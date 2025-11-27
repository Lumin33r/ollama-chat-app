# EC2 Instance Guide - Auto Scaling Architecture

> **Architecture Note**: This infrastructure uses **auto-scaling only** - no single-instance deployment mode. The application is **stateless** (no database, no persistent storage). Backend forwards requests to Ollama, frontend uses localStorage.

## Table of Contents

- [What is EC2?](#what-is-ec2)
- [EC2 in the Auto Scaling Architecture](#ec2-in-the-auto-scaling-architecture)
- [Launch Template Configuration](#launch-template-configuration)
- [User Data Bootstrap Scripts](#user-data-bootstrap-scripts)
- [Instance Metadata Service (IMDSv2)](#instance-metadata-service-imdsv2)
- [Auto Scaling Groups](#auto-scaling-groups)
- [Instance Access via Systems Manager](#instance-access-via-systems-manager)
- [How EC2 Fits Into the Infrastructure](#how-ec2-fits-into-the-infrastructure)
- [Design Decisions](#design-decisions)
- [Troubleshooting](#troubleshooting)

---

## What is EC2?

**Amazon Elastic Compute Cloud (EC2)** is AWS's virtual server service that provides resizable compute capacity in the cloud. Think of EC2 as renting a computer in AWS's data center that you can configure and control remotely.

### Key Concepts

| Concept                        | What It Is                                                   | Why It Matters                                                                 |
| ------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| **Virtual Server**             | A software-based computer running on AWS's physical hardware | You get the benefits of a server without buying/maintaining physical equipment |
| **Instance**                   | A running EC2 virtual machine                                | Each instance is an isolated environment for your application                  |
| **AMI (Amazon Machine Image)** | A template that contains the OS and software configuration   | Like a blueprint for creating identical servers quickly                        |
| **Instance Type**              | The hardware specification (CPU, memory, network)            | Different workloads need different amounts of resources                        |
| **Launch Template**            | A reusable instance configuration                            | Defines settings for Auto Scaling Groups to launch instances                   |

### Why Use EC2 with Auto Scaling?

1. **High Availability**: Multiple instances across availability zones
2. **Scalability**: Automatically add instances when traffic increases
3. **Cost-Effective**: Scale down during low traffic periods
4. **Fault Tolerance**: Failed instances are automatically replaced
5. **Load Distribution**: Traffic spread across healthy instances

---

## EC2 in the Auto Scaling Architecture

In the Ollama Chat application, EC2 instances are managed by **Auto Scaling Groups** that automatically adjust capacity based on CPU load.

### Architecture Overview

```
Internet
   ↓
Application Load Balancer (ALB) ← Public Subnets (2 AZs)
   ↓
   ├─→ Backend Target Group → Backend ASG → Backend EC2 Instances (Private Subnets)
   │                                            ├─ us-east-1a (min: 1, max: 2)
   │                                            └─ us-east-1b (min: 1, max: 2)
   │
   └─→ Frontend Target Group → Frontend ASG → Frontend EC2 Instances (Private Subnets)
                                                ├─ us-east-1a (min: 1, max: 2)
                                                └─ us-east-1b (min: 1, max: 2)
```

### Key Characteristics

| Characteristic       | Value                                              |
| -------------------- | -------------------------------------------------- |
| **Deployment Mode**  | Auto Scaling Groups only (no single-instance mode) |
| **Subnet Type**      | Private subnets (no public IPs)                    |
| **Multi-AZ**         | Instances distributed across 2 availability zones  |
| **Scaling**          | CPU-based (scale up >70% CPU, scale down <30% CPU) |
| **Access Method**    | AWS Systems Manager Session Manager (no SSH keys)  |
| **Storage**          | None - stateless application                       |
| **Backend Min/Max**  | 2 minimum, 4 maximum instances                     |
| **Frontend Min/Max** | 2 minimum, 4 maximum instances                     |

---

## Launch Template Configuration

Launch Templates define the configuration for EC2 instances that Auto Scaling Groups will create.

### Backend Launch Template

```hcl
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = var.ami_id
  instance_type = var.backend_instance_type

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ollama_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/backend-user-data.sh", {
    project_name = var.project_name
    git_repo_url = var.git_repo_url
    ollama_model = var.ollama_model
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-backend"
      Environment = var.environment
      Type        = "Backend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### Configuration Parameters

#### 1. AMI (Amazon Machine Image)

```hcl
image_id = var.ami_id
```

| Setting             | Description                                                    |
| ------------------- | -------------------------------------------------------------- |
| **What It Is**      | Template containing OS and base software                       |
| **Default**         | Amazon Linux 2023 or Ubuntu 22.04                              |
| **Why Variable**    | Easy to update AMI without changing Terraform code             |
| **Update Strategy** | Update variable → Terraform creates new instances with new AMI |

**Recommended AMIs for Ollama:**

- **Amazon Linux 2023**: AWS-optimized, Docker included, automatic security updates
- **Ubuntu 22.04 LTS**: Broader package ecosystem, more community support

#### 2. Instance Type

```hcl
instance_type = var.backend_instance_type  # or var.frontend_instance_type
```

| Instance Family | Use Case           | Example Types       | Pricing (Approx) |
| --------------- | ------------------ | ------------------- | ---------------- |
| **t3/t3a**      | Burstable, general | t3.medium, t3.large | $0.04-0.08/hour  |
| **m5/m6i**      | Balanced           | m5.large, m6i.large | $0.10-0.20/hour  |
| **c5/c6i**      | Compute-optimized  | c5.large, c6i.large | $0.09-0.17/hour  |

**Recommendations:**

- **Backend**: `t3.medium` (2 vCPU, 4GB) for development, `c5.large` (2 vCPU, 4GB) for production
- **Frontend**: `t3.small` (2 vCPU, 2GB) - serves static React build

#### 3. Security Groups

```hcl
vpc_security_group_ids = [aws_security_group.backend_sg.id]
```

| Setting                     | Description                                        |
| --------------------------- | -------------------------------------------------- |
| **Backend Security Group**  | Allows port 8000 from ALB only                     |
| **Frontend Security Group** | Allows port 3000 from ALB only                     |
| **Outbound**                | All traffic allowed (for NAT Gateway connectivity) |

**Security Principles:**

- ✅ Instances only accept traffic from ALB (not directly from internet)
- ✅ No SSH port 22 needed (using Systems Manager)
- ✅ Outbound traffic allowed for software updates and API calls

#### 4. IAM Instance Profile

```hcl
iam_instance_profile {
  name = aws_iam_instance_profile.ollama_profile.name
}
```

| Setting             | Description                                              |
| ------------------- | -------------------------------------------------------- |
| **Attached Policy** | `AmazonSSMManagedInstanceCore`                           |
| **Purpose**         | Allows Systems Manager Session Manager access            |
| **No SSH Keys**     | IAM-based authentication replaces SSH key pairs          |
| **Secure**          | No credentials stored on instance, automatically rotated |

**What Instances Can Do:**

- ✅ Register with Systems Manager for remote access
- ✅ Send session logs to CloudTrail (audit trail)
- ❌ Cannot create/modify AWS resources (security best practice)

#### 5. User Data Script

```hcl
user_data = base64encode(templatefile("${path.module}/backend-user-data.sh", {...}))
```

| Setting       | Description                                     |
| ------------- | ----------------------------------------------- |
| **Format**    | Base64-encoded bash script                      |
| **Execution** | Runs once at first boot                         |
| **Purpose**   | Install software, clone repo, start application |
| **Template**  | Uses `templatefile()` to inject variables       |

**Variables Passed to Script:**

- `project_name`: Used for naming, tagging
- `git_repo_url`: Repository to clone
- `ollama_model`: AI model to download

See [User Data Bootstrap Scripts](#user-data-bootstrap-scripts) section for details.

#### 6. Metadata Options (IMDSv2)

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
  instance_metadata_tags      = "enabled"
}
```

| Setting                       | Value      | Why This Value?                                   |
| ----------------------------- | ---------- | ------------------------------------------------- |
| `http_endpoint`               | `enabled`  | Allows instance to access metadata                |
| `http_tokens`                 | `required` | **Forces IMDSv2** (more secure)                   |
| `http_put_response_hop_limit` | `1`        | Prevents metadata access from containers/pods     |
| `instance_metadata_tags`      | `enabled`  | Tags accessible via metadata (useful for scripts) |

**Security Note**: IMDSv2 requires session tokens, preventing SSRF attacks. See [IMDSv2 section](#instance-metadata-service-imdsv2) for details.

---

## User Data Bootstrap Scripts

User data scripts run at instance launch to configure and start the application.

### Backend User Data Script

```bash
#!/bin/bash
set -e  # Exit on error

# Update system
yum update -y  # or apt-get update && apt-get upgrade -y for Ubuntu

# Install dependencies
yum install -y git python3 python3-pip docker

# Start Docker
systemctl start docker
systemctl enable docker

# Clone application repository
cd /home/ec2-user
git clone ${git_repo_url}
cd ollama-chat-app/backend

# Install Python dependencies
pip3 install -r requirements.txt

# Start Ollama container
docker run -d \
  --name ollama \
  -p 11434:11434 \
  -v /var/lib/ollama:/root/.ollama \
  ollama/ollama

# Wait for Ollama to start
sleep 10

# Pull AI model
docker exec ollama ollama pull ${ollama_model}

# Start Flask backend
cd src
python3 app.py &

# Log completion
echo "Backend initialization complete" >> /var/log/user-data.log
```

### Frontend User Data Script

```bash
#!/bin/bash
set -e

# Update system
yum update -y

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Clone repository
cd /home/ec2-user
git clone ${git_repo_url}
cd ollama-chat-app/frontend

# Install dependencies
npm install

# Build React app
npm run build

# Install serve to host static files
npm install -g serve

# Start frontend server on port 3000
serve -s dist -l 3000 &

echo "Frontend initialization complete" >> /var/log/user-data.log
```

### User Data Best Practices

| Best Practice              | Why It Matters                                  |
| -------------------------- | ----------------------------------------------- |
| **Use `set -e`**           | Script stops on first error (fail fast)         |
| **Log everything**         | Redirect output to `/var/log/user-data.log`     |
| **Use `systemctl enable`** | Services restart on reboot                      |
| **Wait for services**      | Add `sleep` or health checks before next step   |
| **Test incrementally**     | Test script manually before adding to Terraform |
| **Use templates**          | Inject variables instead of hardcoding          |

**Debugging User Data:**

```bash
# Connect via Session Manager
aws ssm start-session --target i-1234567890abcdef0

# Check user data script output
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/user-data.log

# Check if services are running
systemctl status docker
ps aux | grep python
ps aux | grep node
```

---

## Instance Metadata Service (IMDSv2)

### What is IMDS?

The **Instance Metadata Service** allows EC2 instances to retrieve information about themselves without using the AWS API.

### Metadata Available

| Metadata Path                                 | Information Provided        |
| --------------------------------------------- | --------------------------- |
| `/latest/meta-data/instance-id`               | Instance ID                 |
| `/latest/meta-data/local-ipv4`                | Private IP address          |
| `/latest/meta-data/public-ipv4`               | Public IP (if assigned)     |
| `/latest/meta-data/ami-id`                    | AMI used to launch instance |
| `/latest/meta-data/iam/security-credentials/` | Temporary IAM credentials   |

### IMDSv1 vs IMDSv2

| Feature               | IMDSv1 (Legacy)          | IMDSv2 (Enforced)        |
| --------------------- | ------------------------ | ------------------------ |
| **Authentication**    | None                     | Session token required   |
| **Security**          | Vulnerable to SSRF       | Protected against SSRF   |
| **Access Method**     | Simple HTTP GET          | Token + HTTP GET         |
| **Terraform Setting** | `http_tokens = optional` | `http_tokens = required` |

### Why IMDSv2?

**IMDSv1 Vulnerability (SSRF Attack)**:

```bash
# Attacker exploits application to access metadata
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/role-name
# Returns temporary AWS credentials - attacker can now access AWS services!
```

**IMDSv2 Protection**:

```bash
# Step 1: Get session token (requires PUT request - harder to exploit)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Step 2: Use token to access metadata
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id
```

**Enforcement in Terraform:**

```hcl
metadata_options {
  http_tokens = "required"  # Forces IMDSv2, blocks IMDSv1
  http_put_response_hop_limit = 1  # Prevents containers from accessing metadata
}
```

---

## Auto Scaling Groups

Auto Scaling Groups manage instance lifecycle, ensuring desired capacity across availability zones.

### Backend Auto Scaling Group

```hcl
resource "aws_autoscaling_group" "backend_asg" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  target_group_arns   = [aws_lb_target_group.backend_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.backend_min_size          # Default: 2
  max_size         = var.backend_max_size          # Default: 4
  desired_capacity = var.backend_desired_capacity  # Default: 2

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }
}
```

### Configuration Parameters

#### 1. VPC Zone Identifier (Subnets)

```hcl
vpc_zone_identifier = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
```

| Setting          | Value                                                |
| ---------------- | ---------------------------------------------------- |
| **Subnets**      | Private subnets in 2 different availability zones    |
| **Why Private**  | Instances don't need public IPs                      |
| **Why Multi-AZ** | High availability - if one AZ fails, other continues |
| **Distribution** | ASG evenly distributes instances across subnets      |

#### 2. Target Group Association

```hcl
target_group_arns = [aws_lb_target_group.backend_tg.arn]
```

| Setting            | Description                                      |
| ------------------ | ------------------------------------------------ |
| **Purpose**        | Automatically registers new instances with ALB   |
| **Health Checks**  | ALB performs health checks on registered targets |
| **Deregistration** | Unhealthy instances removed from rotation        |

#### 3. Health Check Configuration

```hcl
health_check_type         = "ELB"
health_check_grace_period = 300  # 5 minutes
```

| Setting             | Value | Why This Value?                                       |
| ------------------- | ----- | ----------------------------------------------------- |
| `health_check_type` | `ELB` | Use ALB health checks (more accurate than EC2)        |
| `grace_period`      | `300` | Wait 5 min for instance to initialize before checking |

**Health Check Process:**

1. Instance launches and runs user data script
2. ASG waits 5 minutes (grace period) before checking health
3. ALB checks `/health` endpoint on backend (port 8000)
4. If unhealthy after grace period, ASG terminates and replaces instance

#### 4. Capacity Configuration

```hcl
min_size         = 2
max_size         = 4
desired_capacity = 2
```

| Capacity    | Value | Why This Value?                                |
| ----------- | ----- | ---------------------------------------------- |
| **Min**     | `2`   | Always 2 instances minimum (high availability) |
| **Max**     | `4`   | Limit scaling to control costs                 |
| **Desired** | `2`   | Normal operating capacity                      |

**Scaling Behavior:**

- **Normal Traffic**: 2 instances running
- **High Traffic (CPU >70%)**: Scale up to 3, then 4 instances
- **Low Traffic (CPU <30%)**: Scale down to 3, then 2 instances
- **Never Below Min**: Always maintain 2 instances for availability

### Scaling Policies

#### Scale Up Policy

```hcl
resource "aws_autoscaling_policy" "backend_scale_up" {
  name                   = "${var.project_name}-backend-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}
```

| Setting              | Value              | Description                           |
| -------------------- | ------------------ | ------------------------------------- |
| `scaling_adjustment` | `1`                | Add 1 instance at a time              |
| `adjustment_type`    | `ChangeInCapacity` | Add/remove instances (not percentage) |
| `cooldown`           | `300`              | Wait 5 min before scaling again       |

#### CloudWatch Alarm (Trigger)

```hcl
resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.backend_scale_up.arn]
}
```

**How It Works:**

1. CloudWatch monitors average CPU across all backend instances
2. If CPU >70% for 2 consecutive 2-minute periods (4 minutes total)
3. Alarm triggers scale-up policy
4. ASG launches 1 additional instance
5. Cooldown period prevents immediate additional scaling

---

## Instance Access via Systems Manager

### Why Systems Manager Instead of SSH?

| Feature            | SSH with Keys                | Systems Manager           |
| ------------------ | ---------------------------- | ------------------------- |
| **Authentication** | SSH key pairs                | IAM policies              |
| **Key Management** | Store, rotate, distribute    | None needed               |
| **Bastion Host**   | Required for private subnets | Not needed                |
| **Audit Trail**    | Manual logging               | Automatic CloudTrail logs |
| **Network Access** | Port 22 must be open         | Uses HTTPS (port 443)     |
| **Cost**           | Bastion host ~$15-30/mo      | Free (included with EC2)  |

### Connecting to Instances

#### Via AWS Console

1. Go to **EC2 Console** → **Instances**
2. Select instance
3. Click **Connect** button
4. Choose **Session Manager** tab
5. Click **Connect**

#### Via AWS CLI

```bash
# List instances in Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ollama-chat-app-backend-asg \
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus]" \
  --output table

# Connect to specific instance
aws ssm start-session --target i-1234567890abcdef0
```

#### Via VS Code

1. Install **AWS Toolkit** extension
2. Configure AWS credentials
3. Navigate to **EC2** in AWS Explorer
4. Right-click instance → **Connect via Session Manager**

### Session Manager Capabilities

Once connected, you can:

```bash
# Check application status
systemctl status docker
ps aux | grep python
ps aux | grep node

# View logs
tail -f /var/log/user-data.log
journalctl -u docker -f

# Test application locally
curl http://localhost:8000/health
curl http://localhost:3000

# Debug network
netstat -tlnp
ss -tlnp

# Check IAM role
curl http://169.254.169.254/latest/meta-data/iam/info
```

### IAM Requirements

**For Users (to connect):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:StartSession", "ssm:TerminateSession"],
      "Resource": [
        "arn:aws:ec2:*:*:instance/*",
        "arn:aws:ssm:*:*:session/${aws:username}-*"
      ]
    }
  ]
}
```

**For Instances (IAM role):**

- Policy: `AmazonSSMManagedInstanceCore` (attached to `ollama_ec2_role`)

---

## How EC2 Fits Into the Infrastructure

### Request Flow

```
1. User Request
   ↓
2. DNS → ALB DNS Name
   ↓
3. ALB Security Group (allow 80/443)
   ↓
4. ALB Listener Rules
   ├─ /api/* → Backend Target Group
   │            ↓
   │         Backend Security Group (allow 8000 from ALB)
   │            ↓
   │         Backend EC2 Instances
   │            ↓
   │         Flask app forwards to Ollama container
   │
   └─ /* → Frontend Target Group
               ↓
            Frontend Security Group (allow 3000 from ALB)
               ↓
            Frontend EC2 Instances
               ↓
            Serve static React build
```

### Infrastructure Dependencies

```
Launch Template
   ↓
   ├─ AMI (what to run)
   ├─ Instance Type (hardware specs)
   ├─ Security Group (firewall rules)
   ├─ IAM Instance Profile (permissions)
   ├─ User Data Script (bootstrap)
   └─ Metadata Options (IMDSv2)
   ↓
Auto Scaling Group
   ↓
   ├─ Subnets (where to place)
   ├─ Target Group (load balancer integration)
   ├─ Health Checks (how to monitor)
   └─ Scaling Policies (when to scale)
   ↓
EC2 Instances (managed automatically)
```

---

## Design Decisions

### 1. Why Auto Scaling Only (No Single-Instance Mode)?

**Decision**: Removed single-instance deployment entirely

**Rationale:**

- **Simplicity**: One deployment model, less complexity
- **High Availability**: Auto Scaling provides fault tolerance
- **Production-Ready**: Encourages best practices from the start
- **Cost**: Difference minimal (2 t3.small vs 1 t3.medium)
- **Learning**: Better to learn production architecture early

**Cost Comparison:**

```
Single Instance:   1 × t3.medium  = $0.0416/hour = ~$30/month
Auto Scaling:      2 × t3.small   = $0.0208/hour = ~$30/month
```

### 2. Why Private Subnets for Instances?

**Decision**: All EC2 instances in private subnets

**Rationale:**

- **Security**: No direct internet exposure
- **Defense in Depth**: Attack must breach ALB first
- **Best Practice**: Industry standard for web applications
- **NAT Gateway**: Provides outbound internet for updates
- **Compliance**: Meets most security frameworks

**Alternative Considered**: Public subnets

- ❌ Every instance has public IP (larger attack surface)
- ❌ More difficult to secure
- ❌ Not production-grade

### 3. Why Systems Manager Instead of SSH?

**Decision**: No SSH keys, use Systems Manager

**Rationale:**

- **No Key Management**: Eliminates key distribution, rotation, storage
- **IAM-Based**: Centralized access control
- **Audit Trail**: Every session logged to CloudTrail
- **No Bastion**: Saves $15-30/month and security overhead
- **Port 443 Only**: Works through corporate firewalls

**Alternative Considered**: SSH with bastion host

- ❌ Requires managing bastion instance
- ❌ Requires SSH key distribution
- ❌ Additional cost and security surface
- ❌ Manual audit logging

### 4. Why IMDSv2 Required?

**Decision**: Enforce IMDSv2 (`http_tokens = required`)

**Rationale:**

- **SSRF Protection**: Prevents metadata access via application vulnerabilities
- **Security Best Practice**: AWS recommendation
- **Container Security**: `hop_limit = 1` prevents container access
- **No Downside**: Modern SDKs support IMDSv2

**Alternative Considered**: IMDSv1 optional

- ❌ Vulnerable to SSRF attacks
- ❌ Not compliant with security frameworks

### 5. Why Stateless Architecture?

**Decision**: No EBS volumes, no persistent storage

**Rationale:**

- **Application Design**: Backend forwards to Ollama (no database)
- **Frontend Storage**: Uses localStorage only
- **Simplicity**: No storage management needed
- **Cost**: Eliminates EBS charges (~$8-10/month per volume)
- **Scalability**: Instances are identical, easily replaceable

**What About Data Loss?**

- Backend: No state - each request is independent
- Frontend: User data in browser localStorage (client-side)
- Ollama Models: Cached in Docker container (re-downloaded if needed)

### 6. Why Multi-AZ Auto Scaling?

**Decision**: Distribute instances across 2 availability zones

**Rationale:**

- **High Availability**: If one datacenter fails, other continues
- **Load Distribution**: Even spread of traffic
- **ALB Requirement**: ALB needs 2+ subnets in different AZs
- **Cost**: Minimal (same instance hours, just distributed)

**Failure Scenario:**

```
Normal: 2 instances (1 in each AZ)
AZ-1 Fails: 1 instance in AZ-2 continues serving traffic
Auto Scaling: Launches replacement in AZ-2 to maintain min capacity
```

---

## Troubleshooting

### 1. Instances Not Launching

**Symptoms:**

- Auto Scaling Group shows 0 instances
- Instances launch and immediately terminate

**Common Causes:**

| Issue                        | Check                                               | Solution                                   |
| ---------------------------- | --------------------------------------------------- | ------------------------------------------ |
| **User data script fails**   | CloudWatch Logs or `/var/log/cloud-init-output.log` | Fix script syntax, test manually           |
| **AMI not found**            | Check `var.ami_id` is valid in region               | Update to correct AMI ID                   |
| **Security group not found** | Verify security group exists                        | Check Terraform dependencies               |
| **IAM role not attached**    | Instance profile configuration                      | Verify IAM role and instance profile exist |
| **Insufficient capacity**    | AWS capacity issues in AZ                           | Try different instance type or region      |

**Debugging:**

```bash
# Check Auto Scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ollama-chat-app-backend-asg \
  --max-records 10

# Check if launch template is valid
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-xxx

# Manually launch instance to test
aws ec2 run-instances \
  --launch-template LaunchTemplateId=lt-xxx \
  --subnet-id subnet-xxx
```

### 2. Instances Failing Health Checks

**Symptoms:**

- Instances launch but are marked unhealthy
- Auto Scaling continuously replaces instances

**Common Causes:**

| Issue                        | Check                                  | Solution                                      |
| ---------------------------- | -------------------------------------- | --------------------------------------------- |
| **Application not starting** | User data logs                         | Fix bootstrap script                          |
| **Wrong health check port**  | Target group health check settings     | Verify port 8000 (backend) or 3000 (frontend) |
| **Grace period too short**   | Instance needs more time to initialize | Increase `health_check_grace_period` to 600   |
| **Security group blocking**  | ALB can't reach instance port          | Verify security group allows ALB traffic      |
| **Application crashed**      | Application logs                       | Fix application errors                        |

**Debugging:**

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...

# Connect to instance via Session Manager
aws ssm start-session --target i-xxx

# Check application status
systemctl status docker
curl http://localhost:8000/health
curl http://localhost:3000

# Check logs
tail -f /var/log/user-data.log
journalctl -xe
```

### 3. Cannot Connect via Session Manager

**Symptoms:**

- "Session Manager is not available" error
- Instance not listed in Session Manager

**Common Causes:**

| Issue                           | Check                              | Solution                              |
| ------------------------------- | ---------------------------------- | ------------------------------------- |
| **IAM role not attached**       | Instance IAM role                  | Attach `AmazonSSMManagedInstanceCore` |
| **SSM agent not running**       | Agent status on instance           | Install/restart SSM agent             |
| **No internet connectivity**    | Instance can't reach SSM endpoints | Check NAT Gateway, route tables       |
| **Security group blocking 443** | Outbound rules                     | Allow HTTPS (443) outbound            |
| **User lacks permissions**      | Your IAM user/role                 | Add `ssm:StartSession` permission     |

**Debugging:**

```bash
# Check if instance is managed
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=ollama-chat-app-backend"

# Check IAM role on instance
aws ec2 describe-instances --instance-ids i-xxx \
  --query "Reservations[0].Instances[0].IamInstanceProfile"

# Test SSM endpoint connectivity (if you can SSH)
telnet ssm.us-east-1.amazonaws.com 443
```

### 4. High CPU / Instances Not Scaling

**Symptoms:**

- CPU consistently >70% but no scaling
- Not enough instances to handle traffic

**Common Causes:**

| Issue                         | Check                       | Solution                           |
| ----------------------------- | --------------------------- | ---------------------------------- |
| **Reached max capacity**      | Current count vs `max_size` | Increase `max_size` if needed      |
| **Alarm not configured**      | CloudWatch alarm state      | Verify alarm exists and is enabled |
| **Cooldown period**           | Recent scaling activity     | Wait for cooldown to expire        |
| **Insufficient instance cap** | AWS account limits          | Request service quota increase     |

**Debugging:**

```bash
# Check current capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ollama-chat-app-backend-asg \
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]"

# Check CloudWatch alarm
aws cloudwatch describe-alarms \
  --alarm-names ollama-chat-app-backend-cpu-high

# Check recent scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ollama-chat-app-backend-asg \
  --max-records 5
```

### 5. Application Not Responding

**Symptoms:**

- 502/504 errors from ALB
- Timeouts on requests

**Common Causes:**

| Issue                            | Check                       | Solution                            |
| -------------------------------- | --------------------------- | ----------------------------------- |
| **App not listening on port**    | `netstat -tlnp` on instance | Fix application configuration       |
| **Docker container not running** | `docker ps`                 | Restart container, check logs       |
| **Ollama not responding**        | `docker logs ollama`        | Restart Ollama container            |
| **Out of memory**                | `free -h`                   | Increase instance type memory       |
| **File descriptors exhausted**   | `ulimit -n`                 | Increase limits in user data script |

**Debugging:**

```bash
# Connect to instance
aws ssm start-session --target i-xxx

# Check what's listening
sudo netstat -tlnp | grep -E ':(8000|3000|11434)'

# Check Docker containers
sudo docker ps -a

# Check application logs
sudo journalctl -u docker -f
tail -f /var/log/user-data.log

# Test locally
curl http://localhost:8000/health
curl http://localhost:3000
curl http://localhost:11434/api/version  # Ollama
```

---

## Summary

### Key Takeaways

| Topic                | Key Point                                                     |
| -------------------- | ------------------------------------------------------------- |
| **Architecture**     | Auto Scaling only - no single-instance mode                   |
| **Networking**       | Private subnets across 2 AZs for high availability            |
| **Access**           | Systems Manager (no SSH keys or bastion hosts)                |
| **Storage**          | Stateless - no persistent storage or EBS volumes              |
| **Scaling**          | CPU-based with min 2, max 4 instances per service             |
| **Security**         | IMDSv2 required, security groups restrict traffic to ALB only |
| **Launch Templates** | Define instance configuration for Auto Scaling                |
| **User Data**        | Bootstrap scripts install and start application               |
| **Health Checks**    | ALB health checks determine instance health                   |
| **IAM**              | Instance profile with SSM policy only (no other AWS access)   |

### Production Readiness Checklist

- ✅ Multi-AZ deployment (2 availability zones)
- ✅ Auto Scaling Groups (automatic capacity management)
- ✅ Private subnets (instances not directly internet-accessible)
- ✅ Systems Manager access (secure, audited instance access)
- ✅ IMDSv2 enforced (protects against SSRF attacks)
- ✅ Health checks configured (automatic failure detection)
- ✅ CloudWatch alarms (triggers auto-scaling)
- ✅ Security groups (restrictive ingress, permissive egress)
- ✅ Stateless design (no data loss on instance replacement)
- ✅ Terraform managed (infrastructure as code)

---

## Related Documentation

- [Networking Guide](./prod-networking.md) - VPC, subnets, NAT Gateways, routing
- [Security Groups Guide](./security-groups.md) - Firewall rules, port configuration
- [IAM Guide](./iam.md) - Roles, policies, permissions for SSM access
- [Auto Scaling Guide](./auto-scaling.md) - Scaling policies, CloudWatch alarms
- [Application Load Balancer Guide](./alb.md) - Target groups, health checks, listeners
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/) - Official AWS documentation
- [AWS Systems Manager Guide](https://docs.aws.amazon.com/systems-manager/) - Session Manager details

---

**Last Updated**: November 26, 2025
**Architecture**: Simplified auto-scaling only (no storage, no single-instance mode)
**Terraform Version**: >= 1.0
**AWS Provider Version**: ~> 5.0
