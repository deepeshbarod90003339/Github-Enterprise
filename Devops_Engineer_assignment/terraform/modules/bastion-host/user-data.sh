#!/bin/bash
# Bastion Host User Data Script
set -euo pipefail

# Update system
yum update -y || { echo "Failed to update system"; exit 1; }

# Install required packages
yum install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    vim \
    jq

# Install AWS CLI v2
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || { echo "Failed to download AWS CLI"; exit 1; }
unzip awscliv2.zip
./aws/install || { echo "Failed to install AWS CLI"; exit 1; }
rm -rf aws awscliv2.zip

# Install kubectl
curl -fsSL -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl || { echo "Failed to download kubectl"; exit 1; }
chmod +x ./kubectl
mv ./kubectl /usr/local/bin

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install docker (for troubleshooting)
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Configure Session Manager logging
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/amazon/ssm/amazon-ssm-agent.log",
                        "log_group_name": "/aws/sessionmanager/${environment}",
                        "log_stream_name": "{instance_id}/ssm-agent.log"
                    }
                ]
            }
        }
    }
}
EOF

# Install and start CloudWatch agent
yum install -y amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create useful aliases
cat >> /home/ec2-user/.bashrc << 'EOF'
# Useful aliases for bastion host
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias ll='ls -la'
alias ..='cd ..'

# AWS region
export AWS_DEFAULT_REGION=${aws_region}

# Kubectl completion
source <(kubectl completion bash)
complete -F __start_kubectl k
EOF

# Set up SSH key for accessing private instances (if needed)
mkdir -p /home/ec2-user/.ssh
chown ec2-user:ec2-user /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Create a welcome message
cat > /etc/motd << 'EOF'
================================================================================
                    ${environment} Environment Bastion Host
================================================================================

This bastion host provides secure access to private resources via Session Manager.

Available tools:
- AWS CLI v2
- kubectl (Kubernetes CLI)
- helm (Kubernetes package manager)
- docker (for troubleshooting)

Security Notes:
- No direct SSH access - use Session Manager only
- All sessions are logged to CloudWatch
- Access to private subnets only

Quick Commands:
- kubectl get nodes
- aws eks update-kubeconfig --region ${aws_region} --name <cluster-name>
- helm list

================================================================================
EOF

# Ensure SSM agent is running
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Log the completion
echo "$(date): Bastion host setup completed for ${environment} environment" >> /var/log/bastion-setup.log