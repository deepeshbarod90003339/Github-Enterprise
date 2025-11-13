# 🏗️ Private Subnet Multi-Account Architecture

## 🎯 **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           AWS Organization (Root Account)                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  Dev Account (111111111111)  │  Test Account (222222222222)  │  Prod Account (333333333333) │
│  ┌─────────────────────────┐  │  ┌─────────────────────────┐  │  ┌─────────────────────────┐  │
│  │    Private VPC          │  │  │    Private VPC          │  │  │    Private VPC          │  │
│  │  ┌─────────────────────┐│  │  │  ┌─────────────────────┐│  │  │  ┌─────────────────────┐│  │
│  │  │  Private Subnets    ││  │  │  │  Private Subnets    ││  │  │  │  Private Subnets    ││  │
│  │  │  - EKS Cluster      ││  │  │  │  - EKS Cluster      ││  │  │  │  - EKS Cluster      ││  │
│  │  │  - RDS Database     ││  │  │  │  - RDS Database     ││  │  │  │  - RDS Database     ││  │
│  │  │  - EC2 Instances    ││  │  │  │  - EC2 Instances    ││  │  │  │  - EC2 Instances    ││  │
│  │  └─────────────────────┘│  │  │  └─────────────────────┘│  │  │  └─────────────────────┘│  │
│  │  ┌─────────────────────┐│  │  │  ┌─────────────────────┐│  │  │  ┌─────────────────────┐│  │
│  │  │  Bastion Subnet     ││  │  │  │  Bastion Subnet     ││  │  │  │  Bastion Subnet     ││  │
│  │  │  - Bastion Host     ││  │  │  │  - Bastion Host     ││  │  │  │  - Bastion Host     ││  │
│  │  └─────────────────────┘│  │  │  └─────────────────────┘│  │  │  └─────────────────────┘│  │
│  └─────────────────────────┘  │  └─────────────────────────┘  │  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 🔐 **Security Architecture**

### **Access Control Matrix**
| Environment | Account ID | Access Method | Network | Security |
|-------------|------------|---------------|---------|----------|
| **Development** | 111111111111 | Session Manager + Bastion | Private Subnets | Isolated VPC |
| **Testing** | 222222222222 | Session Manager + Bastion | Private Subnets | Isolated VPC |
| **Production** | 333333333333 | Session Manager + Bastion | Private Subnets | Isolated VPC |

### **Network Isolation**
- ✅ **No Direct SSH Access** - All access via Session Manager
- ✅ **Private Subnets Only** - No public IP addresses
- ✅ **Bastion Host** - Controlled access point with logging
- ✅ **VPC Peering** - Secure cross-account communication if needed
- ✅ **NAT Gateway** - Outbound internet access for updates

## 🏗️ **Infrastructure Components**

### **Per-Account Resources**

#### **VPC Configuration**
```hcl
# VPC with private subnets only
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Private subnets for workloads
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# Bastion subnet (still private, accessed via Session Manager)
resource "aws_subnet" "bastion" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.bastion_subnet_cidr
  availability_zone = var.availability_zones[0]
  
  tags = {
    Name = "${var.environment}-bastion-subnet"
    Type = "Bastion"
  }
}
```

#### **Bastion Host Configuration**
```hcl
# Bastion host with Session Manager access
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.bastion.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  
  user_data = base64encode(templatefile("${path.module}/bastion-userdata.sh", {
    environment = var.environment
  }))
  
  tags = {
    Name        = "${var.environment}-bastion-host"
    Environment = var.environment
    Purpose     = "Bastion"
  }
}

# IAM role for Session Manager access
resource "aws_iam_role" "bastion" {
  name = "${var.environment}-bastion-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

## 🚀 **Deployment Strategy**

### **Account-Specific Configurations**

#### **Development Account (111111111111)**
```yaml
# terraform/environments/dev/terraform.tfvars
environment = "dev"
aws_account_id = "111111111111"
vpc_cidr = "10.1.0.0/16"
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
bastion_subnet_cidr = "10.1.10.0/24"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS Configuration
eks_cluster_name = "dev-eks-cluster"
eks_node_groups = {
  main = {
    instance_types = ["t3.medium"]
    min_size = 1
    max_size = 3
    desired_size = 2
  }
}

# RDS Configuration
rds_instance_class = "db.t3.micro"
rds_allocated_storage = 20
```

#### **Testing Account (222222222222)**
```yaml
# terraform/environments/test/terraform.tfvars
environment = "test"
aws_account_id = "222222222222"
vpc_cidr = "10.2.0.0/16"
private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
bastion_subnet_cidr = "10.2.10.0/24"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS Configuration
eks_cluster_name = "test-eks-cluster"
eks_node_groups = {
  main = {
    instance_types = ["t3.medium"]
    min_size = 1
    max_size = 5
    desired_size = 3
  }
}

# RDS Configuration
rds_instance_class = "db.t3.small"
rds_allocated_storage = 50
```

#### **Production Account (333333333333)**
```yaml
# terraform/environments/prod/terraform.tfvars
environment = "prod"
aws_account_id = "333333333333"
vpc_cidr = "10.3.0.0/16"
private_subnet_cidrs = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
bastion_subnet_cidr = "10.3.10.0/24"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS Configuration
eks_cluster_name = "prod-eks-cluster"
eks_node_groups = {
  main = {
    instance_types = ["t3.large"]
    min_size = 3
    max_size = 10
    desired_size = 5
  }
}

# RDS Configuration
rds_instance_class = "db.t3.medium"
rds_allocated_storage = 100
rds_multi_az = true
```

## 🔧 **Access Management**

### **Session Manager Access**
```bash
# Connect to bastion host via Session Manager
aws ssm start-session --target i-1234567890abcdef0 --profile dev-account

# Connect to EKS nodes via bastion
aws ssm start-session --target i-0987654321fedcba0 --profile dev-account

# Port forwarding for applications
aws ssm start-session --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

### **Cross-Account Role Assumption**
```hcl
# Cross-account access role
resource "aws_iam_role" "cross_account_access" {
  name = "${var.environment}-cross-account-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.management_account_id}:root"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}
```

## 🛡️ **Security Controls**

### **Network Security Groups**
```hcl
# Bastion security group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.environment}-bastion-"
  vpc_id      = aws_vpc.main.id
  
  # No inbound SSH - only Session Manager
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.environment}-bastion-sg"
  }
}

# EKS node security group
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.environment}-eks-nodes-"
  vpc_id      = aws_vpc.main.id
  
  # Allow access from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  
  # EKS required ports
  ingress {
    from_port = 1025
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### **VPC Endpoints for AWS Services**
```hcl
# VPC endpoints for AWS services (no internet required)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  tags = {
    Name = "${var.environment}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}
```

## 📊 **Monitoring & Logging**

### **CloudTrail Configuration**
```hcl
# CloudTrail for all API calls
resource "aws_cloudtrail" "main" {
  name           = "${var.environment}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket
  
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }
  
  tags = {
    Environment = var.environment
  }
}
```

### **VPC Flow Logs**
```hcl
# VPC Flow Logs for network monitoring
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = {
    Name = "${var.environment}-vpc-flow-logs"
  }
}
```

## 🚀 **Deployment Commands**

### **Infrastructure Deployment**
```bash
# Deploy to Development Account
cd terraform/environments/dev
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Deploy to Testing Account
cd ../test
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Deploy to Production Account
cd ../prod
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### **Application Deployment via Session Manager**
```bash
# Connect to bastion in dev account
aws ssm start-session --target i-dev-bastion --profile dev-account

# From bastion, access EKS cluster
kubectl get nodes
kubectl apply -f k8s-manifests/

# Deploy applications
helm upgrade --install app-name ./helm-chart \
  --namespace app-namespace \
  --values values-dev.yaml
```

## 🎯 **Benefits of This Architecture**

### ✅ **Security Benefits**
- **Zero Direct SSH Access** - All access via Session Manager
- **Complete Network Isolation** - Private subnets only
- **Account-Level Isolation** - Separate AWS accounts per environment
- **Audit Trail** - All access logged via CloudTrail
- **Principle of Least Privilege** - Minimal required permissions

### ✅ **Operational Benefits**
- **Centralized Access Control** - Session Manager integration
- **Scalable Architecture** - Easy to replicate across accounts
- **Cost Optimization** - Right-sized resources per environment
- **Compliance Ready** - Meets enterprise security requirements

### ✅ **Management Benefits**
- **Infrastructure as Code** - Terraform for all resources
- **Consistent Deployments** - Standardized across environments
- **Easy Troubleshooting** - Centralized logging and monitoring
- **Disaster Recovery** - Cross-region replication capabilities

This architecture provides enterprise-grade security with complete isolation while maintaining operational efficiency through automation and standardization.