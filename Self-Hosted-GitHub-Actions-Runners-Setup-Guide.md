# Self-Hosted GitHub Actions Runners Setup Guide

## Complete Guide for Multiple Repository CI/CD with Parallel Execution

### Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [EC2 Instance Setup](#ec2-instance-setup)
4. [Docker Installation](#docker-installation)
5. [AWS CLI Configuration](#aws-cli-configuration)
6. [Kubectl Installation](#kubectl-installation)
7. [GitHub Actions Runner Setup](#github-actions-runner-setup)
8. [Multiple Runners Configuration](#multiple-runners-configuration)
9. [Service Management](#service-management)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

This guide provides step-by-step instructions to set up multiple self-hosted GitHub Actions runners on a single EC2 instance, enabling parallel CI/CD execution for multiple repositories.

### Architecture
```
EC2 Instance (Ubuntu) - /home/ubuntu/
├── actions-runner-AI-labs-backend/   # Runner for AI-labs Backend
├── actions-runner-AI-labs-frontend/  # Runner for AI-labs Frontend
├── aws/                             # AWS CLI installation files
├── awscliv2.zip                     # AWS CLI installer
└── manage-runners.sh                # Management script
```

### Actual Implementation for AI-labs
- **Backend Runner**: `actions-runner-AI-labs-backend` with labels `AI-labs-backend,backend,linux,x64`
- **Frontend Runner**: `actions-runner-AI-labs-frontend` with labels `AI-labs-frontend,frontend,linux,x64`
- Both runners configured for parallel execution on the same EC2 instance

---

## Prerequisites

### Required Tools
- AWS EC2 instance (Ubuntu 24.04 or later)
- GitHub organization/repository access
- AWS IAM roles with appropriate permissions
- EKS cluster access (if deploying to Kubernetes)

### Minimum EC2 Specifications
- **Instance Type**: t3.large or higher
- **Storage**: 50GB+ EBS volume
- **Memory**: 8GB+ RAM
- **vCPUs**: 2+ cores

---

## EC2 Instance Setup

### 1. Launch EC2 Instance
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip git
```

### 3. Create Directory Structure
```bash
cd /home/ubuntu
mkdir -p runners
cd runners
```

---

## Docker Installation

### 1. Install Docker
```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Restart Docker service
sudo systemctl restart docker

# Verify installation
docker --version
```

### 2. Configure Docker Permissions
```bash
# Check if user is in docker group
groups $USER

# If not in docker group, logout and login again
# Or use newgrp docker
```

---

## AWS CLI Configuration

### 1. Install AWS CLI
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### 2. Configure AWS Credentials
```bash
# Configure AWS CLI (if using IAM user)
aws configure

# Or use IAM roles (recommended for EC2)
# Attach appropriate IAM role to EC2 instance
```

---

## Kubectl Installation

### 1. Install kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### 2. Configure kubectl for EKS
```bash
# Update kubeconfig for your EKS cluster
aws eks update-kubeconfig --region us-east-1 --name YOUR_CLUSTER_NAME

# Test connectivity
kubectl get nodes
```

---

## GitHub Actions Runner Setup

### 1. Download Runner Package
```bash
cd /home/ubuntu
curl -o actions-runner-linux-x64-2.328.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-linux-x64-2.328.0.tar.gz
```

### 2. Setup AI-labs Backend Runner
```bash
# Create directory for AI-labs Backend
mkdir actions-runner-AI-labs-backend
cd actions-runner-AI-labs-backend

# Extract runner files
tar xzf ../actions-runner-linux-x64-2.328.0.tar.gz
```

### 3. Configure AI-labs Backend Runner
```bash
# Get registration token from AI-labs Backend repository
# Go to: https://github.com/YOUR_ORG/AI-labs-backend/settings/actions/runners
# Click "New self-hosted runner" and copy the token

# Configure the backend runner
./config.sh --url https://github.com/YOUR_ORG/AI-labs-backend --token YOUR_BE_TOKEN --name "AI-labs-backend-runner" --labels "AI-labs-backend,backend,linux,x64" --work "_work-AI-labs-backend"
```

### 4. Install as Service
```bash
# Install runner as system service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status
```

---

## Multiple Runners Configuration

### 1. Create Additional Runners
```bash
cd /home/ubuntu

# For each additional repository, create a new runner directory
for i in {2..10}; do
    mkdir actions-runner-repo$i
    cd actions-runner-repo$i
    tar xzf ../actions-runner-linux-x64-2.328.0.tar.gz
    cd ..
done
```

### 2. Configure AI-labs Frontend Runner
```bash
# Setup AI-labs Frontend runner
cd /home/ubuntu
mkdir actions-runner-AI-labs-frontend
cd actions-runner-AI-labs-frontend
tar xzf ../actions-runner-linux-x64-2.328.0.tar.gz

# Get fresh token for AI-labs Frontend repository
# Go to: https://github.com/YOUR_ORG/AI-labs-frontend/settings/actions/runners
./config.sh --url https://github.com/YOUR_ORG/AI-labs-frontend --token YOUR_FE_TOKEN --name "AI-labs-frontend-runner" --labels "AI-labs-frontend,frontend,linux,x64" --work "_work-AI-labs-frontend"

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

### 3. Repeat for All Repositories
```bash
# Follow the same pattern for each repository:
# 1. Get fresh registration token from GitHub
# 2. Configure runner with unique name and labels
# 3. Install as service
# 4. Start service
```

---

## Service Management

### 1. Create Management Script
```bash
sudo nano /home/ubuntu/manage-runners.sh
```

### 2. Add Management Script Content
```bash
#!/bin/bash

RUNNERS_BASE="/home/ubuntu"
RUNNERS=(
    "actions-runner-AI-labs-backend"           # AI-labs Backend Runner
    "actions-runner-AI-labs-frontend"          # AI-labs Frontend Runner
    "actions-runner-DataPlatform-LaunchPad-BE" # DataPlatform LaunchPad Backend Runner
    "actions-runner-DataPlatform-LaunchPad-FE" # DataPlatform LaunchPad Frontend Runner
    # Add more runners as needed for additional repositories
)

case "$1" in
    start)
        echo "🚀 Starting all GitHub Actions runners..."
        for runner in "${RUNNERS[@]}"; do
            if [ -d "$RUNNERS_BASE/$runner" ]; then
                cd "$RUNNERS_BASE/$runner"
                sudo ./svc.sh start
                echo "✅ Started: $runner"
            else
                echo "❌ Directory not found: $runner"
            fi
        done
        ;;
    stop)
        echo "🛑 Stopping all GitHub Actions runners..."
        for runner in "${RUNNERS[@]}"; do
            if [ -d "$RUNNERS_BASE/$runner" ]; then
                cd "$RUNNERS_BASE/$runner"
                sudo ./svc.sh stop
                echo "✅ Stopped: $runner"
            fi
        done
        ;;
    status)
        echo "📊 Status of all GitHub Actions runners..."
        for runner in "${RUNNERS[@]}"; do
            if [ -d "$RUNNERS_BASE/$runner" ]; then
                cd "$RUNNERS_BASE/$runner"
                echo "=== $runner ==="
                sudo ./svc.sh status
                echo ""
            fi
        done
        ;;
    restart)
        echo "🔄 Restarting all runners..."
        $0 stop
        sleep 5
        $0 start
        ;;
    install)
        echo "📦 Installing all runners as services..."
        for runner in "${RUNNERS[@]}"; do
            if [ -d "$RUNNERS_BASE/$runner" ]; then
                cd "$RUNNERS_BASE/$runner"
                sudo ./svc.sh install
                echo "✅ Installed: $runner"
            fi
        done
        ;;
    uninstall)
        echo "🗑️ Uninstalling all runner services..."
        for runner in "${RUNNERS[@]}"; do
            if [ -d "$RUNNERS_BASE/$runner" ]; then
                cd "$RUNNERS_BASE/$runner"
                sudo ./svc.sh uninstall
                echo "✅ Uninstalled: $runner"
            fi
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|install|uninstall}"
        echo ""
        echo "Commands:"
        echo "  start     - Start all runner services"
        echo "  stop      - Stop all runner services"
        echo "  status    - Show status of all runners"
        echo "  restart   - Restart all runner services"
        echo "  install   - Install all runners as services"
        echo "  uninstall - Uninstall all runner services"
        exit 1
        ;;
esac
```

### 3. Make Script Executable
```bash
chmod +x /home/ubuntu/manage-runners.sh
```

### 4. Usage Examples
```bash
# Start all runners
./manage-runners.sh start

# Check status of all runners
./manage-runners.sh status

# Stop all runners
./manage-runners.sh stop

# Restart all runners
./manage-runners.sh restart

# Install all as services
./manage-runners.sh install

# Uninstall all services
./manage-runners.sh uninstall
```

---

## Auto-Start Configuration

### 1. Enable Auto-Start on Boot
```bash
# Edit crontab
sudo crontab -e

# Add this line to start runners on boot
@reboot /home/ubuntu/manage-runners.sh start
```

### 2. Create Systemd Service (Alternative)
```bash
sudo nano /etc/systemd/system/github-runners.service
```

```ini
[Unit]
Description=GitHub Actions Runners
After=network.target

[Service]
Type=oneshot
ExecStart=/home/ubuntu/manage-runners.sh start
ExecStop=/home/ubuntu/manage-runners.sh stop
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
```

### 3. Enable and Start Service
```bash
sudo systemctl enable github-runners.service
sudo systemctl start github-runners.service
sudo systemctl status github-runners.service
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Runner Registration Fails
```bash
# Issue: Token expired or invalid
# Solution: Generate fresh token from GitHub
# Go to: Repository → Settings → Actions → Runners → New self-hosted runner

# Remove existing configuration
./config.sh remove --token YOUR_REMOVAL_TOKEN

# Reconfigure with fresh token
./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_FRESH_TOKEN
```

#### 2. Docker Permission Denied
```bash
# Issue: Docker commands fail with permission denied
# Solution: Add user to docker group and restart session
sudo usermod -aG docker $USER
newgrp docker

# Or logout and login again
```

#### 3. Service Won't Start
```bash
# Check service status
sudo ./svc.sh status

# Check system logs
sudo journalctl -u actions.runner.* -f

# Restart service
sudo ./svc.sh stop
sudo ./svc.sh start
```

#### 4. EKS Connection Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region YOUR_REGION --name YOUR_CLUSTER

# Test connection
kubectl get nodes

# Check AWS credentials
aws sts get-caller-identity
```

#### 5. Multiple Runners Conflict
```bash
# Ensure unique work directories
# Each runner should have different --work parameter
./config.sh --work "_work-unique-name"

# Check for port conflicts
netstat -tulpn | grep :8080
```

#### 6. Disk Space Issues
```bash
# Check disk usage
df -h

# Clean Docker images
docker system prune -a

# Clean runner work directories
find /home/ubuntu/actions-runner-*//_work -type f -name "*.log" -mtime +7 -delete
```

### Log Locations
```bash
# Runner logs
tail -f /home/ubuntu/actions-runner-repo1/_diag/Runner_*.log

# Service logs
sudo journalctl -u actions.runner.* -f

# System logs
sudo tail -f /var/log/syslog
```

---

## Best Practices

### Security

#### 1. IAM Roles and Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 2. Network Security
- Use private subnets for EC2 instances
- Configure security groups with minimal required ports
- Enable VPC Flow Logs for monitoring
- Use NAT Gateway for outbound internet access

#### 3. Token Management
- Use organization-level runners when possible
- Rotate registration tokens regularly
- Store tokens securely (AWS Secrets Manager)
- Never commit tokens to version control

### Performance Optimization

#### 1. Instance Sizing
```bash
# Monitor resource usage
htop
iostat -x 1
df -h

# Recommended specifications by workload:
# Light workload: t3.medium (2 vCPU, 4GB RAM)
# Medium workload: t3.large (2 vCPU, 8GB RAM)
# Heavy workload: c5.xlarge (4 vCPU, 8GB RAM)
```

#### 2. Storage Optimization
- Use GP3 EBS volumes for better performance
- Enable EBS optimization on EC2 instance
- Monitor disk I/O and expand as needed
- Clean up old build artifacts regularly

#### 3. Parallel Execution
```yaml
# In GitHub Actions workflow
jobs:
  build:
    runs-on: [self-hosted, repo1]
    strategy:
      matrix:
        node-version: [16, 18, 20]
      max-parallel: 3
```

### Monitoring and Maintenance

#### 1. Health Checks
```bash
# Create health check script
cat > /home/ubuntu/health-check.sh << 'EOF'
#!/bin/bash
echo "=== Runner Health Check ==="
echo "Date: $(date)"
echo "Disk Usage:"
df -h /
echo "Memory Usage:"
free -h
echo "Docker Status:"
docker info --format '{{.ServerVersion}}'
echo "Runner Status:"
/home/ubuntu/manage-runners.sh status
EOF

chmod +x /home/ubuntu/health-check.sh
```

#### 2. Automated Cleanup
```bash
# Add to crontab for weekly cleanup
sudo crontab -e

# Add these lines:
# Clean Docker weekly
0 2 * * 0 docker system prune -f
# Clean old logs weekly  
0 3 * * 0 find /home/ubuntu/actions-runner-*/_diag -name "*.log" -mtime +30 -delete
```

#### 3. Backup Configuration
```bash
# Backup runner configurations
tar -czf runner-configs-$(date +%Y%m%d).tar.gz /home/ubuntu/actions-runner-*/

# Store in S3
aws s3 cp runner-configs-$(date +%Y%m%d).tar.gz s3://your-backup-bucket/
```

### Scaling Considerations

#### 1. Horizontal Scaling
- Use Auto Scaling Groups for multiple EC2 instances
- Implement runner registration automation
- Use Application Load Balancer for distribution

#### 2. Vertical Scaling
- Monitor CPU and memory usage
- Scale instance type based on workload
- Use CloudWatch metrics for automated scaling

#### 3. Cost Optimization
- Use Spot Instances for non-critical workloads
- Schedule runners to stop during off-hours
- Monitor usage patterns and right-size instances

### Workflow Integration

#### 1. Repository-Specific Labels
```yaml
# Use specific labels in workflows
runs-on: [self-hosted, ai-labs-be, linux, x64]
```

#### 2. Environment Variables
```bash
# Set common environment variables
echo 'export AWS_DEFAULT_REGION=us-east-1' >> ~/.bashrc
echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> ~/.bashrc
```

#### 3. Artifact Management
```yaml
# Clean up artifacts after jobs
- name: Cleanup
  if: always()
  run: |
    docker system prune -f
    rm -rf ${{ github.workspace }}/*
```

---

## Conclusion

This guide provides a comprehensive setup for self-hosted GitHub Actions runners with multiple repository support. The configuration enables:

- **Parallel Execution**: Multiple repositories can run CI/CD simultaneously
- **Scalability**: Easy addition of new runners for additional repositories
- **Management**: Centralized control through management scripts
- **Reliability**: Service-based installation with auto-restart capabilities
- **Security**: Proper IAM roles and network configuration

For additional support or advanced configurations, refer to the [GitHub Actions documentation](https://docs.github.com/en/actions/hosting-your-own-runners) and [AWS EKS documentation](https://docs.aws.amazon.com/eks/).

```bash
# Enable the service
sudo systemctl enable github-runners.service
sudo systemctl start github-runners.service
```

---

## Workflow Configuration

### 1. Repository Workflow Example
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [dev, main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build-and-deploy:
    runs-on: [self-hosted, Linux, X64, repo1]  # Use specific labels
    
    env:
      AWS_REGION: us-east-1
      AWS_ACCOUNT_ID: 263789222982
      ECR_REPO: your/repo/path
      IMAGE_TAG: latest
      CLUSTER_NAME: your-cluster
      NAMESPACE: your-namespace

    steps:
      - name: Setup Docker permissions
        run: |
          sudo usermod -aG docker $USER
          sudo systemctl restart docker
          groups $USER | grep docker || echo "User not in docker group yet"

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/ROLE_NAME
          aws-region: ${{ env.AWS_REGION }}

      - name: Build and Deploy
        run: |
          # Your build and deployment steps here
          echo "Building and deploying..."
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Runner Not Connecting
```bash
# Check runner status
sudo ./svc.sh status

# Check logs
journalctl -u actions.runner.* -f

# Restart runner
sudo ./svc.sh stop
sudo ./svc.sh start
```

#### 2. Docker Permission Issues
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Restart docker service
sudo systemctl restart docker

# Use sg docker for commands
sg docker -c "docker ps"
```

#### 3. EKS Connectivity Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name CLUSTER_NAME

# Test connectivity
kubectl get nodes

# Check security groups
# Ensure EC2 security group allows outbound HTTPS (443)
# Ensure EKS security group allows inbound HTTPS from EC2
```

#### 4. Token Expiration
```bash
# Remove old configuration
./config.sh remove --token OLD_TOKEN

# Get fresh token from GitHub
# Reconfigure with new token
./config.sh --url REPO_URL --token NEW_TOKEN --name RUNNER_NAME
```

#### 5. Disk Space Issues
```bash
# Check disk usage
df -h

# Clean Docker resources
docker system prune -a -f --volumes

# Clean runner work directories
rm -rf /home/ubuntu/actions-runner-*//_work/*
```

---

## Best Practices

### 1. Security
- Use IAM roles instead of access keys
- Regularly rotate registration tokens
- Keep runners updated
- Use private subnets for EC2 instances
- Implement proper security group rules

### 2. Performance
- Use appropriate EC2 instance types
- Monitor resource usage
- Implement disk cleanup strategies
- Use SSD storage for better I/O performance

### 3. Maintenance
- Regular system updates
- Monitor runner health
- Implement log rotation
- Backup runner configurations
- Document runner-to-repository mappings

### 4. Monitoring
```bash
# Create monitoring script
nano /home/ubuntu/monitor-runners.sh
```

```bash
#!/bin/bash
echo "=== Runner Health Check ==="
echo "Date: $(date)"
echo "Disk Usage:"
df -h
echo ""
echo "Memory Usage:"
free -h
echo ""
echo "Docker Status:"
docker system df
echo ""
echo "Runner Services:"
./manage-runners.sh status
```

### 5. Scaling Considerations
- Plan for peak usage times
- Consider using multiple EC2 instances for high availability
- Implement auto-scaling if needed
- Use load balancing for runner distribution

---

## Repository-Specific Configuration

### Example: AI-Lab Backend
```bash
# Directory: actions-runner-AI-labs-backend
# Labels: ai-labs,backend,linux
# Repository: edb-platform-engineering-93527-tec-dat-gen-ailabinfra
```

### Example: AI-Lab Frontend
```bash
# Directory: actions-runner-AI-labs-frontend
# Labels: ai-labs,frontend,linux
# Repository: apms-10612-admin-dataplatform-ai-lab-frontend
```

---

## Conclusion

This setup provides:
- ✅ Parallel CI/CD execution for multiple repositories
- ✅ Automatic runner startup and management
- ✅ Scalable architecture for additional repositories
- ✅ Robust error handling and monitoring
- ✅ Security best practices implementation

### Next Steps
1. Set up monitoring and alerting
2. Implement backup strategies
3. Plan for disaster recovery
4. Consider implementing runner auto-scaling
5. Regular security audits and updates

---

## Support and Maintenance

### Regular Tasks
- Weekly: Check runner health and logs
- Monthly: Update system packages and runner versions
- Quarterly: Review and rotate access tokens
- Annually: Security audit and architecture review

### Contact Information
- **Created by**: Amazon Q AI Assistant
- **Date**: December 2024
- **Version**: 1.0

---

*This document should be kept updated as the infrastructure evolves and new repositories are added to the CI/CD pipeline.*