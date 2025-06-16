#!/bin/bash
# Deployment Agent - Handles CI/CD, containerization, and cloud deployments
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_STATE="$SCRIPT_DIR/state/deployment"
mkdir -p "$DEPLOY_STATE/configs" "$DEPLOY_STATE/pipelines" "$DEPLOY_STATE/manifests"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║        Deployment Agent v1.0           ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
}

# Detect project type
detect_project() {
    local project_type="generic"
    local platform="docker"
    
    if [[ -f "package.json" ]]; then
        project_type="node"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        project_type="python"
    elif [[ -f "*.csproj" ]] || [[ -f "*.sln" ]]; then
        project_type="dotnet"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        project_type="java"
    elif [[ -f "go.mod" ]]; then
        project_type="go"
    fi
    
    # Detect platform preferences
    if [[ -f ".github/workflows/"*.yml ]]; then
        platform="github"
    elif [[ -f ".gitlab-ci.yml" ]]; then
        platform="gitlab"
    elif [[ -f "azure-pipelines.yml" ]]; then
        platform="azure"
    fi
    
    echo "$project_type:$platform"
}

# Generate Dockerfile
generate_dockerfile() {
    local project_type="${1:-generic}"
    local output_file="${2:-Dockerfile}"
    
    log_event "INFO" "DEPLOYMENT" "Generating Dockerfile for $project_type project"
    
    case "$project_type" in
        node)
            cat > "$output_file" << 'EOF'
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Build if needed
RUN npm run build || true

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy from builder
COPY --from=builder --chown=nodejs:nodejs /app .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

# Start application
CMD ["node", "index.js"]
EOF
            ;;
        python)
            cat > "$output_file" << 'EOF'
# Build stage
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser . .

# Update PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python healthcheck.py || exit 1

# Start application
CMD ["python", "app.py"]
EOF
            ;;
        dotnet)
            cat > "$output_file" << 'EOF'
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS builder

WORKDIR /app

# Copy project files
COPY *.csproj ./
RUN dotnet restore

# Copy everything else
COPY . ./
RUN dotnet publish -c Release -o out

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:7.0

WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy from builder
COPY --from=builder --chown=appuser:appuser /app/out .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start application
ENTRYPOINT ["dotnet", "YourApp.dll"]
EOF
            ;;
        *)
            cat > "$output_file" << 'EOF'
# Generic Dockerfile
FROM ubuntu:22.04

WORKDIR /app

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy application
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Start application
CMD ["./start.sh"]
EOF
            ;;
    esac
    
    log_event "SUCCESS" "DEPLOYMENT" "Dockerfile generated at $output_file"
}

# Generate Docker Compose
generate_docker_compose() {
    local output_file="${1:-docker-compose.yml}"
    
    log_event "INFO" "DEPLOYMENT" "Generating Docker Compose configuration"
    
    cat > "$output_file" << 'EOF'
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - db
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
  
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=myapp
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
  
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    restart: unless-stopped
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF
    
    log_event "SUCCESS" "DEPLOYMENT" "Docker Compose configuration generated"
}

# Generate GitHub Actions workflow
generate_github_actions() {
    local project_type="${1:-node}"
    local workflow_file=".github/workflows/deploy.yml"
    
    mkdir -p "$(dirname "$workflow_file")"
    
    log_event "INFO" "DEPLOYMENT" "Generating GitHub Actions workflow"
    
    cat > "$workflow_file" << 'EOF'
name: Deploy

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run tests
      run: npm test
    
    - name: Run linter
      run: npm run lint

  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to staging
      run: |
        echo "Deploying to staging environment"
        # Add deployment commands here
    
    - name: Run smoke tests
      run: |
        echo "Running smoke tests"
        # Add smoke test commands here
    
    - name: Deploy to production
      if: success()
      run: |
        echo "Deploying to production"
        # Add production deployment commands here
EOF
    
    log_event "SUCCESS" "DEPLOYMENT" "GitHub Actions workflow generated"
}

# Generate Kubernetes manifests
generate_k8s_manifests() {
    local app_name="${1:-myapp}"
    local namespace="${2:-default}"
    
    mkdir -p "$DEPLOY_STATE/manifests"
    
    log_event "INFO" "DEPLOYMENT" "Generating Kubernetes manifests"
    
    # Deployment
    cat > "$DEPLOY_STATE/manifests/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
  namespace: $namespace
  labels:
    app: $app_name
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $app_name
  template:
    metadata:
      labels:
        app: $app_name
    spec:
      containers:
      - name: $app_name
        image: ghcr.io/yourorg/$app_name:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: $app_name-secrets
              key: database-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

    # Service
    cat > "$DEPLOY_STATE/manifests/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $app_name
  namespace: $namespace
spec:
  selector:
    app: $app_name
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
EOF

    # Ingress
    cat > "$DEPLOY_STATE/manifests/ingress.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $app_name
  namespace: $namespace
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - $app_name.example.com
    secretName: $app_name-tls
  rules:
  - host: $app_name.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $app_name
            port:
              number: 80
EOF

    # HPA
    cat > "$DEPLOY_STATE/manifests/hpa.yaml" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: $app_name
  namespace: $namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: $app_name
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF
    
    log_event "SUCCESS" "DEPLOYMENT" "Kubernetes manifests generated"
}

# Generate Terraform configuration
generate_terraform() {
    local provider="${1:-aws}"
    local output_dir="$DEPLOY_STATE/terraform"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "DEPLOYMENT" "Generating Terraform configuration for $provider"
    
    # Main configuration
    cat > "$output_dir/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "app/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = var.tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = var.tags
}

# Application Load Balancer
module "alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "8.0.0"
  
  name = "${var.app_name}-alb"
  
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  
  security_groups = [aws_security_group.alb.id]
  
  target_groups = [
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  ]
  
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.cert.arn
      target_group_index = 0
    }
  ]
  
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
  
  tags = var.tags
}
EOF

    # Variables
    cat > "$output_dir/variables.tf" << 'EOF'
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "myapp"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
EOF
    
    log_event "SUCCESS" "DEPLOYMENT" "Terraform configuration generated"
}

# Generate deployment scripts
generate_deploy_scripts() {
    local platform="${1:-docker}"
    
    log_event "INFO" "DEPLOYMENT" "Generating deployment scripts for $platform"
    
    # Deploy script
    cat > "$DEPLOY_STATE/deploy.sh" << 'EOF'
#!/bin/bash
# Deployment script

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${1:-staging}"
VERSION="${2:-latest}"

echo -e "${YELLOW}Deploying version $VERSION to $ENVIRONMENT...${NC}"

# Pre-deployment checks
echo "Running pre-deployment checks..."
./scripts/pre-deploy-check.sh "$ENVIRONMENT"

# Build and tag image
echo "Building Docker image..."
docker build -t myapp:$VERSION .
docker tag myapp:$VERSION registry.example.com/myapp:$VERSION

# Push to registry
echo "Pushing to registry..."
docker push registry.example.com/myapp:$VERSION

# Deploy based on environment
case "$ENVIRONMENT" in
    staging)
        echo "Deploying to staging..."
        kubectl set image deployment/myapp myapp=registry.example.com/myapp:$VERSION -n staging
        ;;
    production)
        echo "Deploying to production..."
        kubectl set image deployment/myapp myapp=registry.example.com/myapp:$VERSION -n production
        ;;
    *)
        echo -e "${RED}Unknown environment: $ENVIRONMENT${NC}"
        exit 1
        ;;
esac

# Wait for rollout
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/myapp -n "$ENVIRONMENT"

# Run post-deployment tests
echo "Running post-deployment tests..."
./scripts/post-deploy-test.sh "$ENVIRONMENT"

echo -e "${GREEN}Deployment complete!${NC}"
EOF
    
    chmod +x "$DEPLOY_STATE/deploy.sh"
    
    # Rollback script
    cat > "$DEPLOY_STATE/rollback.sh" << 'EOF'
#!/bin/bash
# Rollback script

set -euo pipefail

ENVIRONMENT="${1:-staging}"

echo "Rolling back deployment in $ENVIRONMENT..."

# Get previous revision
PREVIOUS_REVISION=$(kubectl rollout history deployment/myapp -n "$ENVIRONMENT" | tail -2 | head -1 | awk '{print $1}')

# Rollback
kubectl rollout undo deployment/myapp --to-revision="$PREVIOUS_REVISION" -n "$ENVIRONMENT"

# Wait for rollback
kubectl rollout status deployment/myapp -n "$ENVIRONMENT"

echo "Rollback complete!"
EOF
    
    chmod +x "$DEPLOY_STATE/rollback.sh"
    
    log_event "SUCCESS" "DEPLOYMENT" "Deployment scripts generated"
}

# Generate deployment checklist
generate_checklist() {
    local output_file="$DEPLOY_STATE/deployment_checklist.md"
    
    cat > "$output_file" << 'EOF'
# Deployment Checklist

## Pre-Deployment
- [ ] All tests passing
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Database migrations prepared
- [ ] Environment variables configured
- [ ] Secrets updated in vault
- [ ] Load testing completed
- [ ] Security scan passed

## Deployment
- [ ] Build artifacts created
- [ ] Images pushed to registry
- [ ] Deployment manifests updated
- [ ] Staged rollout initiated
- [ ] Health checks passing
- [ ] Metrics baseline captured

## Post-Deployment
- [ ] Smoke tests passed
- [ ] Performance metrics normal
- [ ] Error rates acceptable
- [ ] User acceptance verified
- [ ] Monitoring alerts configured
- [ ] Backup verification completed
- [ ] Rollback plan tested

## Communication
- [ ] Team notified
- [ ] Status page updated
- [ ] Release notes published
- [ ] Customer communication sent
EOF
    
    log_event "SUCCESS" "DEPLOYMENT" "Deployment checklist generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        dockerfile)
            local project_type="${2:-$(detect_project | cut -d: -f1)}"
            generate_dockerfile "$project_type" "${3:-Dockerfile}"
            ;;
        compose)
            generate_docker_compose "${2:-docker-compose.yml}"
            ;;
        github)
            generate_github_actions "${2:-node}"
            ;;
        k8s|kubernetes)
            generate_k8s_manifests "${2:-myapp}" "${3:-default}"
            ;;
        terraform)
            generate_terraform "${2:-aws}"
            ;;
        scripts)
            generate_deploy_scripts "${2:-docker}"
            ;;
        checklist)
            generate_checklist
            ;;
        init)
            echo -e "${CYAN}Initializing deployment configuration...${NC}"
            local project_info=$(detect_project)
            local project_type="${project_info%%:*}"
            echo -e "${GREEN}Detected project type: $project_type${NC}"
            
            generate_dockerfile "$project_type"
            generate_docker_compose
            generate_github_actions "$project_type"
            generate_deploy_scripts
            generate_checklist
            
            echo -e "${GREEN}✓ Deployment configuration initialized!${NC}"
            ;;
        *)
            echo "Usage: $0 {dockerfile|compose|github|k8s|terraform|scripts|checklist|init} [options]"
            echo ""
            echo "Commands:"
            echo "  dockerfile [type] [file]    - Generate Dockerfile"
            echo "  compose [file]              - Generate Docker Compose config"
            echo "  github [type]               - Generate GitHub Actions workflow"
            echo "  k8s [app] [namespace]       - Generate Kubernetes manifests"
            echo "  terraform [provider]        - Generate Terraform config"
            echo "  scripts [platform]          - Generate deployment scripts"
            echo "  checklist                   - Generate deployment checklist"
            echo "  init                        - Initialize all deployment configs"
            exit 1
            ;;
    esac
}

main "$@"