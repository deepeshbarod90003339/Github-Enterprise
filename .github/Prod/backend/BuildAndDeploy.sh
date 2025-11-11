#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
# Global Configuration
# ──────────────────────────────────────────────────────────────

# Environment check
if [ -z "$ENVIRONMENT" ]; then
  echo "❌ Error: ENVIRONMENT variable is not set."
  exit 1
fi

echo "🚀 Deploying Dsaas Backend to environment: $ENVIRONMENT"
echo

# AWS config (conditionally set account ID based on environment)
AWS_REGION="us-east-1"

if [ "$ENVIRONMENT" = "prod" ]; then
  AWS_ACCOUNT_ID="432372222409"
  CURRENT_ENV="prd"
elif [ "$ENVIRONMENT" = "dev" ]; then
  AWS_ACCOUNT_ID="263789222982"
  CURRENT_ENV="dev"
else
  echo "❌ Error: Unknown ENVIRONMENT value '$ENVIRONMENT'. Expected 'dev' or 'prod'."
  exit 1
fi

# Docker config
ECR_REPO="eda/services/dataplatform/dsaas"
IMAGE_TAG="latest"
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG"

# Kubernetes config
NAMESPACE="eda-services"
DEPLOYMENT_NAME="eda-services-dsaas-deploy"
SERVICE_NAME="eda-services-dsaas-svc"
DEPLOY_FOLDER="deploy/$ENVIRONMENT"
DEPLOYMENT_FILE="deploy.yml"
SERVICE_FILE="service.yml"
INGRESS_FILE="ingress.yml"

CONFIG_PATH="configs/$CURRENT_ENV/config.json"

# ──────────────────────────────────────────────────────────────
# Copy environment-specific config
# ──────────────────────────────────────────────────────────────
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Error: Config file not found at $CONFIG_PATH"
  exit 1
fi

echo "📁 Copying config: $CONFIG_PATH → configs/"
echo "📁 from config/$CURRENT_ENV folder"
cp "$CONFIG_PATH" configs/config.json
ls -l configs/config.json
echo " "

# ──────────────────────────────────────────────────────────────
# Docker build and push
# ──────────────────────────────────────────────────────────────
echo "🔍 Checking if Docker image exists locally: $ECR_URI"
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$ECR_URI"; then
  echo "🗑️  Docker image found. Deleting local image..."
  docker rmi $ECR_URI || true
  sleep 5
else
  echo "✅ No existing local Docker image found."
fi
echo " "

echo "🔨 Building Docker image..."
docker build --no-cache -t $ECR_URI .
sleep 5
echo " "

echo "🔐 Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo " "

echo "📦 Pushing Docker image to ECR..."
docker push $ECR_URI
echo "✅ Docker image pushed: $ECR_URI"
echo " "

# ──────────────────────────────────────────────────────────────
# Kubernetes Deployment
# ──────────────────────────────────────────────────────────────
echo "🔎 Checking existing resources in namespace: $NAMESPACE"
if kubectl get all -n $NAMESPACE | grep -q "$DEPLOYMENT_NAME"; then
  echo "🗑️  Existing deployment found. Deleting..."
  kubectl delete deployment $DEPLOYMENT_NAME -n $NAMESPACE
fi

if kubectl get service -n $NAMESPACE | grep -q "$SERVICE_NAME"; then
  echo "🗑️  Existing service found. Deleting..."
  kubectl delete service $SERVICE_NAME -n $NAMESPACE
fi
echo " "

if [ -d "$DEPLOY_FOLDER" ]; then
  echo "📂 Navigating to deployment folder: $DEPLOY_FOLDER"
  cd $DEPLOY_FOLDER
else
  echo "❌ Error: Deployment folder $DEPLOY_FOLDER does not exist!"
  exit 1
fi
echo " "

echo "📄 Applying deployment file..."
kubectl apply -f $DEPLOYMENT_FILE -n $NAMESPACE

echo " "
echo "📄 Applying service file..."
kubectl apply -f $SERVICE_FILE -n $NAMESPACE

echo " "
echo "📄 Applying ingress file..."
kubectl apply -f $INGRESS_FILE -n $NAMESPACE

echo " "
echo "✅ Deployment and service applied successfully!"

echo " "
echo "📊 Current status in namespace: $NAMESPACE"
kubectl get all -n $NAMESPACE

echo " "
echo "🎉 Dsaas Backend deployment completed!"
if [ "$ENVIRONMENT" = "prod" ]; then
  echo "🌐 API accessible at: https://onedata-api.onetakeda.com/services/dataplatform/dsaas"
else
  echo "🌐 API accessible at: https://1data-api-dev.onetakeda.com/services/dataplatform/dsaas"
fi
echo " "