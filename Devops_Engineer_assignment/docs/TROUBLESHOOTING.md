# Troubleshooting Guide

## Scenario 1: Deployment Failure - Container Registry Issues

### Problem
```
Your GitHub Actions pipeline is failing at the deployment stage with this error:
"Error response from daemon: manifest for myapp:v1.2.3 not found"

The build stage completed successfully. What could be wrong?
```

### Diagnostic Approach

#### Step 1: Verify Image Build and Push
```bash
# Check if image was actually pushed
aws ecr describe-images --repository-name myapp --image-ids imageTag=v1.2.3

# Check GitHub Actions logs for push confirmation
grep "digest:" build-logs.txt
```

#### Step 2: Registry Authentication
```bash
# Test ECR authentication
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-west-2.amazonaws.com

# Verify IAM permissions
aws sts get-caller-identity
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::123456789:role/GitHubActionsRole --action-names ecr:GetAuthorizationToken ecr:BatchCheckLayerAvailability
```

#### Step 3: Image Tag Verification
```bash
# List all available tags
aws ecr list-images --repository-name myapp --query 'imageIds[*].imageTag'

# Check for tag format issues
echo "Expected: v1.2.3"
echo "Available: $(aws ecr describe-images --repository-name myapp --query 'imageDetails[0].imageTags[0]')"
```

### Potential Root Causes

#### Cause 1: Registry Authentication Failure
- **Investigation**: Check IAM role permissions and OIDC configuration
- **Resolution**: Update IAM policy with proper ECR permissions
- **Prevention**: Implement pre-deployment authentication tests

#### Cause 2: Image Tag Mismatch
- **Investigation**: Compare expected vs actual image tags
- **Resolution**: Fix tagging strategy in CI/CD pipeline
- **Prevention**: Standardize tagging conventions and validation

#### Cause 3: Registry Region Mismatch
- **Investigation**: Verify ECR repository region vs deployment region
- **Resolution**: Update registry URL or deployment region
- **Prevention**: Use environment-specific configuration

### Tools Used
- AWS CLI for ECR inspection
- Docker CLI for local testing
- GitHub Actions logs analysis
- IAM policy simulator

---

## Scenario 2: Performance Degradation

### Problem
```
After deployment, the service is taking 10x longer to process requests than before.
- Previous: 100 records processed in 5 minutes
- Current: 100 records processed in 50 minutes

The service logs show no errors. System resources (CPU, memory) are at 30% utilization.
```

### Diagnostic Approach

#### Step 1: Application Performance Analysis
```bash
# Check application metrics
kubectl top pods -n data-collection
kubectl describe pod data-collection-service-xxx -n data-collection

# Analyze request patterns
curl -s http://service/metrics | grep http_request_duration
```

#### Step 2: Database Performance Investigation
```bash
# Check database connections and queries
kubectl exec -it postgres-pod -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Analyze slow queries
kubectl exec -it postgres-pod -- psql -U postgres -c "SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

#### Step 3: Network and External Dependencies
```bash
# Test external service connectivity
kubectl exec -it data-collection-pod -- curl -w "@curl-format.txt" -s external-api.com/endpoint

# Check DNS resolution times
kubectl exec -it data-collection-pod -- nslookup external-service.com
```

#### Step 4: Configuration Drift Analysis
```bash
# Compare current vs previous configuration
kubectl get configmap app-config -o yaml > current-config.yaml
git show HEAD~1:k8s/configmap.yaml > previous-config.yaml
diff current-config.yaml previous-config.yaml
```

### Potential Root Causes

#### Cause 1: Database Connection Pool Exhaustion
- **Investigation**: Monitor active connections and pool settings
- **Resolution**: Increase connection pool size or implement connection recycling
- **Prevention**: Set appropriate connection limits and monitoring

#### Cause 2: External API Rate Limiting
- **Investigation**: Check API response headers and error codes
- **Resolution**: Implement exponential backoff and circuit breakers
- **Prevention**: Monitor API usage and implement caching

#### Cause 3: Configuration Changes
- **Investigation**: Compare environment variables and config files
- **Resolution**: Revert problematic configuration changes
- **Prevention**: Configuration validation in CI/CD pipeline

### Tools Used
- Prometheus/Grafana for metrics analysis
- kubectl for Kubernetes diagnostics
- Database query analyzers
- APM tools (New Relic, Datadog)

---

## Scenario 3: Container Networking Issue

### Problem
```
Your Docker Compose stack is running, but the application service 
can't communicate with the PostgreSQL database. 

Logs show: "psycopg2.OperationalError: could not connect to server: 
Connection refused"

The database container is running and healthy. What would you check?
```

### Diagnostic Approach

#### Step 1: Container Network Inspection
```bash
# Check container status and networks
docker-compose ps
docker network ls
docker network inspect $(docker-compose ps -q postgres | head -1)

# Test network connectivity
docker-compose exec app ping postgres
docker-compose exec app telnet postgres 5432
```

#### Step 2: Database Configuration Verification
```bash
# Check PostgreSQL configuration
docker-compose exec postgres psql -U postgres -c "SHOW listen_addresses;"
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_hba_file_rules;"

# Verify database is accepting connections
docker-compose exec postgres pg_isready -h localhost -p 5432
```

#### Step 3: Application Configuration Check
```bash
# Verify connection string
docker-compose exec app env | grep DATABASE_URL
docker-compose logs app | grep -i "database\|connection"

# Test connection from application container
docker-compose exec app python -c "
import psycopg2
try:
    conn = psycopg2.connect('postgresql://postgres:password@postgres:5432/datacollection')
    print('Connection successful')
except Exception as e:
    print(f'Connection failed: {e}')
"
```

### Potential Root Causes

#### Cause 1: Network Configuration Issues
- **Investigation**: Check Docker network settings and container connectivity
- **Resolution**: Recreate Docker network or fix network configuration
- **Prevention**: Use explicit network definitions in docker-compose.yml

#### Cause 2: Service Discovery Problems
- **Investigation**: Verify service names and DNS resolution
- **Resolution**: Use correct service names in connection strings
- **Prevention**: Standardize service naming conventions

#### Cause 3: Database Authentication/Authorization
- **Investigation**: Check PostgreSQL user permissions and pg_hba.conf
- **Resolution**: Update database user permissions or authentication settings
- **Prevention**: Use proper database initialization scripts

### Tools Used
- Docker CLI for container inspection
- Network debugging tools (ping, telnet, nslookup)
- PostgreSQL client tools
- Docker Compose logs analysis

---

## Scenario 4: On-Premises Deployment Challenge

### Problem
```
You need to deploy your containerized service to a client's on-premises environment.
They have:
- Traditional virtualization infrastructure (VMware, Hyper-V, or similar)
- Strict network segmentation (DMZ, internal network, management network)
- No internet access from production servers
- Air-gapped environment for sensitive data
```

### Deployment Approach

#### Step 1: Infrastructure Assessment
```bash
# Document current infrastructure
- Hypervisor type and version
- Available compute resources
- Network topology and firewall rules
- Storage systems and capacity
- Backup and disaster recovery procedures
```

#### Step 2: Air-Gapped Deployment Strategy
```bash
# Create offline installation package
# 1. Export Docker images
docker save data-collection-service:v1.0.0 -o data-collection-service.tar
docker save postgres:15-alpine -o postgres.tar
docker save redis:7-alpine -o redis.tar

# 2. Package Kubernetes manifests
tar -czf k8s-manifests.tar.gz k8s/ helm/

# 3. Create installation scripts
tar -czf installation-package.tar.gz *.tar k8s-manifests.tar.gz scripts/
```

#### Step 3: Network Segmentation Compliance
```yaml
# Network policy for DMZ deployment
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dmz-network-policy
spec:
  podSelector:
    matchLabels:
      tier: dmz
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: external-access
    ports:
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: internal-services
    ports:
    - protocol: TCP
      port: 5432
```

### Challenges and Solutions

#### Challenge 1: Container Runtime Installation
- **Solution**: Provide offline installer packages for Docker/containerd
- **Implementation**: Create custom installation scripts with all dependencies
- **Validation**: Test installation on similar infrastructure

#### Challenge 2: Image Registry Setup
- **Solution**: Deploy local container registry (Harbor or similar)
- **Implementation**: 
```bash
# Deploy Harbor registry
helm install harbor harbor/harbor \
  --set expose.type=nodePort \
  --set persistence.enabled=true \
  --set externalURL=https://registry.client.local
```

#### Challenge 3: Certificate Management
- **Solution**: Implement internal CA and certificate distribution
- **Implementation**:
```bash
# Generate internal CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem

# Generate service certificates
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=data-collection.client.local" -sha256 -new -key server-key.pem -out server.csr
openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -out server-cert.pem
```

### Tools Used
- VMware vSphere/Hyper-V management tools
- Offline package managers (yum, apt with local repos)
- Network scanning tools (nmap, netcat)
- Certificate management tools (OpenSSL, cfssl)

---

## Scenario 5: CI/CD Pipeline Optimization

### Problem
```
Your current GitHub Actions workflow takes 25 minutes to complete.
Breakdown:
- Dependencies installation: 8 minutes
- Linting: 2 minutes
- Testing: 5 minutes
- Docker build: 10 minutes

The team deploys 10-15 times per day. How would you optimize this?
```

### Optimization Strategy

#### Step 1: Dependency Caching
```yaml
# Cache Python dependencies
- name: Cache pip dependencies
  uses: actions/cache@v3
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-

# Cache Docker layers
- name: Setup Docker Buildx
  uses: docker/setup-buildx-action@v2
  with:
    driver-opts: |
      image=moby/buildkit:master
      network=host

- name: Build and push
  uses: docker/build-push-action@v4
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

#### Step 2: Parallel Job Execution
```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: [3.9, 3.10, 3.11]
        test-suite: [unit, integration, e2e]
    runs-on: ubuntu-latest
    steps:
      # Parallel test execution
      
  lint:
    runs-on: ubuntu-latest
    steps:
      # Linting in parallel with tests
      
  security-scan:
    runs-on: ubuntu-latest
    steps:
      # Security scanning in parallel
```

#### Step 3: Build Optimization
```dockerfile
# Multi-stage build with better caching
FROM python:3.11-slim as dependencies
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim as runtime
COPY --from=dependencies /root/.local /root/.local
COPY app/ .
```

#### Step 4: Selective Execution
```yaml
# Skip unnecessary jobs based on changes
- name: Check for changes
  uses: dorny/paths-filter@v2
  id: changes
  with:
    filters: |
      src:
        - 'app/**'
      docker:
        - 'Dockerfile'
        - 'docker-compose.yml'
      k8s:
        - 'k8s/**'
        - 'helm/**'

- name: Run tests
  if: steps.changes.outputs.src == 'true'
  run: pytest

- name: Build Docker image
  if: steps.changes.outputs.docker == 'true' || steps.changes.outputs.src == 'true'
  run: docker build .
```

### Expected Improvements
- **Dependencies**: 8min → 2min (caching)
- **Linting**: 2min → 1min (parallel execution)
- **Testing**: 5min → 3min (parallel + selective)
- **Docker build**: 10min → 4min (layer caching + multi-stage)
- **Total**: 25min → 10min (60% improvement)

### Tools Used
- GitHub Actions cache
- Docker BuildKit with cache mounts
- Parallel job execution
- Path-based change detection
- Build optimization techniques

This comprehensive troubleshooting guide provides systematic approaches to common DevOps challenges, ensuring quick resolution and prevention of recurring issues.