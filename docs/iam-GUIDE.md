# IAM and Access Management Guide

## Table of Contents

1. [Overview](#overview)
2. [IAM Fundamentals](#iam-fundamentals)
3. [EC2 IAM Role](#ec2-iam-role)
4. [AWS Managed Policies](#aws-managed-policies)
5. [IAM Instance Profile](#iam-instance-profile)
6. [SSH Key Pair](#ssh-key-pair)
7. [Infrastructure Strategy Integration](#infrastructure-strategy-integration)
8. [Required Permissions for Infrastructure Creation](#required-permissions-for-infrastructure-creation)
9. [Required Permissions for Infrastructure Usage](#required-permissions-for-infrastructure-usage)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This document explains the **Identity and Access Management (IAM)** configuration for the Ollama Chat App infrastructure. IAM controls **who can do what** in your AWS environment.

### Key Components

Our IAM setup consists of **4 main resources**:

1. **IAM Role** (`ollama_ec2_role`) - Defines what EC2 instances can do
2. **Policy Attachments** (SSM, CloudWatch) - Grant specific permissions
3. **Instance Profile** (`ollama_profile`) - Bridges EC2 and IAM roles
4. **Key Pair** (`ollama_key`) - Enables SSH access to instances

### Why IAM Matters

Without proper IAM configuration:

- ❌ EC2 instances can't send logs to CloudWatch
- ❌ You can't use AWS Systems Manager Session Manager
- ❌ Instances can't access AWS APIs (S3, DynamoDB, etc.)
- ❌ No SSH access for troubleshooting

With our IAM setup:

- ✅ Automated log collection in CloudWatch
- ✅ Secure shell access via SSM (no port 22 needed)
- ✅ Instances can interact with AWS services
- ✅ Traditional SSH available as fallback

---

## IAM Fundamentals

### What is IAM?

**IAM (Identity and Access Management)** is AWS's authorization service. It answers the question: "Can this entity perform this action on this resource?"

### Core IAM Concepts

| Concept       | Definition                             | Example                                 |
| ------------- | -------------------------------------- | --------------------------------------- |
| **Identity**  | Who/what is making the request         | IAM user, EC2 instance, Lambda function |
| **Principal** | The entity assuming a role             | `ec2.amazonaws.com` service             |
| **Action**    | What you want to do                    | `logs:PutLogEvents`, `ssm:StartSession` |
| **Resource**  | What you want to act on                | CloudWatch log group, EC2 instance      |
| **Policy**    | JSON document defining permissions     | `AmazonSSMManagedInstanceCore`          |
| **Role**      | Set of permissions that can be assumed | `ollama_ec2_role`                       |

### Trust Policy vs Permission Policy

```
┌─────────────────────────────────────────────────────────────┐
│ Trust Policy (Who can assume this role?)                    │
│ - Defined in IAM role's assume_role_policy                  │
│ - Answers: "Can EC2 service use this role?"                 │
│ - Example: Allow "ec2.amazonaws.com" to assume role         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Permission Policy (What can this role do?)                  │
│ - Defined in attached IAM policies                          │
│ - Answers: "Can this role write to CloudWatch?"             │
│ - Example: Allow "logs:PutLogEvents" action                 │
└─────────────────────────────────────────────────────────────┘
```

**Analogy:**

- **Trust Policy** = Building access card (who can enter)
- **Permission Policy** = Room keys (what rooms you can access once inside)

---

## EC2 IAM Role

### Resource Block

```hcl
resource "aws_iam_role" "ollama_ec2_role" {
  name = "${var.project_name}-ec2-role"

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
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **EC2 IAM Role** is a container for permissions that EC2 instances can assume. Think of it as a "service account" for your instances.

### Configuration Breakdown

| Component              | Value                          | Why This Value?                                       |
| ---------------------- | ------------------------------ | ----------------------------------------------------- |
| **name**               | `${var.project_name}-ec2-role` | Unique identifier (e.g., `ollama-chat-prod-ec2-role`) |
| **assume_role_policy** | JSON trust policy              | Defines **who** can assume this role                  |
| **Action**             | `sts:AssumeRole`               | The API call to assume a role                         |
| **Principal.Service**  | `ec2.amazonaws.com`            | **ONLY** EC2 service can use this role                |
| **Effect**             | `Allow`                        | Grant permission (vs `Deny`)                          |
| **Version**            | `2012-10-17`                   | IAM policy language version (always use this)         |

### Design Decisions

#### Why a Separate Role Instead of Root Credentials?

**Bad Practice (NEVER DO THIS):**

```bash
# Hardcode AWS credentials on EC2 instance
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Problems:**

- 🔴 Credentials exposed in environment variables
- 🔴 Hard to rotate (must update all instances)
- 🔴 If instance compromised, attacker has permanent keys
- 🔴 No audit trail (all actions look like root account)

**Good Practice (Our Approach):**

```hcl
# Assign IAM role to EC2 instance
iam_instance_profile = aws_iam_instance_profile.ollama_profile.name
```

**Benefits:**

- ✅ No credentials stored on instance
- ✅ Temporary credentials auto-rotate every hour
- ✅ Granular permissions (only what's needed)
- ✅ CloudTrail logs all actions with role identity

#### Why EC2 Service as Principal?

```json
"Principal": {
  "Service": "ec2.amazonaws.com"
}
```

This means **only the EC2 service** can assume this role, not:

- ❌ IAM users (e.g., developers)
- ❌ Other AWS services (Lambda, ECS, etc.)
- ❌ External identities (federated users)

**Why this matters:** If a developer's credentials are compromised, they can't assume the EC2 role directly. The role is tightly scoped to EC2 instances only.

#### What is STS (Security Token Service)?

`sts:AssumeRole` is the AWS API call that:

1. Verifies the caller is allowed to assume the role (trust policy check)
2. Returns temporary security credentials (Access Key, Secret Key, Session Token)
3. Credentials expire after 1-12 hours (default: 1 hour for EC2)

**Flow:**

```
EC2 Instance boots →
Calls sts:AssumeRole with instance identity →
STS validates trust policy →
Returns temporary credentials →
Instance uses credentials to call AWS APIs →
Credentials expire after 1 hour →
Instance automatically requests new credentials
```

### Terraform Policy Syntax

#### Option 1: jsonencode (Our Approach)

```hcl
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
```

**Pros:**

- ✅ Type-safe (Terraform validates HCL syntax)
- ✅ Clean indentation
- ✅ Easier to read for developers

#### Option 2: Heredoc String

```hcl
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
```

**Pros:**

- ✅ Copy-paste from AWS Console
- ✅ Looks exactly like AWS IAM policy

**Choose jsonencode for better Terraform integration.**

---

## AWS Managed Policies

### SSM Policy Attachment

```hcl
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ollama_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

### CloudWatch Policy Attachment

```hcl
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ollama_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

### Purpose

**Policy attachments** link AWS-managed policies to our custom role. This grants specific permissions without writing custom JSON.

### Configuration Breakdown

| Component      | Value                         | Why This Value?                |
| -------------- | ----------------------------- | ------------------------------ |
| **role**       | `ollama_ec2_role.name`        | Which role to attach policy to |
| **policy_arn** | `arn:aws:iam::aws:policy/...` | AWS-managed policy ARN         |

### AWS-Managed vs Customer-Managed Policies

| Type                 | Who Creates | Maintenance                    | Examples                       |
| -------------------- | ----------- | ------------------------------ | ------------------------------ |
| **AWS-Managed**      | AWS         | AWS updates automatically      | `AmazonSSMManagedInstanceCore` |
| **Customer-Managed** | You         | You must update manually       | Custom S3 access policy        |
| **Inline Policy**    | You         | Embedded in role (can't reuse) | One-off permissions            |

**Our approach:** Use AWS-managed policies when possible (less maintenance, AWS keeps them secure).

### AmazonSSMManagedInstanceCore Policy

**What it grants:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetEncryptionConfiguration"],
      "Resource": "*"
    }
  ]
}
```

**Why we need this:**

| Action                             | Purpose                      | User Benefit                        |
| ---------------------------------- | ---------------------------- | ----------------------------------- |
| `ssm:UpdateInstanceInformation`    | Register instance with SSM   | Instance appears in SSM console     |
| `ssmmessages:CreateControlChannel` | Establish SSM session        | You can connect via Session Manager |
| `ssmmessages:OpenDataChannel`      | Send commands to instance    | Commands execute on instance        |
| `s3:GetEncryptionConfiguration`    | Check S3 encryption for logs | Secure log storage                  |

**Real-world use case:**

```bash
# Without SSM policy: ERROR
aws ssm start-session --target i-1234567890abcdef0
# "An error occurred (TargetNotConnected)"

# With SSM policy: SUCCESS
aws ssm start-session --target i-1234567890abcdef0
# "Starting session with SessionId: user-08a1b2c3d4e5f6789"
```

### CloudWatchAgentServerPolicy

**What it grants:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
    }
  ]
}
```

**Why we need this:**

| Action                     | Purpose                        | User Benefit                          |
| -------------------------- | ------------------------------ | ------------------------------------- |
| `logs:CreateLogGroup`      | Create log group if missing    | Auto-setup (no manual creation)       |
| `logs:CreateLogStream`     | Create log stream per instance | Separate logs per instance            |
| `logs:PutLogEvents`        | Write log entries              | Application logs appear in CloudWatch |
| `cloudwatch:PutMetricData` | Send custom metrics            | Track app-specific metrics            |
| `ec2:DescribeVolumes`      | Get disk info                  | Monitor disk usage metrics            |

**Real-world use case:**

```bash
# In your application code
import boto3

logs = boto3.client('logs')
logs.put_log_events(
    logGroupName='/aws/ec2/ollama-chat-prod',
    logStreamName='backend-instance-1',
    logEvents=[
        {
            'timestamp': 1700000000000,
            'message': 'User query processed successfully'
        }
    ]
)
# ✅ Works because CloudWatchAgentServerPolicy grants logs:PutLogEvents
```

### Design Decisions

#### Why Two Separate Attachments?

You might wonder: "Why not one policy with both SSM and CloudWatch permissions?"

**Reasons for separation:**

1. **Single Responsibility**: Each policy has one purpose (SSM access OR logging)
2. **AWS Best Practice**: Use AWS-managed policies (maintained by AWS)
3. **Granular Control**: Remove SSM access without affecting logging
4. **Compliance**: Auditors can see exactly what permissions exist

**Example scenario:**

```hcl
# Production: Full access
resource "aws_iam_role_policy_attachment" "ssm_policy" { ... }
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" { ... }

# Development: Only logging (no SSH alternative)
# Comment out SSM policy to force developers to use traditional SSH
# resource "aws_iam_role_policy_attachment" "ssm_policy" { ... }
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" { ... }
```

#### Why AWS-Managed Policies?

**Alternative: Custom inline policy**

```hcl
resource "aws_iam_role_policy" "custom_policy" {
  role = aws_iam_role.ollama_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}
```

**Problems with custom policies:**

- 🔴 You must manually add new permissions when AWS adds features
- 🔴 Risk of overly broad permissions (`Resource = "*"`)
- 🔴 No version control (AWS doesn't track your custom policies)
- 🔴 Security audits are harder (custom vs standard policies)

**Benefits of AWS-managed policies:**

- ✅ AWS updates them when new APIs are added
- ✅ Least-privilege by default (AWS designs them carefully)
- ✅ Compliance-friendly (auditors recognize standard policies)
- ✅ Reusable across projects

---

## IAM Instance Profile

### Resource Block

```hcl
resource "aws_iam_instance_profile" "ollama_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ollama_ec2_role.name

  tags = {
    Name        = "${var.project_name}-instance-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

An **Instance Profile** is a **container for an IAM role** that can be attached to EC2 instances. It's the bridge between EC2 and IAM.

### Why Instance Profiles Exist

**Historical context:** EC2 was created before IAM roles existed. Instance profiles were added later to maintain backward compatibility while introducing role-based access.

**The problem:**

```hcl
# This doesn't work (EC2 expects instance profile, not role)
resource "aws_instance" "example" {
  iam_instance_profile = aws_iam_role.ollama_ec2_role.name  # ❌ Wrong
}
```

**The solution:**

```hcl
# Create instance profile wrapper
resource "aws_iam_instance_profile" "ollama_profile" {
  role = aws_iam_role.ollama_ec2_role.name
}

# Attach instance profile to EC2
resource "aws_instance" "example" {
  iam_instance_profile = aws_iam_instance_profile.ollama_profile.name  # ✅ Correct
}
```

### Configuration Breakdown

| Component | Value                                  | Why This Value?                      |
| --------- | -------------------------------------- | ------------------------------------ |
| **name**  | `${var.project_name}-instance-profile` | Must be unique in AWS account        |
| **role**  | `ollama_ec2_role.name`                 | Links to our IAM role                |
| **tags**  | Standard project tags                  | For cost allocation and organization |

### How Instance Profiles Work

```
┌─────────────────────────────────────────────────────────────┐
│ EC2 Instance                                                │
│ - Boots up                                                  │
│ - Looks for attached instance profile                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Instance Profile (ollama_profile)                          │
│ - Container/wrapper                                         │
│ - References: ollama_ec2_role                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ IAM Role (ollama_ec2_role)                                 │
│ - Trust policy: Allow EC2 to assume                         │
│ - Attached policies: SSM, CloudWatch                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ AWS Services                                                │
│ - CloudWatch Logs (write logs)                             │
│ - Systems Manager (shell access)                           │
└─────────────────────────────────────────────────────────────┘
```

### Instance Profile vs IAM Role

| Aspect                | IAM Role              | Instance Profile           |
| --------------------- | --------------------- | -------------------------- |
| **Purpose**           | Defines permissions   | Attaches role to EC2       |
| **Can be assumed by** | Any trusted principal | Only EC2 instances         |
| **Creation**          | `aws_iam_role`        | `aws_iam_instance_profile` |
| **Attached to EC2**   | No (needs profile)    | Yes                        |
| **Contains**          | Policies              | One IAM role               |

**Analogy:**

- **IAM Role** = Job description (responsibilities, permissions)
- **Instance Profile** = Badge holder (physical attachment to EC2 instance)

### Credential Retrieval on EC2

When an application on EC2 needs AWS credentials:

```python
# Application code (Python)
import boto3

# SDK automatically fetches credentials from instance metadata
logs = boto3.client('logs')
logs.put_log_events(...)
```

**Behind the scenes:**

1. Boto3 checks environment variables (empty)
2. Boto3 queries EC2 instance metadata service: `http://169.254.169.254/latest/meta-data/iam/security-credentials/ollama-profile`
3. Metadata service returns temporary credentials (valid 1 hour)
4. Boto3 uses credentials to call CloudWatch API
5. After 1 hour, Boto3 automatically refreshes credentials

**You can test this manually:**

```bash
# SSH to EC2 instance
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Output:
# ollama-chat-prod-instance-profile

curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/ollama-chat-prod-instance-profile

# Output (temporary credentials):
# {
#   "AccessKeyId": "ASIAXYZ123...",
#   "SecretAccessKey": "abc123...",
#   "Token": "FwoGZXIvYXd...",
#   "Expiration": "2025-11-25T12:00:00Z"
# }
```

---

## SSH Key Pair

### Resource Block

```hcl
resource "aws_key_pair" "ollama_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "${var.project_name}-key"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **SSH Key Pair** enables **traditional SSH access** to EC2 instances. It's a **public-key cryptography** mechanism for authentication.

### Why SSH Keys (Not IAM)?

**SSH Key Pair is NOT IAM.** It's a separate authentication mechanism:

| Authentication Type | Purpose                          | When to Use                               |
| ------------------- | -------------------------------- | ----------------------------------------- |
| **SSH Key Pair**    | Traditional shell access         | Fallback when SSM unavailable             |
| **IAM + SSM**       | Modern shell access via AWS APIs | Primary access method (no port 22 needed) |
| **IAM User**        | Human access to AWS Console/APIs | Infrastructure management                 |
| **IAM Role**        | Service-to-service access        | EC2 calling CloudWatch                    |

**Why we need both SSH and SSM:**

- **SSM (Primary)**: More secure (no port 22), session logging, IAM-based
- **SSH (Fallback)**: Works when SSM agent fails, network issues, debugging

### Configuration Breakdown

| Component      | Value                     | Why This Value?                                  |
| -------------- | ------------------------- | ------------------------------------------------ |
| **key_name**   | `${var.project_name}-key` | Identifier in AWS (e.g., `ollama-chat-prod-key`) |
| **public_key** | `var.ssh_public_key`      | Your RSA public key content                      |

### SSH Key Pair Workflow

#### Step 1: Generate Key Pair (On Your Laptop)

```bash
# Generate RSA key pair (private + public key)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ollama-chat-prod-key -C "ollama-prod-key"

# Output:
# ~/.ssh/ollama-chat-prod-key       (private key - NEVER SHARE)
# ~/.ssh/ollama-chat-prod-key.pub   (public key - safe to share)
```

**Important:** The **private key never leaves your laptop**. Only the public key is uploaded to AWS.

#### Step 2: Extract Public Key Content

```bash
cat ~/.ssh/ollama-chat-prod-key.pub

# Output:
# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7... ollama-prod-key
```

#### Step 3: Add to terraform.tfvars

```hcl
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7... ollama-prod-key"
```

#### Step 4: Terraform Creates AWS Key Pair

```bash
terraform apply
```

Terraform uploads the public key to AWS. AWS stores it and names it `ollama-chat-prod-key`.

#### Step 5: EC2 Instances Get Public Key

When EC2 instance launches:

1. EC2 service reads `key_name = "ollama-chat-prod-key"` from launch template
2. EC2 downloads public key from AWS
3. EC2 adds public key to `/home/ubuntu/.ssh/authorized_keys` on instance
4. Instance is now ready for SSH

#### Step 6: SSH to Instance

```bash
# Your laptop uses private key to authenticate
ssh -i ~/.ssh/ollama-chat-prod-key ubuntu@<instance-public-ip>

# Behind the scenes:
# 1. SSH client signs challenge with private key
# 2. Instance verifies signature using public key from authorized_keys
# 3. If signature valid, SSH grants access
```

### Public Key Cryptography

**How it works:**

```
┌──────────────────────┐              ┌──────────────────────┐
│ Your Laptop          │              │ EC2 Instance         │
│                      │              │                      │
│ Private Key 🔐       │              │ Public Key 🔓        │
│ (secret)             │              │ (in authorized_keys) │
│                      │              │                      │
│ Signs challenge ✍️   │──────────────▶│ Verifies signature ✅│
│                      │              │                      │
│                      │◀──────────────│ Grants access 🚪     │
└──────────────────────┘              └──────────────────────┘
```

**Security properties:**

- ✅ Private key stays on your laptop (never transmitted)
- ✅ Public key can be shared freely (stored on instance)
- ✅ Knowing public key doesn't help attacker (can't derive private key)
- ✅ No passwords (can't be brute-forced)

### Design Decisions

#### Why Store Public Key in Variable?

```hcl
public_key = var.ssh_public_key
```

**Alternative: Hardcode in Terraform**

```hcl
public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7..."  # ❌ Bad
```

**Why variables are better:**

- ✅ Different keys per environment (dev, staging, prod)
- ✅ Keep keys out of version control (terraform.tfvars in .gitignore)
- ✅ Easy to rotate keys (update variable, run terraform apply)
- ✅ Team members can use their own keys

**Best practice:**

```bash
# .gitignore
terraform.tfvars   # Contains your public key
*.pem              # Private keys should NEVER be in git
```

#### Why Not Store Private Key in Terraform?

**NEVER DO THIS:**

```hcl
variable "ssh_private_key" {  # 🔴 DANGEROUS
  type = string
}
```

**Why private keys should never be in Terraform:**

- 🔴 Terraform state file is stored in S3 (potential leak)
- 🔴 State file includes all variables (including private key)
- 🔴 Multiple people have access to state file
- 🔴 State file is often in version control (huge security risk)

**Correct approach:** Private key stays on your laptop in `~/.ssh/`

#### Key Rotation Strategy

**When to rotate:**

- Every 90 days (security policy)
- When team member leaves
- When private key may be compromised
- When migrating to SSM (can remove SSH entirely)

**How to rotate:**

```bash
# 1. Generate new key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ollama-chat-prod-key-v2

# 2. Update terraform.tfvars
ssh_public_key = "ssh-rsa AAAAB3NzaC1... (new public key)"

# 3. Apply Terraform
terraform apply

# 4. New instances get new key automatically
# 5. For existing instances, use user data to add new key:
echo "ssh-rsa AAAAB3NzaC1..." >> /home/ubuntu/.ssh/authorized_keys

# 6. Test new key works
ssh -i ~/.ssh/ollama-chat-prod-key-v2 ubuntu@<ip>

# 7. Remove old key from authorized_keys
sed -i '/ollama-prod-key$/d' /home/ubuntu/.ssh/authorized_keys

# 8. Delete old private key
rm ~/.ssh/ollama-chat-prod-key
```

---

## Infrastructure Strategy Integration

### How IAM Fits into Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Developer Workstation                                       │
│ - Terraform code                                            │
│ - AWS CLI credentials (AdministratorAccess)                 │
│ - SSH private key (~/.ssh/ollama-key.pem)                  │
└────────────────────┬────────────────────────────────────────┘
                     │ terraform apply
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ AWS Account                                                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ IAM Service                                         │   │
│  │ - EC2 Role (ollama_ec2_role)                       │   │
│  │ - Instance Profile (ollama_profile)                 │   │
│  │ - Policies (SSM, CloudWatch)                        │   │
│  │ - Key Pair (ollama_key public key)                 │   │
│  └────────────────────┬────────────────────────────────┘   │
│                       │                                     │
│                       ↓ (EC2 assumes role)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ EC2 Instances (Backend, Frontend, Single)          │   │
│  │ - Attached: ollama_profile                         │   │
│  │ - Authorized keys: ollama_key public key           │   │
│  │ - Uses role to call AWS APIs                        │   │
│  └────────────────────┬────────────────────────────────┘   │
│                       │                                     │
│                       ↓ (Uses credentials from role)        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ AWS Services                                        │   │
│  │ - CloudWatch Logs (receives log events)            │   │
│  │ - Systems Manager (SSM sessions)                    │   │
│  │ - EC2 Metadata Service (provides credentials)      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Integration with Other Components

#### IAM + Security Groups

Security groups control **network access**. IAM controls **API access**.

| Scenario                     | Security Group                     | IAM                                 |
| ---------------------------- | ---------------------------------- | ----------------------------------- |
| User accesses frontend       | ✅ Allows port 80/443              | ❌ Not involved (HTTP, not AWS API) |
| Backend writes to CloudWatch | ❌ Not involved (API, not network) | ✅ Allows `logs:PutLogEvents`       |
| Developer SSH to instance    | ✅ Allows port 22                  | ❌ Not involved (SSH, not AWS API)  |
| Developer SSM session        | ✅ Allows outbound HTTPS           | ✅ Allows `ssm:StartSession`        |

**Both required for SSM:**

- Security group: Allow outbound 443 (to reach SSM endpoints)
- IAM role: Allow `ssm:UpdateInstanceInformation`

#### IAM + VPC

Private subnet instances **still need IAM roles** to access AWS services:

```
Backend Instance (Private Subnet, no public IP)
     ↓ (Needs to write logs)
NAT Gateway (provides outbound internet)
     ↓
Internet Gateway
     ↓
CloudWatch Logs API endpoint (public internet)
```

Even though the instance is in a private subnet, the IAM role allows it to authenticate to CloudWatch.

#### IAM + Auto Scaling

**All instances in Auto Scaling Group share the same IAM role:**

```hcl
resource "aws_launch_template" "backend_lt" {
  iam_instance_profile {
    name = aws_iam_instance_profile.ollama_profile.name  # ← Same role for all instances
  }
}
```

**Why this is good:**

- ✅ Consistent permissions across instances
- ✅ New instances automatically get correct role
- ✅ Easy to update (change role, restart instances)

**If you need different permissions:**

```hcl
# Separate roles for backend and frontend
resource "aws_iam_role" "backend_role" { ... }
resource "aws_iam_role" "frontend_role" { ... }

# Backend instances get backend role
resource "aws_launch_template" "backend_lt" {
  iam_instance_profile {
    name = aws_iam_instance_profile.backend_profile.name
  }
}

# Frontend instances get frontend role
resource "aws_launch_template" "frontend_lt" {
  iam_instance_profile {
    name = aws_iam_instance_profile.frontend_profile.name
  }
}
```

---

## Required Permissions for Infrastructure Creation

### Overview

To **create** this infrastructure with Terraform, you need IAM permissions. This section documents what your **Terraform execution role** needs.

### Terraform Execution Context

**Who is running Terraform?**

| Context            | IAM Identity            | Credentials          |
| ------------------ | ----------------------- | -------------------- |
| **Local Laptop**   | Your IAM user           | `~/.aws/credentials` |
| **CI/CD Pipeline** | GitHub Actions IAM role | OIDC federation      |
| **Cloud9**         | EC2 instance role       | Instance metadata    |

### Required IAM Permissions for Terraform

#### Minimum Permissions Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:GetRole",
        "iam:DeleteRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": ["arn:aws:iam::*:role/ollama-chat-*"]
    },
    {
      "Sid": "IAMPolicyAttachment",
      "Effect": "Allow",
      "Action": ["iam:AttachRolePolicy", "iam:DetachRolePolicy"],
      "Resource": ["arn:aws:iam::*:role/ollama-chat-*"],
      "Condition": {
        "ArnEquals": {
          "iam:PolicyArn": [
            "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
          ]
        }
      }
    },
    {
      "Sid": "IAMInstanceProfileManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile",
        "iam:UntagInstanceProfile"
      ],
      "Resource": ["arn:aws:iam::*:instance-profile/ollama-chat-*"]
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::*:role/ollama-chat-*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ec2.amazonaws.com"
        }
      }
    },
    {
      "Sid": "EC2KeyPairManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:ImportKeyPair",
        "ec2:DescribeKeyPairs",
        "ec2:DeleteKeyPair",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2InstanceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeInstanceAttribute",
        "ec2:ModifyInstanceAttribute"
      ],
      "Resource": "*"
    }
  ]
}
```

### Permission Breakdown

#### IAMRoleManagement

**Actions:**

- `iam:CreateRole` - Create `ollama_ec2_role`
- `iam:GetRole` - Read role details (for Terraform state)
- `iam:DeleteRole` - Destroy role when running `terraform destroy`
- `iam:ListRolePolicies` - List inline policies attached to role
- `iam:ListAttachedRolePolicies` - List managed policies attached to role
- `iam:TagRole` - Add Name, Environment, Project tags

**Resource:**

```json
"Resource": "arn:aws:iam::*:role/ollama-chat-*"
```

This restricts Terraform to only manage roles starting with `ollama-chat-`. It **cannot** modify other roles like:

- ❌ Production roles from other projects
- ❌ AWS service-linked roles
- ❌ Your personal admin role

#### IAMPolicyAttachment

**Actions:**

- `iam:AttachRolePolicy` - Attach `AmazonSSMManagedInstanceCore` to role
- `iam:DetachRolePolicy` - Detach policy when updating role

**Condition:**

```json
"Condition": {
  "ArnEquals": {
    "iam:PolicyArn": [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ]
  }
}
```

This **restricts which policies** Terraform can attach. It can **only** attach:

- ✅ `AmazonSSMManagedInstanceCore`
- ✅ `CloudWatchAgentServerPolicy`

It **cannot** attach:

- ❌ `AdministratorAccess` (privilege escalation attack)
- ❌ Custom policies with dangerous permissions
- ❌ Policies from other projects

**Why this matters:** Prevents a compromised Terraform from granting itself admin access.

#### IAMPassRole

**Action:**

- `iam:PassRole` - Allow EC2 service to use `ollama_ec2_role`

**Condition:**

```json
"Condition": {
  "StringEquals": {
    "iam:PassedToService": "ec2.amazonaws.com"
  }
}
```

**What is PassRole?**

When you run `terraform apply` to create an EC2 instance with:

```hcl
iam_instance_profile = aws_iam_instance_profile.ollama_profile.name
```

Terraform makes this API call:

```python
ec2.run_instances(
    IamInstanceProfile={'Name': 'ollama-profile'}  # ← This requires iam:PassRole
)
```

AWS checks: "Is the Terraform execution role allowed to **pass** `ollama_ec2_role` to EC2 service?"

**Why PassRole is dangerous without conditions:**

```json
# BAD: Allow passing any role to any service
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "*"
}
```

**Attack scenario:**

1. Attacker compromises your AWS credentials
2. Attacker creates EC2 instance with `AdminRole` (has AdministratorAccess)
3. Attacker SSH to instance
4. Instance has admin credentials via role
5. Attacker now has full AWS access

**GOOD: Restrict PassRole**

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": "arn:aws:iam::*:role/ollama-chat-*",
  "Condition": {
    "StringEquals": {
      "iam:PassedToService": "ec2.amazonaws.com"
    }
  }
}
```

Now attacker can only pass `ollama-chat-*` roles to EC2 (not Lambda, not other services with higher privileges).

### Creating the Terraform Execution Role

#### Option 1: AdministratorAccess (Easy, Less Secure)

```bash
# Create IAM user for Terraform
aws iam create-user --user-name terraform-user

# Attach admin policy (NOT RECOMMENDED FOR PRODUCTION)
aws iam attach-user-policy \
  --user-name terraform-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access keys
aws iam create-access-key --user-name terraform-user
```

**Use this only for:**

- Learning/testing
- Personal AWS accounts
- Proof-of-concept projects

#### Option 2: Least-Privilege Policy (Secure, Production)

```bash
# Save the JSON policy above to terraform-permissions.json

# Create policy
aws iam create-policy \
  --policy-name OllamaChatTerraformPolicy \
  --policy-document file://terraform-permissions.json

# Create role for Terraform
aws iam create-role \
  --role-name OllamaChatTerraformRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USERNAME"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach policy to role
aws iam attach-role-policy \
  --role-name OllamaChatTerraformRole \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/OllamaChatTerraformPolicy

# Configure Terraform to assume role
# ~/.aws/credentials
[terraform]
role_arn = arn:aws:iam::YOUR_ACCOUNT_ID:role/OllamaChatTerraformRole
source_profile = default

# Use profile in Terraform
terraform init
AWS_PROFILE=terraform terraform apply
```

---

## Required Permissions for Infrastructure Usage

### Overview

This section documents what permissions the **EC2 instances** have (via the IAM role) and what **users** need to interact with the infrastructure.

### Permissions Granted to EC2 Instances

#### What ollama_ec2_role Can Do

| Permission                           | Granted By                   | What It Allows                  | Real-World Example                        |
| ------------------------------------ | ---------------------------- | ------------------------------- | ----------------------------------------- |
| **ssm:UpdateInstanceInformation**    | AmazonSSMManagedInstanceCore | Register with SSM service       | Instance appears in SSM console           |
| **ssmmessages:CreateControlChannel** | AmazonSSMManagedInstanceCore | Establish SSM session           | Developer connects via Session Manager    |
| **logs:CreateLogGroup**              | CloudWatchAgentServerPolicy  | Create log group on first write | Auto-setup of `/aws/ec2/ollama-chat-prod` |
| **logs:CreateLogStream**             | CloudWatchAgentServerPolicy  | Create stream per instance      | Separate logs per backend instance        |
| **logs:PutLogEvents**                | CloudWatchAgentServerPolicy  | Write log entries               | Flask app logs appear in CloudWatch       |
| **cloudwatch:PutMetricData**         | CloudWatchAgentServerPolicy  | Send custom metrics             | Track API response times                  |

#### What ollama_ec2_role CANNOT Do

| Action                   | Why Not Allowed          | Impact                           |
| ------------------------ | ------------------------ | -------------------------------- |
| **s3:PutObject**         | No S3 policy attached    | Can't write to S3 buckets        |
| **dynamodb:PutItem**     | No DynamoDB policy       | Can't store data in DynamoDB     |
| **ec2:RunInstances**     | No EC2 management policy | Can't launch other EC2 instances |
| **iam:CreateRole**       | No IAM policy            | Can't create new IAM roles       |
| **rds:CreateDBInstance** | No RDS policy            | Can't create databases           |

**If your application needs these permissions:**

```hcl
# Add custom policy for S3 access
resource "aws_iam_role_policy" "s3_access" {
  role = aws_iam_role.ollama_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::ollama-chat-models/*"
      }
    ]
  })
}
```

### Permissions Users Need

#### To Connect via SSM Session Manager

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:StartSession"],
      "Resource": ["arn:aws:ec2:*:*:instance/*"],
      "Condition": {
        "StringLike": {
          "ssm:resourceTag/Project": "ollama-chat-prod"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["ssm:TerminateSession", "ssm:ResumeSession"],
      "Resource": "arn:aws:ssm:*:*:session/${aws:username}-*"
    }
  ]
}
```

#### To View CloudWatch Logs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/ec2/ollama-chat-*"
    }
  ]
}
```

#### To SSH to Instances (Key-Based)

**No IAM permissions needed!** SSH uses the key pair:

```bash
# Only need:
# 1. Private key file (~/.ssh/ollama-key.pem)
# 2. Network access (security group allows port 22)
# 3. Instance public IP

ssh -i ~/.ssh/ollama-key.pem ubuntu@<instance-ip>
```

---

## Troubleshooting

### Common IAM Issues

#### Problem: "EC2 instance cannot write to CloudWatch"

**Symptoms:**

- Application logs don't appear in CloudWatch
- `/var/log/cloud-init-output.log` shows permission errors

**Diagnosis:**

```bash
# SSH to instance
ssh ubuntu@<instance-ip>

# Check if instance has IAM role
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# If empty output: No role attached
# If shows profile name: Role is attached

# Test CloudWatch access
aws logs describe-log-groups --region us-east-1

# If error "Unable to locate credentials": Instance metadata service issue
# If error "AccessDenied": IAM policy missing
```

**Fix:**

```bash
# Verify role is attached in Terraform
terraform state show aws_instance.ollama_app | grep iam_instance_profile

# Verify policies are attached
aws iam list-attached-role-policies --role-name ollama-chat-prod-ec2-role

# Should show:
# - AmazonSSMManagedInstanceCore
# - CloudWatchAgentServerPolicy

# If missing, re-apply Terraform
terraform apply -target=aws_iam_role_policy_attachment.cloudwatch_policy
```

#### Problem: "Cannot connect via SSM Session Manager"

**Symptoms:**

- `aws ssm start-session` fails with "TargetNotConnected"
- Instance doesn't appear in SSM console

**Diagnosis:**

```bash
# Check SSM agent status on instance
sudo systemctl status amazon-ssm-agent

# Check if role has SSM policy
aws iam list-attached-role-policies --role-name ollama-chat-prod-ec2-role | grep SSM

# Check security group allows outbound HTTPS
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

**Fix:**

1. **Start SSM agent:**

   ```bash
   sudo systemctl start amazon-ssm-agent
   sudo systemctl enable amazon-ssm-agent
   ```

2. **Verify IAM policy:**

   ```bash
   terraform apply -target=aws_iam_role_policy_attachment.ssm_policy
   ```

3. **Check security group:**
   ```hcl
   # Ensure egress allows HTTPS
   egress {
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ```

#### Problem: "SSH connection refused"

**Symptoms:**

- `ssh ubuntu@<ip>` hangs or shows "Connection refused"
- Port 22 not reachable

**Diagnosis:**

```bash
# Test if port 22 is open
nc -zv <instance-ip> 22

# Check security group
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'

# Check if SSH key is correct
ssh-keygen -l -f ~/.ssh/ollama-key.pem.pub
aws ec2 describe-key-pairs --key-names ollama-chat-prod-key
```

**Fix:**

1. **Security group not allowing SSH:**

   ```hcl
   # Add to security group
   ingress {
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["YOUR_IP/32"]
   }
   ```

2. **Wrong private key:**

   ```bash
   # Verify key fingerprint matches
   ssh-keygen -l -E md5 -f ~/.ssh/ollama-key.pem

   # Compare to AWS
   aws ec2 describe-key-pairs --key-names ollama-chat-prod-key \
     --query 'KeyPairs[0].KeyFingerprint'
   ```

3. **Instance in private subnet:**
   ```bash
   # Use bastion host or SSM instead
   aws ssm start-session --target <instance-id>
   ```

#### Problem: "Terraform cannot create IAM role"

**Symptoms:**

- `terraform apply` fails with "AccessDenied: User is not authorized to perform iam:CreateRole"

**Diagnosis:**

```bash
# Check your Terraform execution credentials
aws sts get-caller-identity

# Check what IAM permissions you have
aws iam list-attached-user-policies --user-name <your-username>
```

**Fix:**

**Option 1: Add IAM permissions to your user**

```bash
aws iam attach-user-policy \
  --user-name <your-username> \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

**Option 2: Use admin credentials temporarily**

```bash
# ~/.aws/credentials
[admin]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Use admin profile
AWS_PROFILE=admin terraform apply
```

### IAM Policy Simulator

**Test IAM permissions without deploying:**

```bash
# Test if role can write to CloudWatch
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:role/ollama-chat-prod-ec2-role \
  --action-names logs:PutLogEvents \
  --resource-arns "arn:aws:logs:us-east-1:ACCOUNT_ID:log-group:/aws/ec2/ollama-chat-prod"

# Output:
# {
#   "EvaluationResults": [{
#     "EvalDecision": "allowed",  ✅ Permission granted
#     "MatchedStatements": [{
#       "SourcePolicyId": "CloudWatchAgentServerPolicy"
#     }]
#   }]
# }
```

---

## Summary

### Key Takeaways

1. **IAM Role (`ollama_ec2_role`)**: Defines what EC2 instances can do (CloudWatch, SSM)
2. **Trust Policy**: Allows EC2 service to assume the role
3. **Permission Policies**: Grant specific API permissions (attached via `aws_iam_role_policy_attachment`)
4. **Instance Profile**: Bridges IAM role to EC2 instances (required by EC2 API)
5. **SSH Key Pair**: Traditional authentication (not IAM, but related to access)

### Best Practices

- ✅ Use AWS-managed policies when possible (AmazonSSMManagedInstanceCore)
- ✅ Principle of least privilege (only grant needed permissions)
- ✅ Separate roles for different instance types (backend vs frontend)
- ✅ Use SSM Session Manager instead of SSH (more secure, no port 22)
- ✅ Rotate SSH keys every 90 days
- ✅ Never store private keys in Terraform or Git
- ✅ Use IAM policy conditions to restrict PassRole
- ✅ Test permissions with IAM Policy Simulator before deployment

### Permission Checklist

**For Terraform (to create infrastructure):**

- [ ] `iam:CreateRole`
- [ ] `iam:AttachRolePolicy`
- [ ] `iam:CreateInstanceProfile`
- [ ] `iam:PassRole` (with conditions)
- [ ] `ec2:ImportKeyPair`

**For EC2 instances (to function):**

- [ ] `logs:CreateLogGroup` (CloudWatch logging)
- [ ] `logs:PutLogEvents` (CloudWatch logging)
- [ ] `ssm:UpdateInstanceInformation` (SSM registration)
- [ ] `ssmmessages:CreateControlChannel` (SSM sessions)

**For users (to manage infrastructure):**

- [ ] `ssm:StartSession` (SSM access)
- [ ] `logs:GetLogEvents` (view logs)
- [ ] `ec2:DescribeInstances` (view instance details)

---

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [CloudWatch Agent IAM Role](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-iam-roles-for-cloudwatch-agent.html)
- [SSH Key Pairs for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-25
**Maintained By:** Infrastructure Team
