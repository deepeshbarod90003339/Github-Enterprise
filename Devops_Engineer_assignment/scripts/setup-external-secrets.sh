#!/bin/bash

# External Secrets Operator Setup Script
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install External Secrets Operator
install_external_secrets() {
    log "Installing External Secrets Operator..."
    
    # Add Helm repository
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    # Create namespace
    kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install External Secrets Operator
    helm upgrade --install external-secrets external-secrets/external-secrets \
        --namespace external-secrets-system \
        --set installCRDs=true \
        --set webhook.port=9443 \
        --set certController.enable=true \
        --wait
    
    log "External Secrets Operator installed successfully"
}

# Setup IAM Role for External Secrets
setup_iam_role() {
    local environment=$1
    log "Setting up IAM role for External Secrets Operator in $environment..."
    
    # Get OIDC issuer URL
    OIDC_ISSUER=$(aws eks describe-cluster --name data-collection-${environment}-eks --query 'cluster.identity.oidc.issuer' --output text)
    OIDC_ISSUER_HOSTNAME=$(echo $OIDC_ISSUER | sed 's|https://||')
    
    # Create trust policy
    cat > external-secrets-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/${OIDC_ISSUER_HOSTNAME}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_ISSUER_HOSTNAME}:sub": "system:serviceaccount:data-collection:data-collection-service",
                    "${OIDC_ISSUER_HOSTNAME}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF
    
    # Create IAM role
    aws iam create-role \
        --role-name external-secrets-operator-${environment}-role \
        --assume-role-policy-document file://external-secrets-trust-policy.json || true
    
    # Create policy for Secrets Manager access
    cat > external-secrets-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "arn:aws:secretsmanager:us-east-1:$(aws sts get-caller-identity --query Account --output text):secret:data-collection-${environment}-*"
            ]
        }
    ]
}
EOF
    
    # Attach policy to role
    aws iam put-role-policy \
        --role-name external-secrets-operator-${environment}-role \
        --policy-name SecretsManagerAccess \
        --policy-document file://external-secrets-policy.json
    
    # Cleanup temp files
    rm -f external-secrets-trust-policy.json external-secrets-policy.json
    
    log "IAM role setup completed for $environment"
}

# Apply External Secrets configuration
apply_external_secrets_config() {
    local environment=$1
    log "Applying External Secrets configuration for $environment..."
    
    # Replace environment placeholders
    sed "s/ENV/$environment/g" k8s/external-secrets.yaml > k8s/external-secrets-${environment}.yaml
    sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" k8s/external-secrets-${environment}.yaml
    
    # Apply configuration
    kubectl apply -f k8s/external-secrets-${environment}.yaml
    
    log "External Secrets configuration applied for $environment"
}

# Verify secrets synchronization
verify_secrets() {
    local environment=$1
    log "Verifying secrets synchronization for $environment..."
    
    # Wait for secrets to be created
    sleep 30
    
    # Check if secrets exist
    secrets=("database-credentials" "redis-credentials" "api-keys")
    for secret in "${secrets[@]}"; do
        if kubectl get secret $secret -n data-collection > /dev/null 2>&1; then
            log "✓ Secret $secret synchronized successfully"
        else
            error "✗ Secret $secret not found"
        fi
    done
}

# Main function
main() {
    local environment=${1:-dev}
    
    log "Setting up External Secrets Operator for environment: $environment"
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        error "aws cli is not installed"
        exit 1
    fi
    
    # Install External Secrets Operator
    install_external_secrets
    
    # Setup IAM role
    setup_iam_role $environment
    
    # Apply configuration
    apply_external_secrets_config $environment
    
    # Verify secrets
    verify_secrets $environment
    
    log "External Secrets Operator setup completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi