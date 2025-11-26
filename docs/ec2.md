# EC2 Instance Guide

## Table of Contents

- [What is EC2?](#what-is-ec2)
- [EC2 in the Ollama Chat Infrastructure](#ec2-in-the-ollama-chat-infrastructure)
- [EC2 Instance Configuration Breakdown](#ec2-instance-configuration-breakdown)
- [Root Block Device (EBS Storage)](#root-block-device-ebs-storage)
- [User Data (Bootstrap Scripts)](#user-data-bootstrap-scripts)
- [Instance Metadata Service (IMDSv2)](#instance-metadata-service-imdsv2)
- [Lifecycle Management](#lifecycle-management)
- [How EC2 Fits Into the Greater Infrastructure](#how-ec2-fits-into-the-greater-infrastructure)
- [Single-Instance vs Auto Scaling Architecture](#single-instance-vs-auto-scaling-architecture)
- [Design Decisions and Best Practices](#design-decisions-and-best-practices)
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
| **Instance Store vs EBS**      | Temporary vs persistent storage                              | EBS volumes persist data even when instances stop                              |

### Why Use EC2?

1. **Flexibility**: Choose exact hardware specs you need
2. **Scalability**: Launch more instances when traffic increases
3. **Cost-Effective**: Pay only for what you use
4. **Control**: Full administrative access to configure as needed
5. **Integration**: Works seamlessly with other AWS services

---

## EC2 in the Ollama Chat Infrastructure

In the Ollama Chat application, EC2 instances serve as the **compute layer** that runs your application code. Here's how they fit into the overall architecture:

```
Internet
   ↓
Internet Gateway (IGW)
   ↓
Application Load Balancer (ALB) ← Public Subnets
   ↓                                  ↑
Security Groups (Firewall)            |
   ↓                                  |
EC2 Instances ←→ NAT Gateway ─────────┘
   ↓             (Private Subnets)
   ↓
IAM Role (Permissions)
   ↓
EBS Volumes (Storage)
   ↓
CloudWatch (Monitoring)
```

### Infrastructure Layers and EC2's Role

| Layer              | Component              | EC2's Interaction                                     |
| ------------------ | ---------------------- | ----------------------------------------------------- |
| **Network**        | VPC, Subnets           | EC2 instances are placed in subnets within the VPC    |
| **Security**       | Security Groups, NACLs | Control what traffic can reach EC2 instances          |
| **Identity**       | IAM Roles              | Give EC2 instances permissions to access AWS services |
| **Storage**        | EBS Volumes            | Provide persistent disk storage for EC2 instances     |
| **Load Balancing** | ALB                    | Distributes traffic across multiple EC2 instances     |
| **Monitoring**     | CloudWatch             | Collects metrics and logs from EC2 instances          |
| **Access**         | SSH Key Pairs          | Allow secure login to EC2 instances                   |

---

## EC2 Instance Configuration Breakdown

Let's examine each part of the EC2 instance resource in detail:

```hcl
resource "aws_instance" "ollama_app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ollama_key.key_name
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.ollama_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ollama_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    project_name = var.project_name
    git_repo_url = var.git_repo_url
    ollama_model = var.ollama_model
    domain_name  = var.domain_name
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-instance"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
```

### Core Configuration Parameters

#### 1. AMI (Amazon Machine Image)

```hcl
ami = var.ami_id
```

| Attribute           | Description                                                                             |
| ------------------- | --------------------------------------------------------------------------------------- |
| **What It Is**      | A template that contains the operating system, software, and configuration              |
| **Common Examples** | Amazon Linux 2023, Ubuntu 22.04, Amazon Linux 2                                         |
| **How to Choose**   | Consider OS compatibility, software requirements, and AWS optimization                  |
| **Why It Matters**  | Different AMIs have different packages, configurations, and performance characteristics |

**Design Decision**: This configuration uses a variable so you can easily change AMIs without editing the Terraform code. Common choices for Ollama:

- **Amazon Linux 2023**: AWS-optimized, good for Docker, free-tier eligible
- **Ubuntu 22.04 LTS**: More software packages, better community support
- **Deep Learning AMI**: Pre-installed ML frameworks (if using GPU instances)

#### 2. Instance Type

```hcl
instance_type = var.instance_type
```

| Instance Family | Use Case                   | Example Types           | Pricing (Approx) |
| --------------- | -------------------------- | ----------------------- | ---------------- |
| **t3/t3a**      | General purpose, burstable | t3.medium, t3.large     | $0.04-0.08/hour  |
| **m5/m6i**      | Balanced compute/memory    | m5.large, m6i.xlarge    | $0.10-0.20/hour  |
| **c5/c6i**      | Compute-optimized          | c5.xlarge, c6i.2xlarge  | $0.17-0.34/hour  |
| **r5/r6i**      | Memory-optimized           | r5.large, r6i.xlarge    | $0.13-0.25/hour  |
| **g4dn/p3**     | GPU instances (ML/AI)      | g4dn.xlarge, p3.2xlarge | $0.53-3.05/hour  |

**For Ollama Chat Application**:

- **Development**: `t3.medium` (2 vCPU, 4GB RAM) - minimal cost
- **Production (CPU)**: `c5.2xlarge` (8 vCPU, 16GB RAM) - faster inference
- **Production (GPU)**: `g4dn.xlarge` (4 vCPU, 16GB RAM, 1 GPU) - optimal for large models

**Design Decision**: Using a variable allows you to:

- Start small during development
- Scale up for production
- Test different instance types without code changes

#### 3. SSH Key Pair

```hcl
key_name = aws_key_pair.ollama_key.key_name
```

| Attribute         | Value                                          |
| ----------------- | ---------------------------------------------- |
| **What It Is**    | Public key cryptography for SSH authentication |
| **Purpose**       | Secure login to EC2 instance without passwords |
| **Reference**     | Points to `aws_key_pair.ollama_key` resource   |
| **Security Note** | Private key NEVER leaves your local machine    |

**How It Works**:

1. You generate a public/private key pair locally
2. Terraform uploads the public key to AWS
3. AWS injects the public key into the EC2 instance at launch
4. You use your private key to SSH into the instance

**See Also**: [IAM Guide](./iam-GUIDE.md#ssh-key-pairs) for detailed key pair setup instructions.

#### 4. Subnet Placement

```hcl
subnet_id = aws_subnet.public_subnet_1.id
```

| Attribute             | Value                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| **What It Is**        | The network segment where the instance will be placed                        |
| **Subnet Type**       | Public subnet (has route to Internet Gateway)                                |
| **Availability Zone** | Placed in the first available AZ in the region                               |
| **IP Assignment**     | Automatically receives a public IP (due to `map_public_ip_on_launch = true`) |

**Design Decision**: This single-instance deployment uses a public subnet because:

- Direct internet access for HTTP/HTTPS traffic
- Simplifies initial setup (no NAT Gateway required for single instance)
- Lower cost for development/testing environments

**Production Consideration**: For the Auto Scaling architecture, backend instances are placed in **private subnets** for better security. See [Networking Guide](./ollama-chat-prod-networking.md) for details.

#### 5. Security Groups

```hcl
vpc_security_group_ids = [aws_security_group.ollama_sg.id]
```

| Attribute        | Value                                                       |
| ---------------- | ----------------------------------------------------------- |
| **What It Is**   | Virtual firewall that controls inbound and outbound traffic |
| **Effect**       | Only traffic matching security group rules is allowed       |
| **Type**         | Array (can attach multiple security groups)                 |
| **Statefulness** | Return traffic is automatically allowed                     |

**The `ollama_sg` security group allows**:

- SSH (port 22) from specified CIDR blocks
- HTTP (port 80) from anywhere
- HTTPS (port 443) from anywhere
- Frontend (port 3000) from anywhere
- Backend API (port 8000) from anywhere
- All outbound traffic

**See Also**: [Security Group Guide](./securitygroup-GUIDE.md) for detailed firewall configuration.

#### 6. IAM Instance Profile

```hcl
iam_instance_profile = aws_iam_instance_profile.ollama_profile.name
```

| Attribute                 | Value                                                 |
| ------------------------- | ----------------------------------------------------- |
| **What It Is**            | A bridge between EC2 and IAM roles                    |
| **Purpose**               | Gives the instance permissions to access AWS services |
| **Attached Policies**     | SSM (Systems Manager), CloudWatch Agent               |
| **No Credentials Needed** | Temporary credentials are automatically rotated       |

**What the Instance Can Do** (via `ollama_ec2_role`):

- ✅ Send logs and metrics to CloudWatch
- ✅ Allow remote management via AWS Systems Manager (Session Manager)
- ✅ Register as a managed instance for patching
- ❌ Cannot create/delete AWS resources (security best practice)

**See Also**: [IAM Guide](./iam-GUIDE.md#ec2-iam-role) for complete permission breakdown.

---

## Root Block Device (EBS Storage)

```hcl
root_block_device {
  volume_type           = "gp3"
  volume_size           = var.root_volume_size
  delete_on_termination = true
  encrypted             = true
}
```

### What is EBS?

**Elastic Block Store (EBS)** is AWS's persistent block storage service. Think of it as a virtual hard drive that can be attached to EC2 instances.

### Root Block Device Configuration

| Parameter                 | Value    | Explanation                                  |
| ------------------------- | -------- | -------------------------------------------- |
| **volume_type**           | `gp3`    | General Purpose SSD (latest generation)      |
| **volume_size**           | Variable | Size in GB (typically 30-100GB for this app) |
| **delete_on_termination** | `true`   | Volume is deleted when instance terminates   |
| **encrypted**             | `true`   | Data is encrypted at rest using AWS KMS      |

### EBS Volume Types Comparison

| Type    | IOPS         | Throughput     | Use Case                        | Cost            |
| ------- | ------------ | -------------- | ------------------------------- | --------------- |
| **gp3** | 3,000-16,000 | 125-1,000 MB/s | Most workloads (recommended)    | $0.08/GB-month  |
| **gp2** | 100-16,000   | 128-250 MB/s   | Legacy general purpose          | $0.10/GB-month  |
| **io2** | 100-64,000   | 1,000 MB/s     | High-performance databases      | $0.125/GB-month |
| **st1** | 500          | 500 MB/s       | Big data, data warehouses       | $0.045/GB-month |
| **sc1** | 250          | 250 MB/s       | Cold storage, infrequent access | $0.015/GB-month |

**Design Decision: Why gp3?**

1. **Better Value**: 20% cheaper than gp2 with better performance
2. **Predictable Performance**: 3,000 IOPS baseline (doesn't depend on volume size)
3. **Flexible**: Can independently adjust IOPS and throughput if needed
4. **Sufficient for Ollama**: AI model loading and inference don't require extreme disk I/O

### Storage Layout for Ollama App

```
/dev/xvda (Root Block Device - gp3)
├── / (Root filesystem)
│   ├── /boot - Boot files
│   ├── /etc - Configuration files
│   ├── /home - User directories
│   ├── /var - Variable data (logs, Docker)
│   │   └── /var/lib/docker - Docker images and containers
│   └── /tmp - Temporary files
│
/dev/sdf (Separate EBS Volume - gp3)
└── /mnt/ollama-models - Ollama model storage
    ├── llama2:7b
    ├── mistral:latest
    └── codellama:13b
```

**Why Separate Volumes?**

| Aspect                | Root Volume                       | Separate Model Volume                  |
| --------------------- | --------------------------------- | -------------------------------------- |
| **Purpose**           | OS, application code, Docker      | AI models only                         |
| **Size**              | 30-50GB                           | 50-500GB (models are large!)           |
| **Backup Strategy**   | Snapshot before updates           | Snapshot after downloading models      |
| **Replacement**       | Can replace without losing models | Can detach and attach to new instances |
| **Cost Optimization** | Right-sized for OS/apps           | Can use larger volume only when needed |

### Encryption

```hcl
encrypted = true
```

| Attribute              | Value                                                   |
| ---------------------- | ------------------------------------------------------- |
| **What It Is**         | Data is encrypted at rest using AES-256 encryption      |
| **Key Management**     | AWS-managed key (default) or customer-managed key (CMK) |
| **Performance Impact** | Negligible (encryption/decryption happens in hardware)  |
| **Compliance**         | Required for many security standards (HIPAA, PCI-DSS)   |

**Design Decision**: Always enable encryption because:

- No performance penalty
- No cost increase
- Prevents data exposure if physical storage is compromised
- Required for compliance with security best practices

### Delete on Termination

```hcl
delete_on_termination = true
```

| Setting | Behavior                                   | Use Case                                         |
| ------- | ------------------------------------------ | ------------------------------------------------ |
| `true`  | Volume is deleted when instance terminates | Development, auto-scaling groups, stateless apps |
| `false` | Volume persists after instance termination | Data persistence, manual recovery, cost savings  |

**Design Decision**: Set to `true` for the root volume because:

- OS and app code can be recreated from AMI and user data
- Prevents orphaned volumes that accumulate costs
- Consistent with immutable infrastructure practices

**Important**: The separate Ollama models volume (`aws_ebs_volume.ollama_models`) does NOT have this flag set, so it persists and can be reattached to new instances.

---

## User Data (Bootstrap Scripts)

```hcl
user_data = templatefile("${path.module}/user-data.sh", {
  project_name = var.project_name
  git_repo_url = var.git_repo_url
  ollama_model = var.ollama_model
  domain_name  = var.domain_name
})
```

### What is User Data?

**User Data** is a script that runs **automatically** when an EC2 instance first launches. It's how you automate the initial setup and configuration of your server.

### How User Data Works

```
EC2 Instance Launch
       ↓
Boot Operating System
       ↓
cloud-init Service Starts
       ↓
Execute User Data Script (as root)
       ↓
Install Software
       ↓
Configure Applications
       ↓
Start Services
       ↓
Instance Ready
```

### Templatefile Function

The `templatefile()` function allows you to:

1. **Parameterize scripts**: Pass Terraform variables into bash scripts
2. **DRY Principle**: One script template, multiple configurations
3. **Dynamic Configuration**: Change behavior without rewriting scripts

**Example Template Syntax**:

```bash
#!/bin/bash
# user-data.sh

# Variables from Terraform
PROJECT_NAME="${project_name}"
REPO_URL="${git_repo_url}"
MODEL="${ollama_model}"
DOMAIN="${domain_name}"

echo "Setting up ${PROJECT_NAME}..."
git clone ${REPO_URL}
ollama pull ${MODEL}
```

**Terraform populates** the `${...}` placeholders with actual values:

```hcl
user_data = templatefile("${path.module}/user-data.sh", {
  project_name = "ollama-chat"           # → ${project_name}
  git_repo_url = "https://github.com/..."  # → ${git_repo_url}
  ollama_model = "llama2:7b"             # → ${ollama_model}
  domain_name  = "chat.example.com"      # → ${domain_name}
})
```

### User Data Script Responsibilities

For the Ollama Chat application, the user data script typically:

1. **System Updates**

   ```bash
   yum update -y  # or apt-get update for Ubuntu
   ```

2. **Install Dependencies**

   ```bash
   yum install -y docker git python3 pip
   ```

3. **Configure Services**

   ```bash
   systemctl enable docker
   systemctl start docker
   ```

4. **Install Ollama**

   ```bash
   curl https://ollama.ai/install.sh | sh
   ```

5. **Download AI Models**

   ```bash
   ollama pull llama2:7b
   ollama pull mistral:latest
   ```

6. **Clone Application Code**

   ```bash
   git clone ${git_repo_url} /opt/ollama-chat
   ```

7. **Setup Backend**

   ```bash
   cd /opt/ollama-chat/backend
   pip install -r requirements.txt
   python app.py &
   ```

8. **Setup Frontend**

   ```bash
   cd /opt/ollama-chat/frontend
   npm install
   npm run build
   npm start &
   ```

9. **Configure Monitoring**
   ```bash
   # Install CloudWatch agent
   wget https://s3.amazonaws.com/amazoncloudwatch-agent/...
   ```

### User Data Best Practices

| Practice            | Why                        | Example                                |
| ------------------- | -------------------------- | -------------------------------------- |
| **Logging**         | Debug failures             | `exec > >(tee /var/log/user-data.log)` |
| **Error Handling**  | Stop on errors             | `set -e` at script start               |
| **Idempotency**     | Safe to run multiple times | Check if software already installed    |
| **Validation**      | Verify success             | `curl localhost:8000/health`           |
| **Cloud-Init Logs** | AWS maintains logs         | `/var/log/cloud-init-output.log`       |

### User Data Limitations

| Limitation                                    | Workaround                                                         |
| --------------------------------------------- | ------------------------------------------------------------------ |
| **Runs once** (at first boot)                 | Use configuration management (Ansible, Chef) for ongoing updates   |
| **No direct output** to console               | Write to log files, view with `cat /var/log/cloud-init-output.log` |
| **Instance replacement** required for changes | Use Auto Scaling with Launch Templates for updates                 |
| **Script failures** are silent                | Implement health checks and CloudWatch alarms                      |

### Viewing User Data Execution

**On the instance**:

```bash
# View user data script
sudo cat /var/lib/cloud/instance/user-data.txt

# View execution output
sudo cat /var/log/cloud-init-output.log

# Check for errors
sudo cat /var/log/cloud-init.log | grep -i error
```

---

## Instance Metadata Service (IMDSv2)

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
}
```

### What is Instance Metadata?

**Instance Metadata Service (IMDS)** is a service that provides information about your instance that you can access from within the instance itself. It's like an internal API that the instance can query to learn about itself.

### What Information is Available?

Applications running on the instance can query metadata to get:

```bash
# Get instance ID
curl http://169.254.169.254/latest/meta-data/instance-id

# Get IAM role credentials
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ollama_ec2_role

# Get public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4

# Get availability zone
curl http://169.254.169.254/latest/meta-data/placement/availability-zone
```

### IMDSv1 vs IMDSv2

| Feature                | IMDSv1 (Legacy)        | IMDSv2 (Secure)               |
| ---------------------- | ---------------------- | ----------------------------- |
| **Authentication**     | None (simple HTTP GET) | Session-based tokens required |
| **SSRF Protection**    | Vulnerable             | Protected                     |
| **Token Retrieval**    | Not required           | Required PUT request          |
| **Token Lifetime**     | N/A                    | 1-6 hours (configurable)      |
| **AWS Recommendation** | Deprecated             | Required for new instances    |

### Configuration Breakdown

#### 1. http_endpoint = "enabled"

```hcl
http_endpoint = "enabled"
```

| Value      | Effect                                    |
| ---------- | ----------------------------------------- |
| `enabled`  | Applications can access metadata service  |
| `disabled` | Metadata service is completely turned off |

**Design Decision**: Keep enabled because:

- AWS SDKs use it to retrieve IAM role credentials automatically
- CloudWatch agent needs it for instance information
- Many AWS services rely on it for integration

#### 2. http_tokens = "required" (IMDSv2)

```hcl
http_tokens = "required"
```

| Value      | Effect                           | Security Level          |
| ---------- | -------------------------------- | ----------------------- |
| `required` | **IMDSv2 only** - token required | High (recommended)      |
| `optional` | IMDSv1 and IMDSv2 both work      | Medium (legacy support) |

**How IMDSv2 Works**:

```bash
# Step 1: Request a session token (PUT request)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Step 2: Use token to access metadata (GET request with header)
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

**Why IMDSv2 is More Secure**:

1. **SSRF Protection**: Server-Side Request Forgery attacks can't steal credentials
2. **Token-Based**: Attackers need to send a PUT request first (harder to exploit)
3. **Hop Limit**: Prevents network traversal beyond the instance

#### 3. http_put_response_hop_limit = 1

```hcl
http_put_response_hop_limit = 1
```

| Value | Effect                                        | Use Case                        |
| ----- | --------------------------------------------- | ------------------------------- |
| `1`   | Metadata accessible only from instance itself | Standard (recommended)          |
| `2`   | Accessible from instance + 1 network hop      | Containers with host networking |
| `3+`  | Accessible from multiple network hops         | Rarely needed                   |

**Design Decision**: Set to `1` because:

- Prevents malicious containers from accessing metadata
- Limits attack surface if instance is compromised
- Sufficient for most application architectures

**Exception**: If running Docker containers with `--network host`, you might need to increase to `2`.

### Security Implications

| Security Feature      | IMDSv1 Risk                                    | IMDSv2 Protection                            |
| --------------------- | ---------------------------------------------- | -------------------------------------------- |
| **SSRF Attacks**      | Attacker can trick app into querying metadata  | PUT request requirement prevents simple SSRF |
| **Credential Theft**  | Easy to steal IAM role credentials             | Token-based auth adds barrier                |
| **Container Escapes** | Compromised container can access host metadata | Hop limit restricts network traversal        |
| **Open Proxies**      | Can proxy requests to metadata service         | Token requirement breaks proxy attacks       |

### Real-World Example: Preventing SSRF

**Vulnerable Code (IMDSv1)**:

```python
import requests

# User-controlled URL (attacker provides this)
url = request.args.get('url')  # User sends: http://169.254.169.254/latest/meta-data/iam/security-credentials/

# App makes request (SSRF vulnerability!)
response = requests.get(url)
return response.text  # Attacker now has IAM credentials!
```

**With IMDSv2**:

- The simple GET request fails (no token provided)
- Attacker would need to send a PUT request first
- Web application frameworks typically don't allow PUT in SSRF scenarios
- Attack is prevented

---

## Lifecycle Management

```hcl
lifecycle {
  ignore_changes = [ami]
}
```

### What are Lifecycle Rules?

**Lifecycle rules** tell Terraform how to handle changes to resources. They control Terraform's behavior during `plan`, `apply`, and `destroy` operations.

### Common Lifecycle Rules

| Rule                    | Effect                                  | Use Case                                  |
| ----------------------- | --------------------------------------- | ----------------------------------------- |
| `ignore_changes`        | Ignore changes to specific attributes   | Prevent unnecessary resource replacement  |
| `create_before_destroy` | Create new resource before deleting old | Zero-downtime updates                     |
| `prevent_destroy`       | Terraform cannot destroy resource       | Protect critical resources from accidents |

### Why Ignore AMI Changes?

```hcl
lifecycle {
  ignore_changes = [ami]
}
```

**Problem Without This Rule**:

1. You launch an instance with `ami-0abcdef` (Amazon Linux 2023)
2. AWS releases a new AMI: `ami-0xyz123` (with security patches)
3. You update your Terraform variable to the new AMI
4. Terraform sees AMI changed and wants to **replace the entire instance**
5. **Your instance is destroyed and recreated** (downtime!)

**Solution With This Rule**:

1. Terraform ignores the AMI change
2. Instance continues running with the old AMI
3. No unexpected downtime

**When to Update AMIs**:

| Method                                | Downtime | Use Case                                          |
| ------------------------------------- | -------- | ------------------------------------------------- |
| **Manual Replacement**                | Yes      | Planned maintenance window                        |
| **Blue-Green Deployment**             | No       | Production systems with ALB                       |
| **Auto Scaling with Launch Template** | No       | Update Launch Template, let ASG replace gradually |
| **AMI Automation Pipeline**           | No       | Golden AMI pipeline with automated testing        |

### Best Practice for AMI Updates

**Development/Testing**:

```hcl
# Allow Terraform to manage AMI updates
lifecycle {
  # No ignore_changes - let Terraform recreate instance
}
```

**Production**:

```hcl
# Use Auto Scaling + Launch Template approach
resource "aws_launch_template" "app" {
  image_id = var.ami_id  # Update this

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"  # Automatically use newest
  }

  # ASG will gradually replace instances
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
    }
  }
}
```

### Other Lifecycle Scenarios

**Prevent Accidental Deletion**:

```hcl
resource "aws_instance" "production_app" {
  # ... configuration ...

  lifecycle {
    prevent_destroy = true  # terraform destroy will fail
  }
}
```

**Zero-Downtime Replacement**:

```hcl
resource "aws_instance" "app" {
  # ... configuration ...

  lifecycle {
    create_before_destroy = true  # New instance before old is destroyed
  }
}
```

---

## How EC2 Fits Into the Greater Infrastructure

### 1. Network Layer Integration

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Internet Gateway ← Public internet access
│   ├── Application Load Balancer ← Distributes traffic
│   └── EC2 Instance (Single-instance mode) ← You are here
│
└── Private Subnets (10.0.11.0/24, 10.0.12.0/24)
    ├── NAT Gateway ← Outbound internet for private instances
    ├── Auto Scaling Group (Backend) ← Flask API servers
    └── Auto Scaling Group (Frontend) ← React app servers
```

**EC2's Network Dependencies**:

| Component            | Relationship          | Why EC2 Needs It                                |
| -------------------- | --------------------- | ----------------------------------------------- |
| **VPC**              | Parent network        | Provides isolated network environment           |
| **Subnet**           | Network segment       | Determines availability zone and IP range       |
| **Internet Gateway** | Public access         | Allows inbound HTTP/HTTPS and outbound internet |
| **Route Table**      | Traffic routing       | Directs traffic between subnets and internet    |
| **Security Group**   | Firewall              | Controls what traffic reaches the instance      |
| **Network ACL**      | Subnet-level firewall | Additional security layer                       |

### 2. Security Layer Integration

```
User Request (HTTP/HTTPS)
       ↓
Internet Gateway (allows traffic in)
       ↓
Network ACL (subnet-level filtering)
       ↓
Security Group (instance-level firewall)
       ↓
EC2 Instance
       ↓
IAM Instance Profile
       ↓
AWS Services (CloudWatch, SSM, S3)
```

**EC2's Security Dependencies**:

| Component                | Purpose                | What It Protects Against        |
| ------------------------ | ---------------------- | ------------------------------- |
| **Security Group**       | Inbound/outbound rules | Unauthorized network access     |
| **IAM Instance Profile** | AWS API permissions    | Unauthorized AWS service access |
| **SSH Key Pair**         | Instance login         | Unauthorized SSH access         |
| **IMDSv2**               | Metadata security      | SSRF attacks, credential theft  |
| **EBS Encryption**       | Data at rest           | Physical storage compromise     |

### 3. Identity and Access Integration

```
EC2 Instance
       ↓
IAM Instance Profile (ollama_profile)
       ↓
IAM Role (ollama_ec2_role)
       ↓
Attached Policies
       ├── AmazonSSMManagedInstanceCore
       │   └── Allows: Session Manager, Run Command, Patch Manager
       └── CloudWatchAgentServerPolicy
           └── Allows: Put metrics, Create log streams, Put log events
```

**What EC2 Can Do** (via IAM):

- ✅ Send application logs to CloudWatch Logs
- ✅ Send custom metrics to CloudWatch
- ✅ Receive commands via AWS Systems Manager
- ✅ Download patches via Systems Manager
- ✅ Retrieve secrets from Parameter Store (if policy added)

**What EC2 Cannot Do**:

- ❌ Create or delete EC2 instances
- ❌ Modify security groups
- ❌ Access S3 buckets (unless policy added)
- ❌ Assume other IAM roles

### 4. Storage Layer Integration

```
EC2 Instance
       ├── Root Block Device (gp3, 30GB)
       │   └── OS, Docker, application code
       │
       └── Attached EBS Volume (gp3, 100GB)
           └── /mnt/ollama-models
               ├── llama2:7b (4GB)
               ├── mistral:latest (4GB)
               └── codellama:13b (7GB)
```

**Storage Architecture**:

| Volume             | Purpose                         | Lifecycle                           | Backup Strategy                           |
| ------------------ | ------------------------------- | ----------------------------------- | ----------------------------------------- |
| **Root Volume**    | OS and apps                     | Deleted with instance               | AMI snapshots before updates              |
| **Models Volume**  | AI models                       | Persists after instance termination | Manual snapshots after downloading models |
| **EFS (Optional)** | Shared storage across instances | Independent                         | Daily automated snapshots                 |

### 5. Monitoring and Logging Integration

```
EC2 Instance
       ↓
CloudWatch Agent (installed via user data)
       ↓
CloudWatch Services
       ├── Metrics
       │   ├── CPUUtilization
       │   ├── NetworkIn/Out
       │   ├── DiskReadOps/WriteOps
       │   └── Custom Metrics (API latency, model inference time)
       │
       └── Logs
           ├── /var/log/messages (system logs)
           ├── /var/log/docker (container logs)
           ├── /var/log/ollama (Ollama logs)
           └── /var/log/user-data.log (bootstrap logs)
```

**CloudWatch Integration**:

| Metric               | Source           | Use Case                     |
| -------------------- | ---------------- | ---------------------------- |
| **CPU Utilization**  | EC2 default      | Trigger auto-scaling         |
| **Memory Usage**     | CloudWatch Agent | Detect memory leaks          |
| **Disk I/O**         | EC2 default      | Identify storage bottlenecks |
| **Network Traffic**  | EC2 default      | Monitor bandwidth usage      |
| **Application Logs** | CloudWatch Agent | Debug application errors     |

### 6. Load Balancing Integration (Auto Scaling Architecture)

```
Internet
       ↓
Application Load Balancer
       ↓
Target Groups
       ├── Backend Target Group (port 8000)
       │   └── Auto Scaling Group (Backend)
       │       ├── EC2 Instance 1 (Flask API)
       │       ├── EC2 Instance 2 (Flask API)
       │       └── EC2 Instance N (Flask API)
       │
       └── Frontend Target Group (port 3000)
           └── Auto Scaling Group (Frontend)
               ├── EC2 Instance 1 (React)
               ├── EC2 Instance 2 (React)
               └── EC2 Instance N (React)
```

**Load Balancer Integration**:

| Component              | Purpose                | EC2 Role                               |
| ---------------------- | ---------------------- | -------------------------------------- |
| **ALB**                | Distribute traffic     | Multiple EC2 instances handle requests |
| **Target Group**       | Health checks          | EC2 must respond to `/health` endpoint |
| **Auto Scaling Group** | Maintain capacity      | Launches new EC2 instances as needed   |
| **Launch Template**    | Instance configuration | Defines EC2 settings for new instances |

### 7. Complete Traffic Flow

**Single-Instance Architecture** (Development):

```
User → Internet → IGW → Route Table → Security Group → EC2 Instance
                                                         ├── Frontend (port 3000)
                                                         └── Backend (port 8000)
```

**Multi-Instance Architecture** (Production):

```
User → Internet → IGW → ALB → Security Group → Target Group
                                                       ↓
                               Private Subnet → EC2 Instance 1
                                              → EC2 Instance 2
                                              → EC2 Instance N
                                                       ↓
                               NAT Gateway → IGW → Internet (outbound only)
```

---

## Single-Instance vs Auto Scaling Architecture

The Terraform configuration supports **two deployment modes**:

### Mode 1: Single-Instance Deployment

```hcl
# Single EC2 instance in public subnet
resource "aws_instance" "ollama_app" {
  subnet_id = aws_subnet.public_subnet_1.id
  # ... handles all traffic directly
}
```

| Aspect             | Configuration                                      |
| ------------------ | -------------------------------------------------- |
| **Deployment**     | One EC2 instance running both frontend and backend |
| **Network**        | Public subnet with direct internet access          |
| **Load Balancing** | None (direct access to instance)                   |
| **Scalability**    | Manual (stop, change instance type, start)         |
| **Cost**           | Lower (1 instance, no ALB)                         |
| **Use Case**       | Development, testing, small-scale production       |

**Pros**:

- Simple setup
- Lower cost
- Easy to troubleshoot
- Good for learning

**Cons**:

- No redundancy (single point of failure)
- Cannot scale horizontally
- Manual updates require downtime
- Limited to one availability zone

### Mode 2: Auto Scaling Architecture

```hcl
# Controlled by variable
variable "enable_auto_scaling" {
  default = false
}

# Launch Templates + Auto Scaling Groups
resource "aws_launch_template" "backend_lt" {
  count = var.enable_auto_scaling ? 1 : 0
  # ... backend configuration
}

resource "aws_autoscaling_group" "backend_asg" {
  count = var.enable_auto_scaling ? 1 : 0
  # ... manages multiple backend instances
}
```

| Aspect             | Configuration                                               |
| ------------------ | ----------------------------------------------------------- |
| **Deployment**     | Separate Auto Scaling Groups for backend and frontend       |
| **Network**        | Private subnets (better security)                           |
| **Load Balancing** | ALB distributes traffic                                     |
| **Scalability**    | Automatic based on CPU metrics                              |
| **Cost**           | Higher (multiple instances, ALB, NAT Gateways)              |
| **Use Case**       | Production environments with high availability requirements |

**Pros**:

- High availability (multi-AZ)
- Automatic scaling
- Zero-downtime deployments
- Better security (private subnets)

**Cons**:

- More complex to configure
- Higher cost
- More moving parts to troubleshoot

### When to Use Each Architecture

| Scenario                          | Recommended Architecture        | Why                                 |
| --------------------------------- | ------------------------------- | ----------------------------------- |
| **Learning Terraform**            | Single-Instance                 | Simpler, fewer concepts             |
| **Development Environment**       | Single-Instance                 | Lower cost, easier debugging        |
| **Testing/Staging**               | Single-Instance or Auto Scaling | Depends on production parity needs  |
| **Production (Low Traffic)**      | Single-Instance + EIP           | Cost-effective, acceptable downtime |
| **Production (High Traffic)**     | Auto Scaling                    | Required for reliability and scale  |
| **Production (Mission-Critical)** | Auto Scaling + Multi-Region     | Maximum availability                |

### Migration Path

**Start Simple, Scale When Needed**:

1. **Phase 1: Development**

   ```hcl
   enable_auto_scaling = false
   instance_type = "t3.medium"
   ```

   - Single instance
   - Public subnet
   - Manual scaling

2. **Phase 2: Initial Production**

   ```hcl
   enable_auto_scaling = false
   instance_type = "c5.2xlarge"  # More powerful
   ```

   - Still single instance
   - Better performance
   - Add CloudWatch alarms

3. **Phase 3: Scaling Production**
   ```hcl
   enable_auto_scaling = true
   backend_min_size = 2
   backend_max_size = 10
   ```
   - Auto Scaling enabled
   - Multi-AZ deployment
   - Zero-downtime updates

---

## Design Decisions and Best Practices

### 1. AMI Selection

| Decision                 | Rationale                               |
| ------------------------ | --------------------------------------- |
| **Use variables**        | Easy to update without changing code    |
| **Region-specific AMIs** | AMI IDs differ by region                |
| **Lifecycle ignore**     | Prevent accidental instance replacement |

**Recommendation**:

```hcl
# Use AWS Systems Manager Parameter Store for latest AMI
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "ollama_app" {
  ami = data.aws_ssm_parameter.amazon_linux_2023.value
  # ...
}
```

### 2. Instance Type Selection

| Workload               | Instance Family   | Example Type | Monthly Cost (On-Demand) |
| ---------------------- | ----------------- | ------------ | ------------------------ |
| **Development**        | t3 (Burstable)    | t3.medium    | ~$30                     |
| **Production (CPU)**   | c5 (Compute)      | c5.2xlarge   | ~$245                    |
| **Production (GPU)**   | g4dn (GPU)        | g4dn.xlarge  | ~$380                    |
| **Large Models (GPU)** | p3 (High-end GPU) | p3.2xlarge   | ~$2,205                  |

**Cost Optimization**:

- Use **Savings Plans** (30-70% discount for 1-3 year commitment)
- Use **Spot Instances** for non-critical workloads (up to 90% discount)
- Use **Reserved Instances** for predictable workloads (30-75% discount)

### 3. Storage Configuration

**Root Volume Best Practices**:

- Use **gp3** (better value than gp2)
- Size appropriately (30-50GB for OS + apps)
- Always enable **encryption**
- Set `delete_on_termination = true` for stateless apps

**Separate Data Volumes**:

- Use for large datasets (AI models, databases)
- Set `delete_on_termination = false` for data persistence
- Take regular snapshots
- Consider EFS for shared storage across instances

### 4. User Data Best Practices

```bash
#!/bin/bash
set -e  # Exit on error
set -x  # Print commands (for debugging)

# Redirect output to log file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script at $(date)"

# Update system
yum update -y

# Install dependencies
yum install -y docker git python3

# Start Docker
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
until docker info &>/dev/null; do
  echo "Waiting for Docker..."
  sleep 1
done

# Install Ollama
curl https://ollama.ai/install.sh | sh

# Pull AI models
ollama pull ${ollama_model}

# Clone application
git clone ${git_repo_url} /opt/app

# Setup application
cd /opt/app
pip3 install -r requirements.txt

# Start application
python3 app.py &

echo "User data script completed at $(date)"
```

### 5. Security Best Practices

| Practice            | Implementation              | Why                          |
| ------------------- | --------------------------- | ---------------------------- |
| **IMDSv2**          | `http_tokens = "required"`  | Prevent SSRF attacks         |
| **Encryption**      | `encrypted = true`          | Protect data at rest         |
| **Minimal IAM**     | Only required permissions   | Principle of least privilege |
| **Security Groups** | Restrict source IPs         | Limit attack surface         |
| **SSH Keys**        | Never hardcode in Terraform | Prevent credential exposure  |
| **Regular Updates** | Automated patching          | Fix security vulnerabilities |

### 6. High Availability Considerations

**Single Instance Improvements**:

- Use **Elastic IP** (static IP survives instance replacement)
- Enable **detailed monitoring** (1-minute CloudWatch metrics)
- Set up **CloudWatch alarms** (CPU, disk, status checks)
- Implement **automated backups** (EBS snapshots, AMI creation)

**Multi-Instance Architecture**:

- Deploy across **multiple Availability Zones**
- Use **Application Load Balancer** (health checks, traffic distribution)
- Implement **Auto Scaling** (automatic capacity management)
- Use **Launch Templates** (consistent instance configuration)

---

## Troubleshooting

### Common EC2 Issues

#### 1. Instance Won't Launch

| Problem                   | Possible Cause               | Solution                                  |
| ------------------------- | ---------------------------- | ----------------------------------------- |
| **Terraform apply fails** | Invalid AMI ID               | Verify AMI exists in your region          |
| **Terraform apply fails** | Instance type not available  | Check AZ availability, try different type |
| **Terraform apply fails** | Subnet has no available IPs  | Use larger CIDR block or different subnet |
| **Terraform apply fails** | Security group rules invalid | Check CIDR blocks and port ranges         |

**Debugging**:

```bash
# Check available instance types in AZ
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=location,Values=us-east-1a \
  --region us-east-1

# Verify AMI exists
aws ec2 describe-images --image-ids ami-0abcdef1234567890
```

#### 2. Instance Launches But User Data Fails

| Symptom                     | Cause                      | Solution                                   |
| --------------------------- | -------------------------- | ------------------------------------------ |
| **Application not running** | User data script failed    | Check `/var/log/cloud-init-output.log`     |
| **Partial setup**           | Script error mid-execution | Add `set -e` to exit on error              |
| **No logs**                 | Log redirection failed     | Use `exec > >(tee /var/log/user-data.log)` |

**Debugging**:

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@<instance-public-ip>

# Check user data execution
sudo cat /var/log/cloud-init-output.log | tail -100

# Check for errors
sudo cat /var/log/cloud-init.log | grep -i error

# View user data script
sudo cat /var/lib/cloud/instance/user-data.txt

# Manually run user data for testing
sudo bash /var/lib/cloud/instance/user-data.txt
```

#### 3. Instance Running But Unreachable

| Problem                   | Check                             | Fix                              |
| ------------------------- | --------------------------------- | -------------------------------- |
| **Cannot SSH**            | Security group allows port 22?    | Add ingress rule for SSH         |
| **Cannot SSH**            | Using correct key pair?           | Verify key name in Terraform     |
| **Cannot SSH**            | Network ACL blocking?             | Check NACL rules                 |
| **Cannot access web app** | Security group allows HTTP/HTTPS? | Add ingress rules for 80/443     |
| **Cannot access web app** | Application actually running?     | SSH in and check `netstat -tlnp` |

**Debugging**:

```bash
# Test security group (from local machine)
telnet <instance-public-ip> 22  # Should connect if SG allows SSH
telnet <instance-public-ip> 80  # Should connect if SG allows HTTP

# Check if application is listening (on instance)
sudo netstat -tlnp | grep :8000  # Backend
sudo netstat -tlnp | grep :3000  # Frontend

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-0abcdef1234567890
```

#### 4. Instance Performance Issues

| Symptom                | Possible Cause      | Solution                              |
| ---------------------- | ------------------- | ------------------------------------- |
| **High CPU**           | Undersized instance | Upgrade to larger instance type       |
| **High CPU**           | Infinite loop/bug   | Check application logs                |
| **High disk I/O wait** | Slow EBS volume     | Switch to gp3 or increase IOPS        |
| **Out of memory**      | Memory leak         | Increase instance memory or fix leak  |
| **Slow network**       | Network throttling  | Use enhanced networking instance type |

**Debugging**:

```bash
# Check CPU usage
top
htop  # If installed

# Check memory
free -h

# Check disk I/O
iostat -x 1

# Check network
iftop  # If installed
```

#### 5. IAM Permission Issues

| Error Message                  | Cause                     | Solution                              |
| ------------------------------ | ------------------------- | ------------------------------------- |
| **Access Denied (CloudWatch)** | Missing CloudWatch policy | Attach `CloudWatchAgentServerPolicy`  |
| **Access Denied (SSM)**        | Missing SSM policy        | Attach `AmazonSSMManagedInstanceCore` |
| **Access Denied (S3)**         | No S3 permissions         | Add custom policy for S3 access       |

**Debugging**:

```bash
# Check what role is attached
aws sts get-caller-identity

# Try to access service
aws s3 ls  # Will fail if no S3 permissions
aws logs describe-log-groups  # Will fail if no CloudWatch permissions
```

#### 6. EBS Volume Issues

| Problem                  | Cause             | Solution                            |
| ------------------------ | ----------------- | ----------------------------------- |
| **Volume not attached**  | Wrong device name | Check `/dev/xvdf` vs `/dev/sdf`     |
| **Volume not formatted** | New volume        | Format with `mkfs.ext4`             |
| **Volume not mounted**   | No mount entry    | Add to `/etc/fstab`                 |
| **Volume full**          | Insufficient size | Resize volume and extend filesystem |

**Debugging**:

```bash
# List block devices
lsblk

# Check if volume is attached
ls -l /dev/xvdf

# Check mount status
df -h

# Mount volume manually
sudo mkdir -p /mnt/ollama-models
sudo mount /dev/xvdf /mnt/ollama-models
```

### Monitoring and Alerting

**Set Up CloudWatch Alarms**:

```hcl
resource "aws_cloudwatch_metric_alarm" "instance_cpu_high" {
  alarm_name          = "ollama-instance-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.ollama_app.id
  }
}
```

**Key Metrics to Monitor**:

- CPU Utilization (>80% sustained)
- Disk Space (>85% full)
- Memory Usage (>90%)
- Status Check Failed (instance or system)
- Network In/Out (unusual spikes)

---

## Summary

### EC2 Instance Role in Infrastructure

EC2 instances are the **compute foundation** of the Ollama Chat infrastructure:

1. **Network Layer**: EC2 instances are placed in subnets within a VPC
2. **Security Layer**: Protected by security groups and IAM roles
3. **Storage Layer**: Use EBS volumes for persistent data
4. **Application Layer**: Run the Flask backend and React frontend
5. **Monitoring Layer**: Send metrics and logs to CloudWatch

### Key Takeaways

| Topic             | Key Point                                                                  |
| ----------------- | -------------------------------------------------------------------------- |
| **AMI**           | Use variables for AMIs; ignore changes in lifecycle to prevent replacement |
| **Instance Type** | Choose based on workload (t3 for dev, c5 for production, g4dn for GPU)     |
| **Storage**       | Use gp3 volumes with encryption; separate root and data volumes            |
| **User Data**     | Automate instance setup; log everything for debugging                      |
| **IMDSv2**        | Always enforce IMDSv2 for security                                         |
| **IAM**           | Attach instance profile for AWS service access                             |
| **Networking**    | Public subnet for single-instance, private for auto-scaling                |
| **Lifecycle**     | Use ignore_changes for AMI, create_before_destroy for updates              |

### Next Steps

1. **For Development**: Deploy single-instance architecture to learn fundamentals
2. **For Production**: Graduate to auto-scaling architecture for reliability
3. **For Optimization**: Implement monitoring, alarms, and automated backups
4. **For Scaling**: Add more sophisticated auto-scaling policies and multi-region deployment

---

## Related Documentation

- [Networking Guide](./ollama-chat-prod-networking.md) - VPC, subnets, routing
- [Security Group Guide](./securitygroup-GUIDE.md) - Firewall configuration, SSH access
- [IAM Guide](./iam-GUIDE.md) - Roles, policies, permissions
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/) - Official AWS documentation
