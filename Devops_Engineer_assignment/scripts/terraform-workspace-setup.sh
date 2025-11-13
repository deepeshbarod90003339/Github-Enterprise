#!/bin/bash

# Terraform Workspace Setup Script
# This script initializes Terraform workspaces for different environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Configuration
ENVIRONMENTS=("dev" "test" "prod")
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Initialize backend resources first
init_backend() {
    log "Initializing Terraform backend resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize and apply backend configuration
    terraform init
    terraform plan -out=backend.tfplan
    terraform apply backend.tfplan
    
    log "Backend resources created successfully"
}

# Setup workspace for each environment
setup_workspace() {
    local env=$1
    
    log "Setting up Terraform workspace for environment: $env"
    
    cd "$TERRAFORM_DIR/environments/$env"
    
    # Initialize Terraform
    terraform init
    
    # Create or select workspace
    if terraform workspace list | grep -q "$env"; then
        info "Workspace '$env' already exists, selecting it"
        terraform workspace select "$env"
    else
        info "Creating new workspace '$env'"
        terraform workspace new "$env"
    fi
    
    # Validate configuration
    terraform validate
    
    # Plan the infrastructure
    terraform plan -var-file="terraform.tfvars" -out="$env.tfplan"
    
    log "Workspace '$env' setup completed"
}

# Deploy infrastructure for environment
deploy_environment() {
    local env=$1
    
    log "Deploying infrastructure for environment: $env"
    
    cd "$TERRAFORM_DIR/environments/$env"
    
    # Select workspace
    terraform workspace select "$env"
    
    # Apply the plan
    terraform apply "$env.tfplan"
    
    # Output important values
    terraform output
    
    log "Infrastructure deployment completed for environment: $env"
}

# Validate all environments
validate_all() {
    log "Validating all environment configurations..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        info "Validating $env environment..."
        cd "$TERRAFORM_DIR/environments/$env"
        terraform validate
        terraform fmt -check
    done
    
    log "All environment configurations are valid"
}

# Show workspace status
show_status() {
    log "Terraform workspace status:"
    
    for env in "${ENVIRONMENTS[@]}"; do
        if [ -d "$TERRAFORM_DIR/environments/$env" ]; then
            cd "$TERRAFORM_DIR/environments/$env"
            echo ""
            info "Environment: $env"
            terraform workspace list
            echo "Current workspace: $(terraform workspace show)"
            
            if [ -f "$env.tfplan" ]; then
                echo "Plan file exists: ✓"
            else
                echo "Plan file exists: ✗"
            fi
        fi
    done
}

# Cleanup function
cleanup() {
    local env=$1
    
    warning "Destroying infrastructure for environment: $env"
    read -p "Are you sure you want to destroy $env environment? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        cd "$TERRAFORM_DIR/environments/$env"
        terraform workspace select "$env"
        terraform destroy -var-file="terraform.tfvars" -auto-approve
        log "Infrastructure destroyed for environment: $env"
    else
        info "Destruction cancelled"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "init-backend")
            init_backend
            ;;
        "setup")
            env="${2:-}"
            if [ -z "$env" ]; then
                error "Environment not specified. Usage: $0 setup <environment>"
                exit 1
            fi
            setup_workspace "$env"
            ;;
        "setup-all")
            for env in "${ENVIRONMENTS[@]}"; do
                setup_workspace "$env"
            done
            ;;
        "deploy")
            env="${2:-}"
            if [ -z "$env" ]; then
                error "Environment not specified. Usage: $0 deploy <environment>"
                exit 1
            fi
            deploy_environment "$env"
            ;;
        "deploy-all")
            for env in "${ENVIRONMENTS[@]}"; do
                deploy_environment "$env"
            done
            ;;
        "validate")
            validate_all
            ;;
        "status")
            show_status
            ;;
        "destroy")
            env="${2:-}"
            if [ -z "$env" ]; then
                error "Environment not specified. Usage: $0 destroy <environment>"
                exit 1
            fi
            cleanup "$env"
            ;;
        "help"|"--help"|"-h"|"")
            echo "Terraform Workspace Management Script"
            echo ""
            echo "Usage: $0 <command> [environment]"
            echo ""
            echo "Commands:"
            echo "  init-backend  Initialize S3 and DynamoDB backend resources"
            echo "  setup <env>   Setup workspace for specific environment"
            echo "  setup-all     Setup workspaces for all environments"
            echo "  deploy <env>  Deploy infrastructure for specific environment"
            echo "  deploy-all    Deploy infrastructure for all environments"
            echo "  validate      Validate all environment configurations"
            echo "  status        Show workspace status for all environments"
            echo "  destroy <env> Destroy infrastructure for specific environment"
            echo "  help          Show this help message"
            echo ""
            echo "Environments: ${ENVIRONMENTS[*]}"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi