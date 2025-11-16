# 🤖 Ollama Chat App - Complete Development to Production Guide

**Project Goal**: Build a full-stack AI chat application with React frontend, Flask backend, Ollama AI model server, containerized deployment, and production-ready AWS infrastructure.

## 📋 Project Overview

This guide walks through building `ollama-chat-app` under `codeplatoon/projects/` with:

- **Frontend**: React (Vite) Single Page App (SPA) communicating with Flask API
- **Backend**: Flask API forwarding requests to local Ollama instance
- **AI Engine**: Ollama running on private EC2 instances with EBS storage (≥20GB)
- **Containerization**: Multi-platform Docker images (amd64 & arm64) on GitHub Container Registry
- **Infrastructure**: AWS VPC with Terraform (public/private subnets, ALB, ASG, security layers)
- **CI/CD**: GitHub Actions for automated builds and deployments

---

## 🏗️ Architecture Overview

```
Internet → ALB (Public Subnets) → Flask+Ollama EC2 (Private Subnets)
         ↓
    React EC2 (Public Subnets)
```

**High-Level Architecture:**
1. **VPC (10.0.0.0/16)** - Public & private subnets across ≥2 AZs
2. **ALB** - Load balancer in public subnets, routes to Flask instances
3. **React Frontend** - Static nginx serving React app in public subnets
4. **Flask Backend + Ollama** - API server with AI model in private subnets
5. **Security Layers** - Security Groups, NACLs, IAM roles

---

## 📁 Project Structure

```
projects/ollama-chat-app/
├── frontend/                    # React + Vite application
│   ├── src/
│   ├── package.json
│   ├── vite.config.js
│   ├── Dockerfile              # Multi-stage: build → nginx
│   └── README.md
├── backend/                     # Flask API server
│   ├── app.py                  # Main Flask application
│   ├── ollama-connector.py     # Ollama API wrapper
│   ├── requirements.txt
│   ├── Dockerfile              # Python + gunicorn
│   └── README.md
├── infra/                      # Terraform infrastructure
│   ├── modules/
│   │   ├── vpc/               # VPC, subnets, IGW, NAT
│   │   ├── alb/               # Application Load Balancer
│   │   ├── ec2/               # Launch templates
│   │   ├── asg/               # Auto Scaling Groups
│   │   ├── security/          # Security Groups & NACLs
│   │   ├── iam/               # IAM roles & policies
│   │   └── outputs/           # Terraform outputs
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       ├── ci.yml             # Build & push images
│       └── deploy.yml         # Deployment automation
├── docs/
│   ├── ARCHITECTURE_DIAGRAM.drawio
│   ├── ARCHITECTURE_DIAGRAM.png
│   ├── DEPLOYMENT_GUIDE.md
│   └── SECURITY_GUIDE.md
└── README.md
```

---

## 🚀 Phase 1: Project Setup & Development Environment

### Step 1.1: Create Project Structure
**Prerequisites**: Basic understanding of project organization
**Reference**: [tree-examples.md](./tree-examples.md) for folder structure patterns

```bash
# Navigate to projects directory
cd /home/lumineer/codeplatoon/projects

# Create main project directory structure
mkdir -p ollama-chat-app
cd ollama-chat-app

# Create top-level directories
mkdir -p frontend backend docs .github/workflows

# Create infrastructure directories
mkdir -p infra/modules/{vpc,alb,ec2,asg,security,iam,outputs}

# Verify structure
tree ollama-chat-app -L 3
```

### Step 1.2: Initialize Git Repository
**Reference**: [git.md](./git.md) for Git workflow best practices

```bash
cd ollama-chat-app
git init
echo "node_modules/" >> .gitignore
echo "__pycache__/" >> .gitignore
echo "*.pyc" >> .gitignore
echo ".terraform/" >> .gitignore
echo "terraform.tfvars" >> .gitignore
```

---

## 🎨 Phase 2: Frontend Development (React + Vite)

### Step 2.1: Create React Application
**Prerequisites**: Node.js environment setup
**Reference**: [vite.md](./vite.md) for Vite configuration details

```bash
cd frontend

# Initialize Vite React project
npm create vite@latest . -- --template react
npm install

# Install additional dependencies for chat UI
npm install axios lucide-react
```

### Step 2.2: Configure Vite for Production
**Key Configuration**: Environment variables and build optimization

**Create `vite.config.js`:**
```javascript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true
  },
  preview: {
    port: 3000,
    host: true
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    minify: 'terser'
  }
})
```

### Step 2.3: Build Chat Interface
**Key Components**: Chat window, message handling, API integration

**Create basic chat components** (detailed implementation in frontend README)

### Step 2.4: Frontend Containerization
**Prerequisites**: Docker basics
**Reference**: [docker.md](./docker.md) for Docker best practices

**Create `frontend/Dockerfile`:**
```dockerfile
# Multi-stage build for production
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Production stage
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## ⚙️ Phase 3: Backend Development (Flask + Ollama)

### Step 3.1: Flask Application Setup
**Prerequisites**: Python environment
**Reference**: [flask.md](./flask.md) for Flask development patterns

```bash
cd backend

# Create virtual environment (or use uv - see py-uv.md)
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask gunicorn requests python-dotenv flask-cors
pip freeze > requirements.txt
```

### Step 3.2: Create Flask Application
**Create `backend/app.py`:**
```python
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from ollama_connector import OllamaConnector

app = Flask(__name__)
CORS(app)

# Initialize Ollama connector
ollama = OllamaConnector(
    host=os.getenv('OLLAMA_HOST', 'localhost'),
    port=os.getenv('OLLAMA_PORT', '11434')
)

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        prompt = data.get('prompt', '')
        session_id = data.get('session_id', 'default')

        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400

        response = ollama.generate_response(prompt, session_id)
        return jsonify({"response": response, "session_id": session_id})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

### Step 3.3: Ollama Integration
**Create `backend/ollama_connector.py`:**
```python
import requests
import json
from typing import Dict, Any

class OllamaConnector:
    def __init__(self, host='localhost', port='11434'):
        self.base_url = f"http://{host}:{port}"
        self.sessions = {}  # Simple in-memory session storage

    def generate_response(self, prompt: str, session_id: str = 'default') -> str:
        """Generate response from Ollama API"""
        try:
            payload = {
                "model": "llama2",  # Configure based on available models
                "prompt": prompt,
                "stream": False
            }

            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=60
            )
            response.raise_for_status()

            result = response.json()
            return result.get('response', 'No response from model')

        except requests.exceptions.RequestException as e:
            raise Exception(f"Ollama API error: {str(e)}")
```

### Step 3.4: Backend Containerization
**Create `backend/Dockerfile`:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 8000

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

---

## 🐳 Phase 4: Multi-Platform Docker & Container Registry

### Step 4.1: Docker Buildx Setup
**Prerequisites**: Docker with buildx support
**Reference**: [docker.md](./docker.md) for advanced Docker features

```bash
# Create and use buildx builder
docker buildx create --use --name multiarch-builder
docker buildx inspect --bootstrap
```

### Step 4.2: Local Multi-Arch Testing
**Test both frontend and backend builds:**

```bash
# Frontend multi-arch build
cd frontend
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg VITE_API_URL="http://localhost:8000" \
  -t ollama-frontend:local .

# Backend multi-arch build
cd ../backend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ollama-backend:local .
```

### Step 4.3: GitHub Container Registry Setup
**Prerequisites**: GitHub repository and PAT token
**Configure secrets in GitHub repository:**
- `GHCR_TOKEN`: Personal Access Token with `packages:write` scope

---

## 🏗️ Phase 5: AWS Infrastructure with Terraform

### Step 5.1: VPC Network Foundation
**Prerequisites**: AWS CLI configured, Terraform installed
**References**:
- [aws-cli.md](./aws-cli.md) for AWS CLI setup
- [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for VPC networking concepts

**Create `infra/modules/vpc/main.tf`:**
```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (for ALB and React instances)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Type = "Public"
  }
}

# Private Subnets (for Flask+Ollama instances)
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Type = "Private"
  }
}

# NAT Gateway for private subnet internet access
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}
```

### Step 5.2: Security Groups & Network ACLs
**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for security concepts

**Create `infra/modules/security/main.tf`:**
```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Flask Backend Security Group
resource "aws_security_group" "backend" {
  name_prefix = "${var.project_name}-backend-"
  vpc_id      = var.vpc_id

  # Allow Flask traffic from ALB only
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow HTTPS outbound for updates
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP outbound for packages
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# Network ACL for Private Subnets (Defense in Depth)
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow inbound from ALB subnets on port 8000
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = var.public_subnet_cidr_blocks[0]
    from_port  = 8000
    to_port    = 8000
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = var.public_subnet_cidr_blocks[1]
    from_port  = 8000
    to_port    = 8000
  }

  # Allow return traffic on ephemeral ports
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "${var.project_name}-private-nacl"
  }
}
```

### Step 5.3: Application Load Balancer
**Create `infra/modules/alb/main.tf`:**
```hcl
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets           = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for Flask Backend
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
```

### Step 5.4: EC2 Launch Templates & Auto Scaling
**Prerequisites**: Understanding of EC2 and container deployment
**Reference**: [ec2-docker.md](./ec2-docker.md) for EC2 Docker deployment

**Create `infra/modules/ec2/main.tf`:**
```hcl
# Launch Template for Backend (Flask + Ollama)
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = var.ami_id
  instance_type = var.backend_instance_type

  vpc_security_group_ids = [var.backend_security_group_id]

  # EBS configuration for Ollama models
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = var.ollama_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/user_data_backend.sh", {
    backend_image = var.backend_image
    ollama_image  = var.ollama_image
    region        = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-backend"
      Type = "Backend"
    }
  }
}

# Auto Scaling Group for Backend
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.backend_target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.backend_min_size
  max_size         = var.backend_max_size
  desired_capacity = var.backend_desired_capacity

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg"
    propagate_at_launch = false
  }
}
```

---

## 🚀 Phase 6: CI/CD Pipeline with GitHub Actions

### Step 6.1: Container Build & Push Workflow
**Create `.github/workflows/ci.yml`:**
```yaml
name: Build and Push Images

on:
  push:
    branches: [ main, development ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME_FRONTEND: ${{ github.repository }}/ollama-frontend
  IMAGE_NAME_BACKEND: ${{ github.repository }}/ollama-backend

jobs:
  build-frontend:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_FRONTEND }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Frontend
      uses: docker/build-push-action@v5
      with:
        context: ./frontend
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        build-args: |
          VITE_API_URL=${{ vars.VITE_API_URL || 'https://api.example.com' }}

  build-backend:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_BACKEND }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Backend
      uses: docker/build-push-action@v5
      with:
        context: ./backend
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
```

### Step 6.2: Infrastructure Deployment Workflow
**Create `.github/workflows/deploy.yml`:**
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]
    paths: [ 'infra/**' ]
  workflow_dispatch:
    inputs:
      action:
        description: 'Terraform action'
        required: true
        default: 'plan'
        type: choice
        options:
        - plan
        - apply
        - destroy

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ vars.AWS_REGION || 'us-east-1' }}

    - name: Terraform Init
      run: terraform init

    - name: Terraform Plan
      run: terraform plan -var-file="terraform.tfvars"

    - name: Terraform Apply
      if: github.event.inputs.action == 'apply' || (github.event_name == 'push' && github.ref == 'refs/heads/main')
      run: terraform apply -auto-approve -var-file="terraform.tfvars"
```

---

## 📊 Phase 7: Monitoring, Security & Operations

### Step 7.1: Application Monitoring
**Key Metrics to Monitor:**
- ALB response times and error rates
- EC2 instance health and resource utilization
- Auto Scaling Group scaling events
- EBS volume usage (Ollama models)

### Step 7.2: Security Hardening Checklist
**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for security verification

- [ ] Private subnets have no direct internet access
- [ ] Security Groups follow principle of least privilege
- [ ] NACLs provide defense-in-depth
- [ ] EBS volumes are encrypted
- [ ] IAM roles have minimal required permissions
- [ ] ALB has proper SSL/TLS configuration (if using HTTPS)

### Step 7.3: Cost Optimization
**Key Cost Factors:**
- **NAT Gateway**: Consider single NAT vs per-AZ NAT
- **Instance Types**: Right-size based on Ollama model requirements
- **EBS Storage**: Monitor actual model storage usage
- **ALB**: Review request patterns and idle time

---

## 🔧 Phase 8: Testing & Validation

### Step 8.1: Local Development Testing
```bash
# Test multi-arch builds locally
docker buildx build --platform linux/amd64,linux/arm64 -t test-frontend ./frontend
docker buildx build --platform linux/amd64,linux/arm64 -t test-backend ./backend

# Test API endpoints
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello, how are you?"}'
```

### Step 8.2: Infrastructure Validation
**Use existing VPC verification scripts:**
**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md)

```bash
# Validate VPC setup
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ollama-chat-app-vpc"

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

### Step 8.3: End-to-End Testing
1. **Health Check**: Verify `/health` endpoint returns 200
2. **Chat Functionality**: Test chat API with sample prompts
3. **Load Testing**: Use tools like `ab` or `wrk` to test ALB→Flask→Ollama pipeline
4. **Failover Testing**: Terminate instances and verify ASG replacement

---

## 📋 Implementation Checklist

### Development Phase
- [ ] Create project structure and Git repository
- [ ] Build React frontend with Vite
- [ ] Develop Flask backend with Ollama integration
- [ ] Create multi-platform Dockerfiles
- [ ] Test local container builds

### Infrastructure Phase
- [ ] Design Terraform modules (VPC, ALB, EC2, ASG, Security)
- [ ] Configure GitHub Container Registry
- [ ] Set up AWS CLI and Terraform
- [ ] Deploy and test infrastructure
- [ ] Validate security configurations

### CI/CD Phase
- [ ] Create GitHub Actions workflows
- [ ] Configure repository secrets and variables
- [ ] Test automated builds and deployments
- [ ] Set up monitoring and alerting

### Production Phase
- [ ] Performance testing and optimization
- [ ] Security audit and hardening
- [ ] Documentation and runbooks
- [ ] Cost optimization review

---

## 🎯 Quick Start Commands

```bash
# 1. Clone and setup project
git clone <repository-url>
cd ollama-chat-app

# 2. Build containers locally
cd frontend && docker build -t ollama-frontend .
cd ../backend && docker build -t ollama-backend .

# 3. Deploy infrastructure
cd infra
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply

# 4. Get ALB DNS for frontend configuration
terraform output alb_dns_name
```

---

## 📚 Related Documentation

- **[aws-networking-GUIDE.md](./aws-networking-GUIDE.md)** - VPC networking and security verification
- **[docker.md](./docker.md)** - Docker containerization best practices
- **[flask.md](./flask.md)** - Flask application development patterns
- **[vite.md](./vite.md)** - Vite build configuration and optimization
- **[aws-cli.md](./aws-cli.md)** - AWS CLI setup and usage
- **[ec2-docker.md](./ec2-docker.md)** - EC2 Docker deployment strategies

---

## ❓ Decision Points & Customization Options

### Architecture Decisions
1. **Ollama Placement**: Co-located with Flask vs dedicated instances
2. **OS Choice**: Amazon Linux 2 vs Ubuntu 22.04
3. **TLS**: ALB termination vs HTTP-only for development
4. **Instance Size**: t3.medium vs t3.large vs memory-optimized (r5/m6)
5. **Deployment Strategy**: Terraform-only vs Terraform + SSM for app updates

### Customization Variables
- VPC CIDR range and subnet allocation
- Instance types and Auto Scaling parameters
- Ollama model selection and EBS volume sizing
- Multi-AZ vs single-AZ NAT Gateway strategy
- GitHub Container Registry vs other registries

---

**Next Steps**: Choose your architecture decisions and begin with Phase 1: Project Setup & Development Environment. Each phase builds upon the previous, creating a robust, scalable AI chat application ready for production deployment.
