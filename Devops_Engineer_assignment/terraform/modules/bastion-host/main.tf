# Bastion Host Module for Session Manager Access
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role for bastion host
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
  
  tags = {
    Name        = "${var.environment}-bastion-role"
    Environment = var.environment
  }
}

# IAM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional policy for EKS access
resource "aws_iam_role_policy" "bastion_eks" {
  name = "${var.environment}-bastion-eks-policy"
  role = aws_iam_role.bastion.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM instance profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
  
  tags = {
    Name        = "${var.environment}-bastion-profile"
    Environment = var.environment
  }
}

# Security group for bastion host
resource "aws_security_group" "bastion" {
  name_prefix = "${var.environment}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host - Session Manager access only"
  
  # Allow SSH to private instances
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "SSH to private instances"
  }
  
  # Allow HTTPS for kubectl and AWS API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }
  
  # Allow HTTP for package updates
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }
  
  # Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }
  
  tags = {
    Name        = "${var.environment}-bastion-sg"
    Environment = var.environment
  }
}

# Bastion host EC2 instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.bastion_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  monitoring             = true
  
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    environment = var.environment
    aws_region  = var.aws_region
  }))
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }
  
  tags = {
    Name        = "${var.environment}-bastion-host"
    Environment = var.environment
    Purpose     = "Bastion"
    Backup      = "Required"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Session Manager logs
resource "aws_cloudwatch_log_group" "session_manager" {
  name              = "/aws/sessionmanager/${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name        = "${var.environment}-session-manager-logs"
    Environment = var.environment
  }
}