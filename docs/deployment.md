# Ollama Chat App - Deployment Guide

Complete step-by-step guide to deploy the Ollama Chat application infrastructure and application to AWS using Terraform.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture Summary](#architecture-summary)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Phase 1: Terraform Setup](#phase-1-terraform-setup)
- [Phase 2: Deploy Infrastructure](#phase-2-deploy-infrastructure)
- [Phase 3: Verify Deployment](#phase-3-verify-deployment)
- [Phase 4: Application Configuration](#phase-4-application-configuration)
- [Phase 5: Testing](#phase-5-testing)
- [Phase 6: Monitoring and Scaling](#phase-6-monitoring-and-scaling)
- [Troubleshooting](#troubleshooting)
- [Rollback Procedures](#rollback-procedures)
- [Cost Estimation](#cost-estimation)

---

## Overview

This deployment will create a **production-ready, auto-scaling infrastructure** on AWS with:

- **Multi-AZ VPC** with public and private subnets
- **Application Load Balancer** for traffic distribution
- **Auto Scaling Groups** for backend (Flask + Ollama) and frontend (React)
- **NAT Gateways** for secure outbound internet access
- **IAM roles** for Systems Manager (SSM) access
- **CloudWatch alarms** for auto-scaling triggers

### Deployment Timeline

| Phase     | Task                      | Duration             |
| --------- | ------------------------- | -------------------- |
| 1         | Terraform Setup           | 5 minutes            |
| 2         | Infrastructure Deployment | 10-15 minutes        |
| 3         | Verification              | 5 minutes            |
| 4         | Application Configuration | Auto (via user-data) |
| 5         | Testing                   | 5-10 minutes         |
| **Total** | **End-to-End**            | **25-35 minutes**    |

---

## Prerequisites

### Required Tools

Install and configure the following tools on your local machine:

#### 1. AWS CLI

```bash
# Install AWS CLI (if not already installed)
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version  # Should show aws-cli/2.x.x or higher
```

#### 2. Terraform

```bash
# Install Terraform
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform version  # Should show Terraform v1.5+ or higher
```

#### 3. Git

```bash
# Verify Git is installed
git --version

# If not installed
# macOS
brew install git

# Linux
sudo apt-get install git
```

### AWS Account Setup

#### 1. Create AWS Account

If you don't have an AWS account:

1. Go to https://aws.amazon.com
2. Click "Create an AWS Account"
3. Follow the signup process
4. **Note**: You'll need a credit card, but most resources in this deployment qualify for the free tier

#### 2. Create IAM User for Terraform

**Best Practice**: Don't use root credentials. Create a dedicated IAM user.

```bash
# Log into AWS Console as root or admin user
# Navigate to: IAM → Users → Add users

# User details:
Username: terraform-deploy
Access type: Programmatic access (Access key - Programmatic access)

# Attach permissions:
# Option 1: For testing/learning (not recommended for production)
- AdministratorAccess

# Option 2: For production (minimum required permissions)
Create custom policy with:
- EC2FullAccess
- VPCFullAccess
- ElasticLoadBalancingFullAccess
- AutoScalingFullAccess
- IAMFullAccess
- CloudWatchFullAccess

# Save the Access Key ID and Secret Access Key!
# You won't be able to see the secret key again
```

#### 3. Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# You'll be prompted for:
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: us-east-1
Default output format [None]: json

# Verify configuration
aws sts get-caller-identity
# Should return your UserId, Account, and Arn
```

#### 4. Verify AWS Permissions

```bash
# Test that you can create EC2 resources
aws ec2 describe-instances --region us-east-1

# Test that you can list VPCs
aws ec2 describe-vpcs --region us-east-1

# If these commands work, you're ready to proceed
```

### Service Limits Check

Check your AWS account service limits:

```bash
# Check EC2 instance limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --region us-east-1

# You need at least 4 running instances:
# - 2 backend instances (t3.medium)
# - 2 frontend instances (t3.small)

# If your limit is too low, request an increase:
# AWS Console → Service Quotas → AWS services → Amazon EC2 → Running On-Demand Standard instances
```

---

## Architecture Summary

### What Will Be Created

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                      │ │
│  │                                                           │ │
│  │  ┌─────────────────────────────────────────────────┐    │ │
│  │  │         Public Subnets (2 AZs)                  │    │ │
│  │  │  - Application Load Balancer                    │    │ │
│  │  │  - NAT Gateways (2)                             │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  │                         ↓                                 │ │
│  │  ┌─────────────────────────────────────────────────┐    │ │
│  │  │         Private Subnets (2 AZs)                 │    │ │
│  │  │  - Backend ASG (2-4 instances)                  │    │ │
│  │  │    • Flask API (port 8000)                      │    │ │
│  │  │    • Ollama service                             │    │ │
│  │  │  - Frontend ASG (2-4 instances)                 │    │ │
│  │  │    • React app (port 3000)                      │    │ │
│  │  └─────────────────────────────────────────────────┘    │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Resource Count

| Resource Type             | Count       | Purpose                              |
| ------------------------- | ----------- | ------------------------------------ |
| VPC                       | 1           | Isolated network                     |
| Internet Gateway          | 1           | Public internet access               |
| NAT Gateways              | 2           | Private subnet internet access       |
| Public Subnets            | 2           | ALB and NAT Gateways                 |
| Private Subnets           | 2           | Application instances                |
| Application Load Balancer | 1           | Traffic distribution                 |
| Target Groups             | 2           | Backend and frontend routing         |
| Security Groups           | 3           | ALB, backend, frontend               |
| Launch Templates          | 2           | Backend and frontend instance config |
| Auto Scaling Groups       | 2           | Backend and frontend scaling         |
| IAM Roles                 | 1           | SSM access for instances             |
| CloudWatch Alarms         | 4           | Auto-scaling triggers                |
| EC2 Instances             | 4 (initial) | 2 backend + 2 frontend               |

---

## Pre-Deployment Checklist

Before running Terraform, ensure:

### ✅ 1. Repository Configuration

```bash
# Clone the repository (if not already done)
cd ~/projects
git clone https://github.com/yourusername/ollama-chat-app.git
cd ollama-chat-app

# Verify structure
ls -la
# Should see: backend/, frontend/, infra/, docs/
```

### ✅ 2. Update Git Repository URL

**CRITICAL**: Update the git repository URL in `terraform.tfvars`

```bash
cd infra
nano terraform.tfvars

# Update this line with your actual repository URL:
git_repo_url = "https://github.com/YOUR-USERNAME/ollama-chat-app.git"

# Save and exit (Ctrl+X, Y, Enter)
```

**Why?** The user-data scripts will clone this repository on each EC2 instance to deploy your application code.

### ✅ 3. Choose Ollama Model

Edit `terraform.tfvars` to select the AI model:

```bash
# Default is llama3.2:1b (smallest, fastest)
ollama_model = "llama3.2:1b"

# Options (larger models require more resources):
# llama3.2:1b   - 1B parameters, ~1GB, fastest
# llama3.2:3b   - 3B parameters, ~2GB, balanced
# llama2:7b     - 7B parameters, ~4GB, higher quality
# llama2:13b    - 13B parameters, ~8GB, best quality (requires larger instance)
```

**Recommendation**: Start with `llama3.2:1b` for initial testing, then upgrade if needed.

### ✅ 4. Verify AWS Configuration

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check default region
aws configure get region
# Should be: us-east-1 (or your preferred region)

# If you need to change region
aws configure set region us-east-1
```

### ✅ 5. Review Instance Types

In `terraform.tfvars`, verify instance types match your needs:

```bash
backend_instance_type  = "t3.medium"  # 2 vCPU, 4GB RAM
frontend_instance_type = "t3.small"   # 2 vCPU, 2GB RAM
```

**Cost Note**:

- `t3.medium`: ~$0.0416/hour × 2 instances = ~$60/month
- `t3.small`: ~$0.0208/hour × 2 instances = ~$30/month
- **Total**: ~$90/month for instances

### ✅ 6. Understand Auto Scaling Settings

Default configuration in `variables.tf`:

```hcl
# Backend: Flask + Ollama
backend_min_size         = 2  # Always at least 2 instances
backend_max_size         = 4  # Can scale up to 4 instances
backend_desired_capacity = 2  # Start with 2 instances

# Frontend: React
frontend_min_size         = 2
frontend_max_size         = 4
frontend_desired_capacity = 2
```

**When does it scale?**

- **Scale Up**: When average CPU > 70% for 4 minutes
- **Scale Down**: When average CPU < 30% for 4 minutes

---

## Phase 1: Terraform Setup

### Step 1: Navigate to Infrastructure Directory

```bash
cd ~/projects/ollama-chat-app/infra
```

### Step 2: Initialize Terraform

This downloads the AWS provider and prepares Terraform:

```bash
terraform init
```

**Expected Output:**

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
- Installed hashicorp/aws v5.x.x

Terraform has been successfully initialized!
```

**Troubleshooting:**

```bash
# If you see errors about provider versions
terraform init -upgrade

# If you see errors about missing files
ls -la  # Verify main.tf, variables.tf exist
```

### Step 3: Validate Configuration

Check that all Terraform files are syntactically correct:

```bash
terraform validate
```

**Expected Output:**

```
Success! The configuration is valid.
```

**If validation fails:**

```bash
# Check for syntax errors in the output
# Common issues:
# - Missing closing braces }
# - Typos in resource names
# - Missing required variables
```

### Step 4: Format Code (Optional)

```bash
terraform fmt
```

This automatically formats your `.tf` files with proper indentation.

### Step 5: Review Terraform Plan

**IMPORTANT**: Always review the plan before applying!

```bash
terraform plan
```

**What to Look For:**

```
Plan: X to add, 0 to change, 0 to destroy.

# You should see approximately:
# - 40+ resources to be created
# - 0 resources to be changed (first deployment)
# - 0 resources to be destroyed

# Key resources to verify:
✓ aws_vpc.ollama_vpc
✓ aws_subnet.public_subnet_1 and public_subnet_2
✓ aws_subnet.private_subnet_1 and private_subnet_2
✓ aws_internet_gateway.ollama_igw
✓ aws_nat_gateway.nat_gw_1 and nat_gw_2
✓ aws_lb.app_lb
✓ aws_autoscaling_group.backend_asg
✓ aws_autoscaling_group.frontend_asg
```

**Red Flags** (if you see these, STOP and investigate):

- More than 50 resources being created (might indicate duplication)
- Resources being destroyed (shouldn't happen on first deploy)
- Errors about missing variables
- Errors about invalid AMI IDs

### Step 6: Save the Plan (Optional but Recommended)

```bash
# Save plan to a file for review
terraform plan -out=tfplan

# View the saved plan
terraform show tfplan

# This ensures the apply step uses exactly this plan
```

---

## Phase 2: Deploy Infrastructure

### Step 1: Apply Terraform Configuration

**WARNING**: This will create real AWS resources that will incur costs!

```bash
terraform apply
```

**What Happens:**

1. Terraform shows you the plan again
2. You'll be prompted: `Do you want to perform these actions?`
3. Type **`yes`** and press Enter

**Alternative** (skip confirmation):

```bash
terraform apply -auto-approve
```

**OR** (use saved plan):

```bash
terraform apply tfplan
```

### Step 2: Monitor Deployment Progress

The deployment takes **10-15 minutes**. You'll see resources being created in real-time:

```
aws_vpc.ollama_vpc: Creating...
aws_vpc.ollama_vpc: Creation complete after 2s
aws_internet_gateway.ollama_igw: Creating...
aws_subnet.public_subnet_1: Creating...
...
aws_autoscaling_group.backend_asg: Creating...
aws_autoscaling_group.frontend_asg: Creating...
...

Apply complete! Resources: 42 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name = "ollama-chat-app-alb-1234567890.us-east-1.elb.amazonaws.com"
application_url = "http://ollama-chat-app-alb-1234567890.us-east-1.elb.amazonaws.com"
backend_api_url = "http://ollama-chat-app-alb-1234567890.us-east-1.elb.amazonaws.com/api"
...
```

### Step 3: Save Important Outputs

**CRITICAL**: Save these outputs for accessing your application!

```bash
# Save all outputs to a file
terraform output > deployment-info.txt

# Display specific outputs
terraform output alb_dns_name
terraform output application_url
terraform output backend_api_url

# Example:
# alb_dns_name = "ollama-chat-app-alb-1234567890.us-east-1.elb.amazonaws.com"
```

**Key Outputs You Need:**

| Output              | Purpose           | Example                                                          |
| ------------------- | ----------------- | ---------------------------------------------------------------- |
| `alb_dns_name`      | ALB DNS name      | `ollama-chat-app-alb-123.us-east-1.elb.amazonaws.com`            |
| `application_url`   | Frontend URL      | `http://ollama-chat-app-alb-123.us-east-1.elb.amazonaws.com`     |
| `backend_api_url`   | Backend API URL   | `http://ollama-chat-app-alb-123.us-east-1.elb.amazonaws.com/api` |
| `backend_asg_name`  | Backend ASG name  | `ollama-chat-app-backend-asg`                                    |
| `frontend_asg_name` | Frontend ASG name | `ollama-chat-app-frontend-asg`                                   |

### Step 4: Verify Terraform State

```bash
# View current state
terraform show

# List all resources
terraform state list

# You should see approximately 40+ resources
```

---

## Phase 3: Verify Deployment

### Step 1: Check Infrastructure in AWS Console

#### VPC Verification

```bash
# CLI method
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ollama-chat-app-vpc"

# Console method
# Go to: AWS Console → VPC → Your VPCs
# Look for: ollama-chat-app-vpc
# Verify: DNS hostnames enabled, DNS resolution enabled
```

#### Subnets Verification

```bash
# Check subnets
aws ec2 describe-subnets --filters "Name=tag:Project,Values=ollama-chat-app"

# Should see 4 subnets:
# - 2 public (with map_public_ip_on_launch = true)
# - 2 private (in different AZs)
```

#### Load Balancer Verification

```bash
# Check ALB status
aws elbv2 describe-load-balancers --names ollama-chat-app-alb

# Look for:
# State: active
# Scheme: internet-facing
# VPC ID: matches your VPC
```

### Step 2: Monitor Instance Launch

EC2 instances launch automatically via Auto Scaling Groups. This takes **5-10 minutes**.

```bash
# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ollama-chat-app-backend-asg ollama-chat-app-frontend-asg

# Check instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ollama-chat-app" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# Expected output:
# -----------------------------------------------------------------
# |                     DescribeInstances                         |
# +---------------------+-----------+---------------+--------------+
# | i-1234567890abcdef0 | running   | 10.0.11.x     | backend      |
# | i-0987654321fedcba0 | running   | 10.0.11.y     | backend      |
# | i-abcdef1234567890  | running   | 10.0.12.x     | frontend     |
# | i-fedcba0987654321  | running   | 10.0.12.y     | frontend     |
# +---------------------+-----------+---------------+--------------+
```

**Instance States:**

- `pending` → Instance is launching
- `running` → Instance is running (but app might still be initializing)
- `stopping` / `terminated` → Problem detected, check logs

### Step 3: Check Target Group Health

The ALB performs health checks on registered instances:

```bash
# Get target group ARNs
BACKEND_TG=$(terraform output -raw backend_target_group_arn)
FRONTEND_TG=$(terraform output -raw frontend_target_group_arn)

# Check backend target health
aws elbv2 describe-target-health --target-group-arn $BACKEND_TG

# Check frontend target health
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG

# Look for:
# TargetHealth: { State: "healthy" }
```

**Health Check States:**

| State       | Meaning                                           | Action                   |
| ----------- | ------------------------------------------------- | ------------------------ |
| `initial`   | Instance just registered, waiting for first check | Wait 2-5 minutes         |
| `healthy`   | Instance passing health checks                    | ✅ Good!                 |
| `unhealthy` | Instance failing health checks                    | Check logs (Step 4)      |
| `draining`  | Instance being deregistered                       | Normal during updates    |
| `unused`    | Target not registered                             | Check Auto Scaling Group |

**Health Check Grace Period**: 5 minutes (300 seconds) - instances won't be checked until after this period.

### Step 4: Check Application Logs

Connect to instances via Systems Manager Session Manager:

```bash
# List backend instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ollama-chat-app-backend" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text

# Connect to first backend instance (replace with actual instance ID)
aws ssm start-session --target i-1234567890abcdef0

# Once connected, check logs:
sudo tail -f /var/log/user-data.log

# Look for:
# "=== Backend Instance Setup Complete ==="
# If you see errors, read through the log to identify the issue

# Check if Ollama is running
systemctl status ollama

# Check if backend service is running
ps aux | grep python
curl http://localhost:8000/health

# Exit session
exit
```

**Common Log Messages:**

| Message                                     | Status                                     |
| ------------------------------------------- | ------------------------------------------ |
| `=== Starting Backend Instance Setup ===`   | Beginning initialization                   |
| `=== Installing Docker ===`                 | Installing dependencies                    |
| `=== Pulling Ollama model: llama3.2:1b ===` | Downloading AI model (can take 5+ minutes) |
| `=== Backend Instance Setup Complete ===`   | ✅ Success!                                |
| `Error: ...`                                | ❌ Problem - investigate                   |

---

## Phase 4: Application Configuration

The application configures itself automatically via **user-data scripts** during instance launch. No manual configuration needed!

### What Happens Automatically

#### Backend Instances (user-data-backend.sh)

1. **System Updates** (~2 minutes)

   ```bash
   apt-get update && apt-get upgrade -y
   ```

2. **Install Dependencies** (~3 minutes)

   - Docker and Docker Compose
   - Python 3 and pip
   - Git
   - CloudWatch agent

3. **Install Ollama** (~1 minute)

   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   systemctl enable ollama
   systemctl start ollama
   ```

4. **Pull AI Model** (~5 minutes for llama3.2:1b)

   ```bash
   ollama pull llama3.2:1b
   ```

5. **Clone Repository and Start Backend** (~1 minute)
   ```bash
   git clone <your-repo-url> /home/ubuntu/app
   cd /home/ubuntu/app/backend
   pip3 install -r requirements.txt
   python3 src/app.py
   ```

**Total Time**: ~12 minutes per backend instance

#### Frontend Instances (user-data-frontend.sh)

1. **System Updates** (~2 minutes)
2. **Install Dependencies** (~3 minutes)

   - Docker and Docker Compose
   - Node.js 18
   - Git
   - CloudWatch agent

3. **Clone Repository** (~1 minute)
4. **Build and Serve Frontend** (~2 minutes)
   ```bash
   cd /home/ubuntu/app/frontend
   npm install
   npm run build
   serve -s dist -l 3000
   ```

**Total Time**: ~8 minutes per frontend instance

### Monitoring Initialization Progress

```bash
# Check instance system logs
aws ec2 get-console-output --instance-id i-1234567890abcdef0

# Or connect via SSM and tail logs
aws ssm start-session --target i-1234567890abcdef0
sudo tail -f /var/log/user-data.log
```

### Verify Application Configuration

```bash
# Connect to backend instance
aws ssm start-session --target <backend-instance-id>

# Check Ollama models
ollama list
# Should show: llama3.2:1b (or your chosen model)

# Check backend is responding
curl http://localhost:8000/health
# Should return: {"status": "healthy", "ollama_connected": true}

# Check backend can reach Ollama
curl http://localhost:8000/api/models
# Should return: {"models": ["llama3.2:1b"], "count": 1}

# Exit
exit
```

```bash
# Connect to frontend instance
aws ssm start-session --target <frontend-instance-id>

# Check if frontend is serving
curl http://localhost:3000
# Should return: HTML content (React app)

# Exit
exit
```

---

## Phase 5: Testing

### Step 1: Test ALB Health Endpoint

Wait until target groups show `healthy` status, then:

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test backend health through ALB
curl http://$ALB_DNS/health

# Expected response:
# {
#   "status": "healthy",
#   "ollama_connected": true,
#   "ollama_host": "localhost:11434",
#   "models_available": 1
# }

# If you get 503 Service Unavailable, wait a few more minutes
```

### Step 2: Test Backend API Endpoints

```bash
# List available models
curl http://$ALB_DNS/api/models

# Expected response:
# {
#   "models": ["llama3.2:1b"],
#   "count": 1
# }

# Test chat endpoint
curl -X POST http://$ALB_DNS/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Say hello!",
    "model": "llama3.2:1b"
  }'

# Expected response:
# {
#   "response": "Hello! How can I help you today?",
#   "conversation_id": "default",
#   "model": "llama3.2:1b"
# }
```

### Step 3: Test Frontend in Browser

```bash
# Get application URL
terraform output application_url

# Copy and paste into browser
# Example: http://ollama-chat-app-alb-1234567890.us-east-1.elb.amazonaws.com
```

**What You Should See:**

1. React app loads with chat interface
2. Sidebar shows "Ollama Chat"
3. You can type messages
4. Bot responds with AI-generated text

**Frontend Features to Test:**

- [ ] Send a message and receive response
- [ ] Create new conversation
- [ ] Switch between conversations
- [ ] Delete conversation
- [ ] Verify messages persist in localStorage

### Step 4: Test Auto Scaling

#### Verify Auto Scaling Configuration

```bash
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name ollama-chat-app-backend-asg

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-names ollama-chat-app-backend-cpu-high ollama-chat-app-backend-cpu-low
```

#### Manually Trigger Scaling (Optional)

**Scale Up Test:**

```bash
# Connect to backend instance
aws ssm start-session --target <backend-instance-id>

# Generate CPU load
stress --cpu 4 --timeout 600s
# Or if stress not installed:
for i in {1..4}; do while : ; do : ; done & done

# Watch scaling in separate terminal
watch -n 10 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ollama-chat-app-backend-asg \
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,HealthStatus]]"'

# After 4 minutes of >70% CPU, should scale from 2 → 3 instances
# After another 4 minutes if still high, scales 3 → 4 instances
```

**Scale Down Test:**

```bash
# Stop the stress test (Ctrl+C on all stress processes)
killall stress

# Wait 4 minutes of <30% CPU
# Should scale down 4 → 3 → 2 instances
```

### Step 5: Test High Availability (Multi-AZ)

```bash
# List instances and their availability zones
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ollama-chat-app" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,Tags[?Key=='Name'].Value|[0]]" \
  --output table

# You should see:
# - 1 backend in us-east-1a
# - 1 backend in us-east-1b
# - 1 frontend in us-east-1a
# - 1 frontend in us-east-1b
```

**Simulate AZ Failure** (Don't do this in production!):

```bash
# Terminate all instances in one AZ
INSTANCES_IN_AZ1=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ollama-chat-app" \
          "Name=placement-availability-zone,Values=us-east-1a" \
          "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

# WARNING: This will terminate instances!
aws ec2 terminate-instances --instance-ids $INSTANCES_IN_AZ1

# Watch Auto Scaling replace them
watch -n 10 'aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=ollama-chat-app" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,Placement.AvailabilityZone]" \
  --output table'

# Within 5 minutes, Auto Scaling will launch replacement instances
# Application remains available via instances in us-east-1b
```

---

## Phase 6: Monitoring and Scaling

### CloudWatch Dashboard (Optional)

Create a dashboard to monitor your application:

```bash
# Create dashboard via CLI
aws cloudwatch put-dashboard --dashboard-name ollama-chat-app \
  --dashboard-body file://cloudwatch-dashboard.json

# Or use AWS Console:
# CloudWatch → Dashboards → Create dashboard → Add widgets
```

**Metrics to Monitor:**

| Metric             | Namespace          | Dimensions           | Threshold       |
| ------------------ | ------------------ | -------------------- | --------------- |
| CPUUtilization     | AWS/EC2            | AutoScalingGroupName | >70% = scale up |
| HealthyHostCount   | AWS/ApplicationELB | TargetGroup          | <2 = alert      |
| RequestCount       | AWS/ApplicationELB | LoadBalancer         | Monitor traffic |
| TargetResponseTime | AWS/ApplicationELB | LoadBalancer         | >5s = slow      |

### View Current Metrics

```bash
# Backend ASG CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=ollama-chat-app-backend-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn | cut -d: -f6) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Set Up Alerts (Recommended)

Create SNS topic for alerts:

```bash
# Create SNS topic
aws sns create-topic --name ollama-chat-app-alerts

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:ollama-chat-app-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription via email link

# Add alarm for unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name ollama-chat-app-unhealthy-targets \
  --alarm-description "Alert when target count drops below 2" \
  --metric-name HealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 2 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=TargetGroup,Value=$(terraform output -raw backend_target_group_arn | cut -d: -f6-) \
  --alarm-actions arn:aws:sns:us-east-1:YOUR-ACCOUNT-ID:ollama-chat-app-alerts
```

---

## Troubleshooting

### Issue 1: Instances Stuck in "Initial" Health State

**Symptom**: Target groups show instances in `initial` state for >10 minutes

**Diagnosis:**

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Connect to instance
aws ssm start-session --target <instance-id>

# Check user-data script progress
sudo tail -f /var/log/user-data.log

# Check if app is running
curl http://localhost:8000/health  # backend
curl http://localhost:3000         # frontend
```

**Common Causes:**

1. **User-data script still running**

   - Solution: Wait. Ollama model download takes 5-10 minutes.

2. **App failed to start**

   - Check logs for errors: `sudo cat /var/log/user-data.log`
   - Look for Python errors, missing dependencies, or Ollama connection issues

3. **Wrong health check port**

   - Verify target group health check port: 8000 (backend) or 3000 (frontend)
   - Fix in main.tf and reapply

4. **Security group blocking ALB**
   - Verify backend security group allows port 8000 from ALB security group
   - Verify frontend security group allows port 3000 from ALB security group

### Issue 2: 502 Bad Gateway from ALB

**Symptom**: Browser shows "502 Bad Gateway"

**Diagnosis:**

```bash
# Check if any targets are healthy
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check ALB access logs (if enabled)
# Console: EC2 → Load Balancers → Attributes → Access logs
```

**Solutions:**

1. **No healthy targets**

   - Wait for instances to finish initializing
   - Check target health (see Issue 1)

2. **Application crashed after starting**

   - Connect via SSM: `aws ssm start-session --target <instance-id>`
   - Check if app is running: `ps aux | grep python` (backend) or `ps aux | grep node` (frontend)
   - Check application logs

3. **Ollama not running (backend only)**
   ```bash
   sudo systemctl status ollama
   sudo systemctl restart ollama
   ollama list  # Verify model is loaded
   ```

### Issue 3: Cannot Connect via Session Manager

**Symptom**: "Session Manager is not available for this instance"

**Diagnosis:**

```bash
# Check if instance has IAM role
aws ec2 describe-instances --instance-ids <instance-id> \
  --query "Reservations[0].Instances[0].IamInstanceProfile"

# Check if SSM agent is running
# (Must connect via EC2 Instance Connect or check System Log)
```

**Solutions:**

1. **IAM role not attached**

   - Verify in Terraform: `aws_iam_instance_profile.ollama_profile`
   - Check policy: `AmazonSSMManagedInstanceCore` attached to role

2. **No internet connectivity**

   - Verify NAT Gateway is running: `aws ec2 describe-nat-gateways`
   - Check route tables: Private subnets should route 0.0.0.0/0 to NAT Gateway
   - Verify security group allows HTTPS (443) outbound

3. **SSM agent not installed/running**
   - Ubuntu 20.04+ includes SSM agent by default
   - Check user-data script completed successfully

### Issue 4: High Costs / Unexpected Charges

**Symptom**: AWS bill higher than expected

**Diagnosis:**

```bash
# Check running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime]"

# Check NAT Gateway data processing
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=<nat-gateway-id> \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

**Common Causes:**

1. **Auto Scaling scaled up and didn't scale down**

   - Check current instance count vs desired capacity
   - Manually set desired capacity: `aws autoscaling set-desired-capacity ...`

2. **NAT Gateway data transfer**

   - $0.045/GB processed
   - Minimize unnecessary downloads in user-data scripts

3. **Elastic IPs not associated**
   - Unassociated Elastic IPs cost $0.005/hour
   - Check: `aws ec2 describe-addresses`

**Cost Reduction:**

```bash
# Reduce minimum instances (not recommended for production)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name ollama-chat-app-backend-asg \
  --min-size 1 --desired-capacity 1

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name ollama-chat-app-frontend-asg \
  --min-size 1 --desired-capacity 1

# Use smaller instance types (update terraform.tfvars)
backend_instance_type  = "t3.small"   # Instead of t3.medium
frontend_instance_type = "t3.micro"   # Instead of t3.small

# Then: terraform apply
```

### Issue 5: Terraform Apply Fails

**Common Errors:**

1. **"Error creating VPC: VpcLimitExceeded"**

   - Solution: Delete unused VPCs or request limit increase
   - Check: AWS Console → VPC → Your VPCs

2. **"Error creating AutoScaling Group: InsufficientInstanceCapacity"**

   - Solution: Try different availability zone or instance type
   - Update `variables.tf`: Change instance type or add more AZs

3. **"Error creating IAM Role: EntityAlreadyExists"**

   - Solution: Import existing role or use different project_name

   ```bash
   terraform import aws_iam_role.ollama_ec2_role ollama-chat-app-ec2-role
   terraform apply
   ```

4. **"Error: InvalidAMIID.NotFound"**
   - Solution: Update AMI ID in `terraform.tfvars`
   ```bash
   # Find latest Ubuntu 22.04 AMI in your region
   aws ec2 describe-images \
     --owners 099720109477 \
     --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
     --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
     --output text
   ```

---

## Rollback Procedures

### Rollback Plan

If deployment fails or application has critical issues:

### Option 1: Rollback to Previous State (If Terraform State Exists)

```bash
# This only works if you saved previous state
# Not applicable for first deployment

# View state backups
ls -la terraform.tfstate*

# Restore previous state
mv terraform.tfstate terraform.tfstate.failed
mv terraform.tfstate.backup terraform.tfstate

# Apply previous state
terraform apply
```

### Option 2: Complete Infrastructure Teardown

**WARNING**: This destroys ALL resources!

```bash
# Destroy everything
terraform destroy

# Review what will be destroyed
# Type 'yes' to confirm

# Verify destruction
aws ec2 describe-instances --filters "Name=tag:Project,Values=ollama-chat-app"
# Should return no results
```

### Option 3: Partial Rollback (Remove Problematic Resources)

```bash
# Remove specific resource from state (without destroying)
terraform state rm aws_autoscaling_group.backend_asg

# Or destroy specific resource
terraform destroy -target=aws_autoscaling_group.backend_asg

# Then fix the issue and reapply
terraform apply
```

### Emergency: Stop All Instances (Preserve Infrastructure)

```bash
# Stop Auto Scaling (prevents new instances from launching)
aws autoscaling suspend-processes \
  --auto-scaling-group-name ollama-chat-app-backend-asg

aws autoscaling suspend-processes \
  --auto-scaling-group-name ollama-chat-app-frontend-asg

# Set desired capacity to 0
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ollama-chat-app-backend-asg \
  --desired-capacity 0

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ollama-chat-app-frontend-asg \
  --desired-capacity 0

# This terminates instances but keeps infrastructure
# To resume:
aws autoscaling resume-processes --auto-scaling-group-name ollama-chat-app-backend-asg
aws autoscaling set-desired-capacity --auto-scaling-group-name ollama-chat-app-backend-asg --desired-capacity 2
```

---

## Cost Estimation

### Monthly Cost Breakdown

Based on **us-east-1** pricing (as of November 2025):

| Resource                      | Configuration            | Hourly Cost       | Monthly Cost    |
| ----------------------------- | ------------------------ | ----------------- | --------------- |
| **EC2 Instances (Backend)**   | 2× t3.medium (on-demand) | $0.0832           | ~$60            |
| **EC2 Instances (Frontend)**  | 2× t3.small (on-demand)  | $0.0416           | ~$30            |
| **NAT Gateways**              | 2× (one per AZ)          | $0.090            | ~$65            |
| **NAT Gateway Data**          | ~500GB/month             | $0.045/GB         | ~$23            |
| **Application Load Balancer** | 1×                       | $0.0225           | ~$16            |
| **ALB Data Processing**       | ~100GB/month             | $0.008/GB         | ~$1             |
| **EBS Storage**               | 4× 20GB gp3              | $0.08/GB-month    | ~$6             |
| **Elastic IPs**               | 2× (for NAT)             | Free (associated) | $0              |
| **Data Transfer Out**         | First 100GB free         | After free tier   | ~$5             |
|                               |                          | **TOTAL**         | **~$206/month** |

### Cost Optimization Options

#### 1. Reduce to Single-AZ (NOT Recommended for Production)

**Savings**: ~$45/month (1 NAT Gateway)

```hcl
# Remove second AZ resources
# Not recommended - loses high availability
```

#### 2. Use Smaller Instance Types

**Savings**: ~$20-40/month

```hcl
backend_instance_type  = "t3.small"   # Save ~$30/month
frontend_instance_type = "t3.micro"   # Save ~$10/month
```

#### 3. Reserved Instances (1-Year Commitment)

**Savings**: ~40% on EC2 costs = ~$36/month

```bash
# Purchase Reserved Instances via Console
# AWS Console → EC2 → Reserved Instances → Purchase Reserved Instances
# Select: t3.medium (2x) and t3.small (2x)
# Term: 1 year, Payment: All upfront or No upfront
```

#### 4. Use Spot Instances (High Risk)

**Savings**: Up to 90% on EC2 costs = ~$81/month

**Risk**: Instances can be terminated with 2-minute warning

```hcl
# In launch template, add:
instance_market_options {
  market_type = "spot"
  spot_options {
    max_price = "0.05"  # Maximum you'll pay per hour
  }
}
```

#### 5. Stop Instances During Off-Hours

**Savings**: ~$45/month (if stopped 50% of time)

```bash
# Create Lambda function to start/stop on schedule
# Or use AWS Instance Scheduler
```

### Free Tier Eligibility

**New AWS Accounts** get 12 months free tier:

- 750 hours/month of t2.micro (can replace t3.small)
- 15GB data transfer out
- 1GB NAT Gateway data processing

**Estimated Cost with Free Tier**: ~$140/month (first year)

---

## Next Steps

After successful deployment:

### 1. Configure Custom Domain (Optional)

```bash
# Create Route 53 hosted zone
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)

# Create A record pointing to ALB
ALB_ZONE_ID=$(terraform output -raw alb_zone_id)
ALB_DNS=$(terraform output -raw alb_dns_name)

# Add to Route 53 via Console or CLI
# AWS Console → Route 53 → Hosted zones → Create record
# Name: chat.yourdomain.com
# Type: A - IPv4 address
# Alias: Yes → Alias to Application Load Balancer
# Region: us-east-1
# Load Balancer: Select your ALB
```

### 2. Add SSL/TLS Certificate

```bash
# Request certificate in ACM
aws acm request-certificate \
  --domain-name chat.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# Add CNAME records for validation
# Update ALB listener to use HTTPS (port 443)
```

### 3. Set Up CI/CD Pipeline

Create GitHub Actions workflow for automated deployments:

```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to AWS
        run: |
          # Update application code
          # Trigger rolling deployment
```

### 4. Enable Enhanced Monitoring

```bash
# Enable detailed CloudWatch metrics
# Console: EC2 → Auto Scaling Groups → Monitoring → Enable
```

### 5. Implement Backup Strategy

```bash
# Snapshot launch templates
# Backup Terraform state to S3
# Document recovery procedures
```

---

## Summary

You've successfully deployed a production-ready, auto-scaling Ollama Chat application on AWS!

**What You've Accomplished:**

- ✅ Multi-AZ infrastructure for high availability
- ✅ Auto-scaling based on CPU metrics
- ✅ Load-balanced traffic distribution
- ✅ Secure instance access via Systems Manager
- ✅ Automated instance configuration via user-data
- ✅ Stateless architecture for easy scaling

**Infrastructure At A Glance:**

- **VPC**: 1 (10.0.0.0/16)
- **Subnets**: 4 (2 public, 2 private across 2 AZs)
- **Load Balancer**: 1 Application Load Balancer
- **EC2 Instances**: 4 initial (2 backend, 2 frontend)
- **Auto Scaling**: CPU-based (70% up, 30% down)
- **Cost**: ~$206/month (optimizable to ~$140)

**Access Your Application:**

```bash
# Get URLs
terraform output application_url
terraform output backend_api_url

# Monitor status
aws elbv2 describe-target-health --target-group-arn <arn>

# Access instances
aws ssm start-session --target <instance-id>
```

---

## Related Documentation

- [EC2 Guide](./ec2.md) - Instance configuration and auto-scaling
- [Networking Guide](./prod-networking.md) - VPC, subnets, and network architecture
- [Terraform Documentation](https://www.terraform.io/docs) - Terraform reference

---

**Last Updated**: November 26, 2025
**Terraform Version**: >= 1.0
**AWS Provider Version**: ~> 5.0
**Deployment Time**: 25-35 minutes
**Estimated Cost**: $140-206/month
