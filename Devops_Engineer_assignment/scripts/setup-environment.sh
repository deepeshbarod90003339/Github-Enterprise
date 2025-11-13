#!/bin/bash

# Data Collection Service Environment Setup Script
# This script sets up the complete environment for the data collection service

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
CONFIG_DIR="$PROJECT_ROOT/config"

# Logging function
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

# Pre-flight checks
preflight_checks() {
    log "Starting pre-flight checks..."
    
    # Check required tools
    local required_tools=("docker" "docker-compose" "kubectl" "helm" "terraform" "aws" "python3")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            info "$tool: $(command -v "$tool")"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check system resources
    local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    local available_disk=$(df -h "$PROJECT_ROOT" | awk 'NR==2{print $4}' | sed 's/G//')
    
    info "Available memory: ${available_memory}GB"
    info "Available disk space: ${available_disk}GB"
    
    if (( $(echo "$available_memory < 2.0" | bc -l) )); then
        warning "Low memory available: ${available_memory}GB (recommended: 4GB+)"
    fi
    
    if (( $(echo "$available_disk < 10" | bc -l) )); then
        error "Insufficient disk space: ${available_disk}GB (required: 10GB+)"
        exit 1
    fi
    
    # Check network connectivity
    local endpoints=("github.com" "registry.hub.docker.com" "amazonaws.com")
    for endpoint in "${endpoints[@]}"; do
        if ping -c 1 "$endpoint" &> /dev/null; then
            info "Network connectivity to $endpoint: OK"
        else
            warning "Cannot reach $endpoint"
        fi
    done
    
    log "Pre-flight checks completed successfully"
}

# Environment configuration
setup_environment() {
    log "Setting up environment configuration..."
    
    # Create directory structure
    local directories=("$LOG_DIR" "$CONFIG_DIR" "$PROJECT_ROOT/data" "$PROJECT_ROOT/backups")
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            info "Created directory: $dir"
        fi
    done
    
    # Set proper permissions
    chmod 755 "$LOG_DIR"
    chmod 755 "$CONFIG_DIR"
    
    # Generate configuration files from templates
    if [ -f "$PROJECT_ROOT/config/config.template.json" ]; then
        envsubst < "$PROJECT_ROOT/config/config.template.json" > "$CONFIG_DIR/config.json"
        info "Generated config.json from template"
    fi
    
    # Setup logging configuration
    cat > "$LOG_DIR/setup.log" << EOF
# Data Collection Service Setup Log
# Started at: $(date)
# User: $(whoami)
# Host: $(hostname)
EOF
    
    log "Environment configuration completed"
}

# Deployment function
deploy_services() {
    log "Starting service deployment..."
    
    cd "$PROJECT_ROOT"
    
    # Check if we should build or pull images
    if [ "${BUILD_FROM_SOURCE:-false}" = "true" ]; then
        info "Building Docker image from source..."
        docker build -t data-collection-service:latest .
    else
        info "Using pre-built images..."
    fi
    
    # Start services with Docker Compose
    info "Starting services with Docker Compose..."
    docker-compose down --remove-orphans || true
    docker-compose up -d
    
    # Wait for services to be healthy
    local services=("postgres" "redis" "data-collection-service")
    for service in "${services[@]}"; do
        info "Waiting for $service to be healthy..."
        local retries=0
        local max_retries=30
        
        while [ $retries -lt $max_retries ]; do
            if docker-compose ps "$service" | grep -q "healthy\|Up"; then
                info "$service is healthy"
                break
            fi
            
            retries=$((retries + 1))
            sleep 10
            
            if [ $retries -eq $max_retries ]; then
                error "$service failed to become healthy"
                docker-compose logs "$service"
                exit 1
            fi
        done
    done
    
    # Run database migrations if needed
    if [ -f "$PROJECT_ROOT/migrations/init.sql" ]; then
        info "Running database migrations..."
        docker-compose exec -T postgres psql -U postgres -d datacollection -f /docker-entrypoint-initdb.d/init.sql || true
    fi
    
    log "Service deployment completed"
}

# Validation function
validate_deployment() {
    log "Validating deployment..."
    
    local health_checks=(
        "http://localhost:8000/health"
        "http://localhost/health"
    )
    
    for endpoint in "${health_checks[@]}"; do
        info "Checking health endpoint: $endpoint"
        local retries=0
        local max_retries=10
        
        while [ $retries -lt $max_retries ]; do
            if curl -f -s "$endpoint" > /dev/null 2>&1; then
                info "$endpoint is responding"
                break
            fi
            
            retries=$((retries + 1))
            sleep 5
            
            if [ $retries -eq $max_retries ]; then
                warning "$endpoint is not responding"
            fi
        done
    done
    
    # Generate status report
    local report_file="$LOG_DIR/deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    cat > "$report_file" << EOF
# Data Collection Service Deployment Report
Generated at: $(date)

## Service Status
$(docker-compose ps)

## Resource Usage
$(docker stats --no-stream)

## Health Check Results
EOF
    
    for endpoint in "${health_checks[@]}"; do
        if curl -f -s "$endpoint" > /dev/null 2>&1; then
            echo "$endpoint: HEALTHY" >> "$report_file"
        else
            echo "$endpoint: UNHEALTHY" >> "$report_file"
        fi
    done
    
    info "Deployment report saved to: $report_file"
    log "Validation completed"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        error "Setup failed. Cleaning up..."
        docker-compose down --remove-orphans || true
    fi
}

# Main execution
main() {
    trap cleanup EXIT
    
    log "Starting Data Collection Service environment setup"
    
    preflight_checks
    setup_environment
    deploy_services
    validate_deployment
    
    log "Environment setup completed successfully!"
    info "Services are available at:"
    info "  - API: http://localhost:8000"
    info "  - Nginx Proxy: http://localhost"
    info "  - API Documentation: http://localhost:8000/docs"
    
    exit 0
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi