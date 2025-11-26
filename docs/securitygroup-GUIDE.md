# Security Group Architecture Guide

## Table of Contents

1. [Overview](#overview)
2. [Security Group Fundamentals](#security-group-fundamentals)
3. [Defense in Depth Strategy](#defense-in-depth-strategy)
4. [ALB Security Group](#alb-security-group)
5. [Backend Security Group](#backend-security-group)
6. [Frontend Security Group](#frontend-security-group)
7. [Single-Instance Security Group](#single-instance-security-group)
8. [Security Group Relationships](#security-group-relationships)
9. [Traffic Flow Diagrams](#traffic-flow-diagrams)
10. [SSH Access Guide](#ssh-access-guide)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This document explains the security group architecture for the Ollama Chat App infrastructure. Security groups act as virtual firewalls controlling inbound and outbound traffic for AWS resources. Our architecture implements **defense in depth** with multiple security layers.

### Why Multiple Security Groups?

We use **4 separate security groups** instead of one "allow all" configuration because:

1. **Principle of Least Privilege**: Each component only gets the access it needs
2. **Blast Radius Reduction**: If one component is compromised, others remain protected
3. **Granular Control**: Different rules for different tiers (web, app, single-instance)
4. **Audit Trail**: Clear visibility into what traffic is allowed where
5. **Compliance**: Meets security best practices and regulatory requirements

---

## Security Group Fundamentals

### What is a Security Group?

A **security group** is a stateful firewall that controls traffic at the instance/resource level. Key characteristics:

- **Stateful**: If you allow inbound traffic, the response is automatically allowed outbound (and vice versa)
- **Allow Rules Only**: You can only create allow rules, not deny rules (use NACLs for deny rules)
- **Instance-Level**: Applied to ENIs (Elastic Network Interfaces) attached to EC2 instances, ALBs, etc.
- **Multiple Groups**: A resource can be associated with multiple security groups (rules are aggregated)

### Ingress vs Egress

- **Ingress (Inbound)**: Traffic coming INTO the resource
- **Egress (Outbound)**: Traffic going OUT from the resource

### Common Protocol Values

- **TCP**: Transmission Control Protocol (reliable, connection-oriented)
- **UDP**: User Datagram Protocol (fast, connectionless)
- **ICMP**: Internet Control Message Protocol (ping, diagnostics)
- **-1**: All protocols

---

## Defense in Depth Strategy

Our infrastructure implements layered security:

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Network ACL (Subnet Level)                            │
│ - Stateless firewall                                           │
│ - Allow/Deny rules                                              │
│ - Protects entire private subnet                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: ALB Security Group                                     │
│ - Internet-facing boundary                                      │
│ - Allows HTTP/HTTPS from world                                  │
│ - First line of defense                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Application Security Groups                            │
│ - Backend SG: Only accepts traffic from ALB                     │
│ - Frontend SG: Only accepts traffic from ALB                    │
│ - Instance-level protection                                     │
└─────────────────────────────────────────────────────────────────┘
```

**Why This Matters:**

- If ALB is compromised, backend/frontend instances still protected
- If Network ACL is misconfigured, security groups still enforce rules
- Multiple checkpoints = harder to breach

---

## ALB Security Group

### Resource Block

```hcl
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.ollama_vpc.id

  # HTTP access
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (will be restricted by target security groups)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **ALB Security Group** protects the Application Load Balancer, which is the single entry point for all user traffic. It's the "front door" to your application.

### Configuration Breakdown

| Component            | Value                        | Why This Value?                                                   |
| -------------------- | ---------------------------- | ----------------------------------------------------------------- |
| **name**             | `${var.project_name}-alb-sg` | Descriptive name with project prefix for easy identification      |
| **vpc_id**           | `aws_vpc.ollama_vpc.id`      | Must be in same VPC as ALB; security groups are VPC-scoped        |
| **Ingress Port 80**  | `0.0.0.0/0`                  | Allow HTTP from entire internet (public-facing web app)           |
| **Ingress Port 443** | `0.0.0.0/0`                  | Allow HTTPS from entire internet (secure traffic)                 |
| **Egress All**       | `0.0.0.0/0`                  | Allow all outbound; backend/frontend SGs control what they accept |

### Design Decisions

#### Why Allow All Egress?

```
Initial Thought: Restrict egress to only backend/frontend security groups
Problem: Creates circular dependency (alb_sg references backend_sg, backend_sg references alb_sg)
Solution: Allow all egress from ALB, restrict ingress at target instances
```

**This is the key insight**: Instead of ALB saying "I can only talk to backend_sg", we let backend_sg say "I only accept traffic from alb_sg". Same security outcome, no circular dependency.

#### Why Ports 80 and 443?

- **Port 80 (HTTP)**: Standard web traffic

  - Often redirected to 443 for security
  - Some clients don't support HTTPS
  - Required for Let's Encrypt certificate validation

- **Port 443 (HTTPS)**: Encrypted web traffic
  - Production standard
  - Protects data in transit
  - Required for modern browsers

#### Why 0.0.0.0/0 CIDR?

This means "allow from anywhere on the internet". For a **public web application**, this is correct because:

- Users can access from any IP address
- You don't know client IPs in advance
- CDNs, mobile networks, VPNs make IP whitelisting impractical

**For internal apps**, you'd restrict to corporate IP ranges:

```hcl
cidr_blocks = ["10.0.0.0/8", "192.168.1.0/24"]
```

### Infrastructure Strategy Fit

The ALB Security Group is the **perimeter defense**:

1. **Internet-Facing Boundary**: First AWS resource that internet traffic hits
2. **SSL Termination Point**: Where HTTPS gets decrypted (if using ACM certificates)
3. **Single Entry Point**: Simplifies security monitoring and WAF integration
4. **Traffic Distribution**: Routes to backend/frontend based on path rules

---

## Backend Security Group

### Resource Block

```hcl
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "Security group for Flask backend instances"
  vpc_id      = aws_vpc.ollama_vpc.id

  # Allow traffic from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH access from bastion or specific CIDR
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # All outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-backend-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **Backend Security Group** protects Flask API instances running in private subnets. These instances serve the `/api/*` endpoints and communicate with Ollama.

### Configuration Breakdown

| Component             | Value                           | Why This Value?                                                            |
| --------------------- | ------------------------------- | -------------------------------------------------------------------------- |
| **Ingress Port 8000** | `security_groups = [alb_sg.id]` | **ONLY** ALB can reach backend (security-group-to-security-group rule)     |
| **Ingress Port 22**   | `var.allowed_ssh_cidr`          | SSH for management from specific IPs only (principle of least privilege)   |
| **Egress All**        | `0.0.0.0/0`                     | Backend needs to download packages, pull Docker images, call external APIs |

### Design Decisions

#### Why Port 8000?

Flask backend listens on **port 8000** (defined in `docker-compose.yml`). This is:

- **Non-privileged port** (>1024, doesn't require root)
- **Common Flask convention** (gunicorn default: 8000)
- **Distinct from frontend** (port 3000) for easy identification

#### Why Security Group Reference Instead of CIDR?

```hcl
# Option 1: CIDR-based (BAD)
security_groups = ["10.0.1.0/24", "10.0.2.0/24"]  # ALB subnet CIDRs

# Option 2: Security Group reference (GOOD)
security_groups = [aws_security_group.alb_sg.id]
```

**Security group reference is better because:**

1. **Dynamic**: Works even if ALB moves to different subnet
2. **Explicit Intent**: "Allow from ALB" vs "Allow from these IPs"
3. **Maintainable**: No need to update if you add ALB subnets
4. **AWS Best Practice**: Decouples network topology from security rules

#### Why Allow All Egress?

Backend instances need outbound access for:

- **Package Updates**: `apt update`, `yum install`
- **Docker Hub**: Pulling images (`docker pull`)
- **Ollama Models**: Downloading LLMs from Ollama registry
- **AWS APIs**: CloudWatch logs, SSM session manager
- **External APIs**: If your app calls third-party services

**Could you restrict it?** Yes, but it's complex:

```hcl
# Restrict to specific services (advanced)
egress {
  description = "HTTPS to AWS services"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  prefix_list_ids = [data.aws_prefix_list.s3.id]  # S3, CloudWatch, etc.
}
```

For **most applications**, allowing all egress is acceptable because:

- Egress risk is lower than ingress (you're initiating connections)
- Instances are in private subnets (NAT Gateway controls outbound)
- VPC Flow Logs can monitor all outbound traffic

#### SSH Access Strategy

```hcl
cidr_blocks = var.allowed_ssh_cidr
```

This variable should be set to:

**Development:**

```hcl
allowed_ssh_cidr = ["0.0.0.0/0"]  # Allow from anywhere (testing)
```

**Production:**

```hcl
allowed_ssh_cidr = [
  "203.0.113.0/24",  # Corporate VPN IP range
  "10.0.1.0/24"       # Bastion host subnet
]
```

**Best Practice:** Use **AWS Systems Manager Session Manager** instead of SSH:

- No need to open port 22
- Centralized access logging
- No need to manage SSH keys
- Works from AWS console

### Infrastructure Strategy Fit

The Backend Security Group implements **Zero Trust** principles:

1. **Private Subnet Isolation**: Backend instances have no public IPs
2. **ALB-Only Access**: Can't be reached directly from internet
3. **Controlled SSH**: Management access only from authorized networks
4. **API Gateway Pattern**: ALB acts as API gateway, backend is hidden

**Traffic Flow:**

```
User → ALB:80/443 → Backend:8000 → Ollama:11434
     (public)      (private)       (container)
```

---

## Frontend Security Group

### Resource Block

```hcl
resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-frontend-sg"
  description = "Security group for React frontend instances"
  vpc_id      = aws_vpc.ollama_vpc.id

  # Allow traffic from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # All outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-frontend-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **Frontend Security Group** protects React frontend instances serving the web UI. These instances handle all non-API paths (`/`, `/chat`, `/settings`, etc.).

### Configuration Breakdown

| Component             | Value                           | Why This Value?                                         |
| --------------------- | ------------------------------- | ------------------------------------------------------- |
| **Ingress Port 3000** | `security_groups = [alb_sg.id]` | **ONLY** ALB can reach frontend (React dev server port) |
| **Ingress Port 22**   | `var.allowed_ssh_cidr`          | SSH for management from specific IPs only               |
| **Egress All**        | `0.0.0.0/0`                     | Frontend needs to fetch dependencies, call backend APIs |

### Design Decisions

#### Why Port 3000?

React's development server runs on **port 3000** by default (Vite, Create React App). We keep this in production because:

- **Consistency**: Same port in dev and prod reduces configuration drift
- **Non-privileged**: Doesn't require root to bind
- **Docker-friendly**: Easy to expose in container

**Alternative:** Use Nginx on port 80/443 inside the container:

```dockerfile
# Multi-stage build
FROM node:18 AS build
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

#### Why Separate Frontend and Backend Security Groups?

You might wonder: "Both frontend and backend have the same rules (ALB + SSH). Why not one security group?"

**Reasons to keep them separate:**

1. **Future Flexibility**: Frontend might need different ports later (WebSockets on 8080)
2. **Audit Clarity**: Security reviews are easier with clear role separation
3. **Blast Radius**: If you accidentally modify frontend SG, backend is unaffected
4. **Compliance**: Some frameworks require tier-based security groups
5. **Principle of Least Privilege**: Even if rules are same now, intentions differ

**When to combine them:**

- Small non-production environments
- Proof-of-concept deployments
- Extremely cost-sensitive setups (security groups are free, so this is rare)

#### Frontend Egress Needs

Frontend instances need outbound access for:

- **NPM Registry**: Installing packages during build
- **Backend API Calls**: If frontend makes server-side API calls (SSR)
- **AWS Services**: CloudWatch logs, SSM session manager
- **CDN/Assets**: Fetching fonts, libraries from CDNs

**Important Note**: If your React app is **purely client-side** (SPA), the frontend instance only serves static files. The user's browser makes API calls directly to the ALB, not from the frontend instance.

### Infrastructure Strategy Fit

The Frontend Security Group supports a **decoupled architecture**:

1. **Stateless Frontend**: Instances can be replaced without data loss
2. **Horizontal Scalability**: Easy to add more frontend instances behind ALB
3. **Private Subnet**: Frontend instances have no public IPs (security)
4. **ALB Routing**: ALB handles path-based routing to backend

**Request Flow:**

```
User requests /chat
     ↓
ALB receives request on port 80/443
     ↓
ALB routes to Frontend Target Group
     ↓
Frontend instance serves React SPA on port 3000
     ↓
User's browser loads JavaScript
     ↓
JavaScript makes API calls to /api/* (routed to backend by ALB)
```

---

## Single-Instance Security Group

### Resource Block

```hcl
resource "aws_security_group" "ollama_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Ollama Chat App"
  vpc_id      = aws_vpc.ollama_vpc.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend (if not behind nginx)
  ingress {
    description = "Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API (if not behind nginx)
  ingress {
    description = "Backend API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ollama service (localhost only - Docker internal)
  ingress {
    description = "Ollama Service"
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    self        = true
  }

  # Outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

The **Single-Instance Security Group** is for a **simpler deployment architecture** where all components (frontend, backend, Ollama) run on **one EC2 instance**. This is useful for:

- **Development/Testing**: Quick setup without ALB/ASG complexity
- **Low-Budget Projects**: Minimize AWS costs ($50/month vs $100/month)
- **Proof of Concept**: Validate idea before scaling
- **Personal Use**: Single-user applications

### Configuration Breakdown

| Component              | Value                  | Why This Value?                                                  |
| ---------------------- | ---------------------- | ---------------------------------------------------------------- |
| **Ingress Port 22**    | `var.allowed_ssh_cidr` | SSH for management                                               |
| **Ingress Port 80**    | `0.0.0.0/0`            | HTTP from internet (direct access, no ALB)                       |
| **Ingress Port 443**   | `0.0.0.0/0`            | HTTPS from internet (with self-signed or Let's Encrypt cert)     |
| **Ingress Port 3000**  | `0.0.0.0/0`            | Direct access to React frontend (if not using reverse proxy)     |
| **Ingress Port 8000**  | `0.0.0.0/0`            | Direct access to Flask backend (if not using reverse proxy)      |
| **Ingress Port 11434** | `self = true`          | **ONLY** this instance can reach Ollama (container-to-container) |
| **Egress All**         | `0.0.0.0/0`            | Instance needs internet access                                   |

### Design Decisions

#### Why Allow Ports 3000 and 8000 from Internet?

In the **single-instance architecture**, you have two deployment options:

**Option 1: Direct Exposure (Simpler)**

```
User:80 → Frontend:3000
User:80/api/* → Backend:8000
Backend:8000 → Ollama:11434
```

- Frontend and backend expose their ports directly
- No reverse proxy needed
- Security group allows 3000 and 8000 from internet

**Option 2: Nginx Reverse Proxy (Production)**

```
User:80 → Nginx:80 → Frontend:3000 (localhost)
                   → Backend:8000 (localhost)
                   → Ollama:11434 (localhost)
```

- Only port 80/443 open to internet
- Nginx routes internally based on path
- More secure, but requires Nginx configuration

Our security group allows **both patterns** (ports 3000, 8000, 80, 443) so you can choose based on your needs.

#### Why `self = true` for Port 11434?

```hcl
ingress {
  description = "Ollama Service"
  from_port   = 11434
  to_port     = 11434
  protocol    = "tcp"
  self        = true  # ← Key security feature
}
```

`self = true` means "only resources with **this same security group** can access port 11434". Since only one instance has `ollama_sg`, this effectively means:

- **Backend container on this instance** can reach Ollama ✓
- **Other EC2 instances** cannot reach Ollama ✗
- **Internet** cannot reach Ollama ✗

**Why this matters**: Ollama has no authentication by default. If you exposed port 11434 to `0.0.0.0/0`, anyone could use your AI models for free (and rack up compute costs).

#### Single-Instance vs Multi-Instance Architecture

| Aspect                | Single-Instance (ollama_sg)       | Multi-Instance (alb_sg + backend_sg + frontend_sg) |
| --------------------- | --------------------------------- | -------------------------------------------------- |
| **Cost**              | ~$50/month (1 t3.medium + EIP)    | ~$120/month (ALB + NAT + 2x instances)             |
| **High Availability** | ✗ Single point of failure         | ✓ Multi-AZ with auto-scaling                       |
| **Scalability**       | ✗ Vertical only (larger instance) | ✓ Horizontal (add more instances)                  |
| **Security**          | ⚠️ All ports on one instance      | ✓✓✓ Defense in depth, private subnets              |
| **Complexity**        | ⭐ Simple (1 instance, 1 SG)      | ⭐⭐⭐ Complex (ALB, ASG, 4 SGs)                   |
| **SSL**               | Self-signed or Let's Encrypt      | AWS Certificate Manager (ACM)                      |
| **Use Case**          | Dev, POC, personal                | Production, enterprise                             |

### Infrastructure Strategy Fit

The Single-Instance Security Group is for the **monolithic deployment pattern**:

```
┌────────────────────────────────────────┐
│         EC2 Instance (Public)          │
│                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────┐│
│  │ Frontend │  │ Backend  │  │Ollama││
│  │  :3000   │  │  :8000   │  │:11434││
│  └──────────┘  └──────────┘  └──────┘│
│                                        │
│  Security Group: ollama_sg             │
│  - Ports 22, 80, 443, 3000, 8000       │
│  - Public IP for direct access         │
└────────────────────────────────────────┘
```

**When to use this:**

1. **Learning/Testing**: Understand the app before scaling
2. **Budget Constraints**: Minimize AWS costs
3. **Low Traffic**: <1000 users, minimal concurrent requests
4. **Rapid Iteration**: Deploy changes quickly without ALB/ASG complexity

**When to migrate to multi-instance:**

1. Users complain about downtime
2. Traffic exceeds 1000 requests/hour
3. Need to deploy updates without downtime
4. Require compliance certifications (SOC2, HIPAA)

---

## Security Group Relationships

### Dependency Graph

```
┌─────────────┐
│   alb_sg    │ (Created first, no dependencies)
└──────┬──────┘
       │
       ├─────────────┬─────────────┐
       ↓             ↓             ↓
┌──────────┐   ┌──────────┐   ┌──────────┐
│backend_sg│   │frontend_ │   │ ollama_sg│
│          │   │   sg     │   │          │
└──────────┘   └──────────┘   └──────────┘
   (references       (references     (independent)
    alb_sg.id)        alb_sg.id)
```

### Why This Ordering Matters

Terraform creates resources in dependency order. If we had:

```hcl
# BAD: Circular dependency
resource "aws_security_group" "alb_sg" {
  egress {
    security_groups = [aws_security_group.backend_sg.id]  # References backend_sg
  }
}

resource "aws_security_group" "backend_sg" {
  ingress {
    security_groups = [aws_security_group.alb_sg.id]  # References alb_sg
  }
}
```

**Terraform error:**

```
Cycle: aws_security_group.alb_sg, aws_security_group.backend_sg
```

**Solution:** One-way references only (backend/frontend reference ALB, not vice versa)

### Security Group Rule Matrix

| Source                 | Destination   | Port | Protocol | Purpose                      |
| ---------------------- | ------------- | ---- | -------- | ---------------------------- |
| `0.0.0.0/0`            | `alb_sg`      | 80   | TCP      | User HTTP requests           |
| `0.0.0.0/0`            | `alb_sg`      | 443  | TCP      | User HTTPS requests          |
| `alb_sg`               | `backend_sg`  | 8000 | TCP      | API requests to Flask        |
| `alb_sg`               | `frontend_sg` | 3000 | TCP      | Web requests to React        |
| `var.allowed_ssh_cidr` | `backend_sg`  | 22   | TCP      | SSH management               |
| `var.allowed_ssh_cidr` | `frontend_sg` | 22   | TCP      | SSH management               |
| `backend_sg`           | `0.0.0.0/0`   | All  | All      | Download packages, call APIs |
| `frontend_sg`          | `0.0.0.0/0`   | All  | All      | Download packages            |

**Security Rule:**

- ✓ **Good**: Specific source security group (`security_groups = [aws_security_group.alb_sg.id]`)
- ✓ **Acceptable**: Restricted CIDR (`cidr_blocks = ["10.0.0.0/16"]`)
- ⚠️ **Caution**: Wide CIDR for ingress (`cidr_blocks = ["0.0.0.0/0"]`)
- ✗ **Bad**: Wide CIDR for management ports (`port 22 from 0.0.0.0/0`)

---

## Traffic Flow Diagrams

### Multi-Instance Architecture Flow

```
                          INTERNET
                             │
                             ↓ (HTTP/HTTPS: 80/443)
                     ┌───────────────┐
                     │   alb_sg      │
                     │  (ALB)        │
                     └───────┬───────┘
                             │
                ┌────────────┼────────────┐
                │                         │
                ↓ (port 8000)            ↓ (port 3000)
        ┌───────────────┐        ┌───────────────┐
        │  backend_sg   │        │  frontend_sg  │
        │  (Flask)      │        │  (React)      │
        └───────┬───────┘        └───────────────┘
                │
                ↓ (port 11434, localhost)
        ┌───────────────┐
        │    Ollama     │
        │  (Container)  │
        └───────────────┘
```

**Rule Summary:**

1. Internet → ALB (80/443): Allowed by `alb_sg` ingress
2. ALB → Backend (8000): Allowed by `backend_sg` ingress (security group reference)
3. ALB → Frontend (3000): Allowed by `frontend_sg` ingress (security group reference)
4. Backend → Ollama (11434): Container-to-container (Docker network)

### Single-Instance Architecture Flow

```
                          INTERNET
                             │
                ┌────────────┼────────────┐
                │            │            │
                ↓ (80/443)  ↓ (3000)    ↓ (8000)
        ┌──────────────────────────────────────┐
        │         ollama_sg (EC2)              │
        │                                      │
        │  ┌──────┐   ┌──────┐   ┌────────┐  │
        │  │React │   │Flask │   │ Ollama │  │
        │  │:3000 │   │:8000 │←→│ :11434 │  │
        │  └──────┘   └──────┘   └────────┘  │
        │                                      │
        └──────────────────────────────────────┘
                             │
                             ↓
                      AWS Services
                  (CloudWatch, SSM)
```

**Rule Summary:**

1. Internet → EC2 (80/443/3000/8000): Allowed by `ollama_sg` ingress
2. Flask → Ollama (11434): Allowed by `self = true` (same security group)

### SSH Access Flow (Both Architectures)

```
        Your Laptop (IP: 203.0.113.5)
                │
                ↓ (port 22)
        ┌───────────────┐
        │ var.allowed_  │ ← This variable controls who can SSH
        │   ssh_cidr    │
        └───────┬───────┘
                │
                ↓
        ┌───────────────┐
        │ Backend/      │
        │ Frontend/     │
        │ Single-       │
        │ Instance SG   │
        └───────────────┘
```

**SSH is allowed if your IP is in `var.allowed_ssh_cidr`**

---

## SSH Access Guide

### Prerequisites

1. **SSH Key Pair**: You need the private key for `aws_key_pair.ollama_key`
2. **IP Whitelisting**: Your IP must be in `var.allowed_ssh_cidr`
3. **Instance Details**: Public IP (single-instance) or private IP (multi-instance)

### Option 1: SSH to Single-Instance Deployment

#### Step 1: Get Instance Public IP

```bash
# From Terraform outputs
terraform output instance_public_ip

# Or from AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ollama-chat-prod-instance" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

#### Step 2: SSH Directly

```bash
ssh -i ~/.ssh/ollama-chat-prod-key.pem ubuntu@<INSTANCE_PUBLIC_IP>

# Example:
ssh -i ~/.ssh/ollama-chat-prod-key.pem ubuntu@54.123.45.67
```

#### Step 3: Verify Services

```bash
# Check running containers
docker ps

# Expected output:
# CONTAINER ID   IMAGE                    PORTS
# abc123         ollama/ollama            0.0.0.0:11434->11434/tcp
# def456         ollama-backend           0.0.0.0:8000->8000/tcp
# ghi789         ollama-frontend          0.0.0.0:3000->3000/tcp

# Check logs
docker logs <container_id>
```

---

### Option 2: SSH to Multi-Instance (Backend/Frontend in Private Subnets)

Since backend/frontend instances are in **private subnets** with no public IPs, you need a **bastion host** or **AWS Systems Manager**.

#### Method A: Bastion Host (Jump Server)

**Step 1: Deploy Bastion Host**

```hcl
# Add to main.tf
resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ollama_key.key_name
  subnet_id     = aws_subnet.public_subnet_1.id

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_security_group" "bastion_sg" {
  name   = "${var.project_name}-bastion-sg"
  vpc_id = aws_vpc.ollama_vpc.id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    description = "SSH to private instances"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Only within VPC
  }
}
```

**Step 2: Update Backend/Frontend Security Groups**

```hcl
# Add to backend_sg and frontend_sg
ingress {
  description     = "SSH from bastion"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
}
```

**Step 3: SSH Via Bastion**

```bash
# Method 1: Two-step SSH
ssh -i ~/.ssh/ollama-key.pem ubuntu@<BASTION_PUBLIC_IP>
# Once on bastion:
ssh ubuntu@<BACKEND_PRIVATE_IP>

# Method 2: SSH ProxyJump (one command)
ssh -i ~/.ssh/ollama-key.pem \
  -J ubuntu@<BASTION_PUBLIC_IP> \
  ubuntu@<BACKEND_PRIVATE_IP>

# Method 3: SSH Config (~/.ssh/config)
Host bastion
  HostName <BASTION_PUBLIC_IP>
  User ubuntu
  IdentityFile ~/.ssh/ollama-key.pem

Host backend
  HostName <BACKEND_PRIVATE_IP>
  User ubuntu
  IdentityFile ~/.ssh/ollama-key.pem
  ProxyJump bastion

# Then simply:
ssh backend
```

#### Method B: AWS Systems Manager (SSM) - **RECOMMENDED**

**Why SSM is Better:**

- ✓ No bastion host needed (save $8/month)
- ✓ No SSH keys needed (IAM-based authentication)
- ✓ All sessions logged to CloudWatch
- ✓ No port 22 exposure (more secure)
- ✓ Works from AWS console (no terminal required)

**Step 1: Ensure IAM Role Has SSM Policy**

Already done in our `main.tf`:

```hcl
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ollama_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**Step 2: Remove Port 22 from Security Groups (Optional, for max security)**

```hcl
# Comment out SSH ingress rules in backend_sg and frontend_sg
# ingress {
#   description = "SSH"
#   from_port   = 22
#   to_port     = 22
#   protocol    = "tcp"
#   cidr_blocks = var.allowed_ssh_cidr
# }
```

**Step 3: Connect Via AWS CLI**

```bash
# Install Session Manager plugin
# See: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# List available instances
aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus]' \
  --output table

# Start session
aws ssm start-session --target i-1234567890abcdef0

# Or use instance name tag
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=ollama-chat-prod-backend-asg-instance" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm start-session --target $INSTANCE_ID
```

**Step 4: Connect Via AWS Console**

1. Go to **EC2 Console** → **Instances**
2. Select backend/frontend instance
3. Click **Connect** button
4. Choose **Session Manager** tab
5. Click **Connect**

**Step 5: Enable Port Forwarding (Access Backend Directly)**

```bash
# Forward remote port 8000 to local port 8000
aws ssm start-session \
  --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8000"],"localPortNumber":["8000"]}'

# Now access backend on localhost:
curl http://localhost:8000/health
```

---

### SSH Access Matrix

| Deployment          | Instance Type       | Access Method  | Public IP? | Command                          |
| ------------------- | ------------------- | -------------- | ---------- | -------------------------------- |
| **Single-Instance** | EC2 (public subnet) | Direct SSH     | ✓ Yes      | `ssh ubuntu@<public_ip>`         |
| **Multi-Instance**  | Backend (private)   | Bastion or SSM | ✗ No       | `ssh -J bastion backend` or SSM  |
| **Multi-Instance**  | Frontend (private)  | Bastion or SSM | ✗ No       | `ssh -J bastion frontend` or SSM |
| **Multi-Instance**  | Bastion (public)    | Direct SSH     | ✓ Yes      | `ssh ubuntu@<bastion_ip>`        |

---

### Getting Instance IPs/IDs

#### Terraform Outputs

```bash
# View all outputs
terraform output

# Specific output
terraform output backend_instance_private_ips
terraform output frontend_instance_private_ips
```

#### AWS CLI

```bash
# Get backend instance IPs
aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Backend" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Get frontend instance IPs
aws ec2 describe-instances \
  --filters "Name=tag:Tier,Values=Frontend" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

---

### Common SSH Issues and Solutions

#### Issue 1: "Permission denied (publickey)"

**Cause:** Wrong SSH key or key not added to SSH agent

**Solution:**

```bash
# Verify key permissions
chmod 400 ~/.ssh/ollama-key.pem

# Add key to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/ollama-key.pem

# Specify key explicitly
ssh -i ~/.ssh/ollama-key.pem ubuntu@<ip>
```

#### Issue 2: "Connection timed out"

**Cause:** Security group doesn't allow your IP

**Solution:**

```bash
# Check your public IP
curl ifconfig.me

# Update terraform.tfvars
allowed_ssh_cidr = ["<your_ip>/32"]

# Apply changes
terraform apply
```

#### Issue 3: "No route to host" (Private Instances)

**Cause:** Trying to SSH directly to private subnet instance

**Solution:**

- Use bastion host (`ssh -J bastion backend`)
- Use AWS Systems Manager (no bastion needed)

#### Issue 4: "Host key verification failed"

**Cause:** Instance was recreated with new host key

**Solution:**

```bash
# Remove old host key
ssh-keygen -R <ip_address>

# Or disable host key checking (less secure)
ssh -o StrictHostKeyChecking=no ubuntu@<ip>
```

---

## Troubleshooting

### Security Group Testing

#### Test Inbound Connectivity

```bash
# Test if port is open (from your laptop)
nc -zv <target_ip> <port>

# Examples:
nc -zv 54.123.45.67 80    # Test ALB HTTP
nc -zv 54.123.45.67 443   # Test ALB HTTPS
nc -zv 10.0.11.5 8000     # Test backend (from bastion)

# Expected output if port is open:
# Connection to 54.123.45.67 port 80 [tcp/http] succeeded!
```

#### Test Outbound Connectivity

```bash
# SSH into instance, then test outbound
curl -I https://google.com          # Test internet access
curl -I http://10.0.11.5:8000       # Test backend from ALB
curl -I http://ollama:11434/health  # Test Ollama from backend container
```

### Common Security Group Issues

#### Problem: "Can't reach backend from ALB"

**Symptoms:**

- ALB health checks fail
- 502 Bad Gateway errors
- Target group shows unhealthy instances

**Diagnosis:**

```bash
# Check backend security group ingress
aws ec2 describe-security-groups \
  --group-ids <backend_sg_id> \
  --query 'SecurityGroups[0].IpPermissions'

# Verify ALB security group ID is allowed
```

**Fix:**

```hcl
# Ensure backend_sg allows traffic from alb_sg
ingress {
  from_port       = 8000
  to_port         = 8000
  protocol        = "tcp"
  security_groups = [aws_security_group.alb_sg.id]  # ← Must reference ALB SG
}
```

#### Problem: "Can't SSH to instance"

**Symptoms:**

- Connection timeout
- "No route to host"

**Diagnosis:**

```bash
# 1. Check your public IP
curl ifconfig.me

# 2. Check if that IP is in allowed_ssh_cidr
terraform show | grep allowed_ssh_cidr

# 3. Check security group rules
aws ec2 describe-security-groups \
  --group-ids <sg_id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
```

**Fix:**

```hcl
# Update terraform.tfvars
allowed_ssh_cidr = ["<your_ip>/32", "10.0.0.0/16"]

# Apply
terraform apply -var-file=terraform.tfvars
```

#### Problem: "Backend can't download packages"

**Symptoms:**

- `apt update` fails
- `docker pull` fails
- User data script fails

**Diagnosis:**

```bash
# SSH to backend instance
# Try to reach internet
curl -I https://google.com
ping 8.8.8.8

# Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table
```

**Fix:**

1. **Check NAT Gateway**: Ensure NAT is running and has Elastic IP
2. **Check Route Table**: Private subnet route table must point `0.0.0.0/0` to NAT Gateway
3. **Check Security Group Egress**: Backend SG must allow outbound traffic

```hcl
# Backend SG must have this egress rule
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

### Security Group Change Impact

#### Low-Risk Changes

- ✓ Adding new ingress rule (expanding access)
- ✓ Adding new egress rule (expanding access)
- ✓ Updating descriptions (no connectivity impact)
- ✓ Adding tags (no connectivity impact)

#### Medium-Risk Changes

- ⚠️ Changing source CIDR (might break existing connections)
- ⚠️ Changing port numbers (requires app reconfiguration)
- ⚠️ Removing ingress rules (will block traffic)

#### High-Risk Changes

- 🚨 Removing egress rules (can break app functionality)
- 🚨 Changing security group ID references (requires dependency updates)
- 🚨 Recreating security group (causes downtime)

**Best Practice:** Test security group changes in a **non-production environment** first!

---

## Summary

### Key Takeaways

1. **Defense in Depth**: Use multiple security groups (ALB, backend, frontend) instead of one permissive group
2. **Least Privilege**: Only allow the minimum required access (security group references > CIDR blocks)
3. **Stateful Firewall**: If you allow inbound, outbound response is automatic
4. **Private Subnets**: Backend/frontend instances have no public IPs (must use bastion or SSM)
5. **Single-Instance Option**: Useful for development, but less secure than multi-instance

### Security Group Design Checklist

- [ ] ALB accepts HTTP/HTTPS from internet (`0.0.0.0/0`)
- [ ] Backend only accepts traffic from ALB (security group reference)
- [ ] Frontend only accepts traffic from ALB (security group reference)
- [ ] SSH restricted to corporate IP range (`var.allowed_ssh_cidr`)
- [ ] Ollama port (11434) restricted to `self = true` or localhost
- [ ] All egress rules allow required outbound traffic
- [ ] No circular dependencies between security groups
- [ ] Tags applied for cost tracking and organization

### Next Steps

1. **Review your `terraform.tfvars`**: Ensure `allowed_ssh_cidr` is set correctly
2. **Choose SSH method**: Bastion host or AWS Systems Manager
3. **Test connectivity**: Use `nc`, `curl`, and SSH to verify all paths work
4. **Monitor traffic**: Enable VPC Flow Logs to see all security group decisions
5. **Automate audits**: Use AWS Config rules to detect security group misconfigurations

---

## Additional Resources

- [AWS Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-25
**Maintained By:** Infrastructure Team
