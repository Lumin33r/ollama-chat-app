# Ollama Chat App - Production Networking Architecture

A comprehensive guide to the network infrastructure design for the Ollama Chat App, explaining each component and its role in the overall architecture strategy.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [VPC Configuration](#vpc-configuration)
3. [Internet Gateway](#internet-gateway)
4. [Public Subnets](#public-subnets)
5. [Private Subnets](#private-subnets)
6. [Public Route Table](#public-route-table)
7. [NAT Gateways](#nat-gateways)
8. [Private Route Tables](#private-route-tables)
9. [Network ACL](#network-acl)
10. [Network Architecture Diagram](#network-architecture-diagram)
11. [Design Decisions](#design-decisions)

---

## Architecture Overview

The Ollama Chat App uses a **multi-tier network architecture** with:

- **Public Tier**: Hosts the Application Load Balancer (ALB) and NAT Gateways
- **Private Tier**: Hosts backend and frontend application instances (Auto Scaling Groups only)
- **Multi-AZ Deployment**: Spans 2 Availability Zones for high availability
- **Defense in Depth**: Uses Security Groups + Network ACLs
- **Stateless Design**: No persistent storage - application runs entirely in memory

### Why This Architecture?

1. **Security**: Application instances are isolated in private subnets with no direct internet access
2. **High Availability**: Multi-AZ deployment with Auto Scaling ensures resilience against failures
3. **Scalability**: Auto Scaling Groups dynamically add/remove instances based on CPU load
4. **Simplicity**: No storage management - stateless application architecture
5. **Secure Access**: Systems Manager (SSM) Session Manager for instance access (no SSH keys required)
6. **Cost Efficiency**: NAT Gateways enable outbound internet for updates without requiring public IPs on every instance

---

## VPC Configuration

### Terraform Code

```terraform
resource "aws_vpc" "ollama_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

Creates an **isolated virtual network** in AWS where all infrastructure resources will be deployed.

### Configuration Choices

| Setting                | Value                   | Why This Value?                                                               |
| ---------------------- | ----------------------- | ----------------------------------------------------------------------------- |
| `cidr_block`           | `10.0.0.0/16` (default) | Provides 65,536 IP addresses, plenty for growth. Private IP range (RFC 1918)  |
| `enable_dns_hostnames` | `true`                  | Instances get DNS names like `ec2-xx-xx-xx-xx.compute.amazonaws.com`          |
| `enable_dns_support`   | `true`                  | Enables AWS DNS resolution (Route 53 resolver) for internal service discovery |

### Infrastructure Strategy

- **Isolation**: Completely isolated from other AWS accounts and VPCs
- **Control**: Full control over IP addressing, routing, and security
- **Future-Proof**: Large address space allows for subnet expansion

---

## Internet Gateway

### Terraform Code

```terraform
resource "aws_internet_gateway" "ollama_igw" {
  vpc_id = aws_vpc.ollama_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

Provides **bidirectional internet connectivity** for resources in public subnets.

### Configuration Choices

| Setting  | Value            | Why This Value?                           |
| -------- | ---------------- | ----------------------------------------- |
| `vpc_id` | Reference to VPC | Attaches IGW to our VPC (one IGW per VPC) |

### Infrastructure Strategy

- **Public Access**: Enables the ALB to receive traffic from the internet
- **Outbound Traffic**: Allows NAT Gateways to route private subnet traffic to the internet
- **High Availability**: Automatically redundant and scales with traffic

### Traffic Flow

```
Internet ← → Internet Gateway ← → Public Subnets (ALB, NAT Gateways)
```

---

## Public Subnets

### Terraform Code

```terraform
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.ollama_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-1"
    Environment = var.environment
    Type        = "Public"
    Project     = var.project_name
    Tier        = "Web"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.ollama_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-2"
    Environment = var.environment
    Type        = "Public"
    Project     = var.project_name
    Tier        = "Web"
  }
}
```

### Purpose

Host **internet-facing resources** like the Application Load Balancer and NAT Gateways.

### Configuration Choices

| Setting                   | Value                     | Why This Value?                            |
| ------------------------- | ------------------------- | ------------------------------------------ |
| `cidr_block` (subnet 1)   | `10.0.1.0/24`             | 256 IPs - adequate for ALB and NAT Gateway |
| `cidr_block` (subnet 2)   | `10.0.2.0/24`             | 256 IPs - maintains consistency across AZs |
| `availability_zone`       | `names[0]` and `names[1]` | Deploys across 2 different AZs for HA      |
| `map_public_ip_on_launch` | `true`                    | Instances automatically get public IPs     |
| Tag: `Tier`               | `"Web"`                   | Identifies as web/presentation tier        |

### Infrastructure Strategy

- **High Availability**: Two subnets across different AZs ensure if one AZ fails, the other continues serving traffic
- **ALB Requirement**: ALB requires at least 2 subnets in different AZs
- **Small CIDR**: /24 is sufficient since only ALB and NAT Gateways live here
- **Public Access**: Route table directs traffic through Internet Gateway

### What Goes Here?

✅ **Belongs in Public Subnets:**

- Application Load Balancer (ALB)
- NAT Gateways

❌ **Should NOT be in Public Subnets:**

- Backend application instances
- Frontend application instances
- Database servers

**Note**: Instance access is via AWS Systems Manager Session Manager (no bastion hosts needed)

---

## Private Subnets

### Terraform Code

```terraform
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.ollama_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.project_name}-private-subnet-1"
    Environment = var.environment
    Type        = "Private"
    Project     = var.project_name
    Tier        = "Application"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.ollama_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.project_name}-private-subnet-2"
    Environment = var.environment
    Type        = "Private"
    Project     = var.project_name
    Tier        = "Application"
  }
}
```

### Purpose

Host **application instances** that should NOT be directly accessible from the internet.

### Configuration Choices

| Setting                   | Value                     | Why This Value?                               |
| ------------------------- | ------------------------- | --------------------------------------------- |
| `cidr_block` (subnet 1)   | `10.0.11.0/24`            | 256 IPs - room for Auto Scaling expansion     |
| `cidr_block` (subnet 2)   | `10.0.12.0/24`            | Consistent sizing across AZs                  |
| `availability_zone`       | `names[0]` and `names[1]` | Matches AZ distribution of public subnets     |
| `map_public_ip_on_launch` | **Not set** (false)       | Instances do NOT get public IPs               |
| Tag: `Tier`               | `"Application"`           | Identifies as application/business logic tier |

### Infrastructure Strategy

- **Security**: No direct inbound internet access - only through ALB
- **Outbound Access**: Can reach internet via NAT Gateway for updates/downloads
- **Multi-AZ**: Backend and frontend instances distributed across both subnets
- **Larger CIDR**: /24 provides room for Auto Scaling (up to ~250 instances per AZ)
- **Defense in Depth**: Protected by Security Groups + Network ACL

### What Goes Here?

✅ **Belongs in Private Subnets:**

- Flask backend instances (Auto Scaling Group)
- React frontend instances (Auto Scaling Group)

❌ **Should NOT be in Private Subnets:**

- Load Balancers
- NAT Gateways
- Any resource requiring direct internet access

**Note**: This application is stateless - no database or persistent storage is used. Backend forwards requests to Ollama, frontend uses localStorage only.

---

## Public Route Table

### Terraform Code

```terraform
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ollama_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ollama_igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
```

### Purpose

Defines how traffic is routed **from public subnets to the internet**.

### Configuration Choices

| Setting          | Value               | Why This Value?                              |
| ---------------- | ------------------- | -------------------------------------------- |
| `cidr_block`     | `0.0.0.0/0`         | All internet-bound traffic (catch-all route) |
| `gateway_id`     | Internet Gateway    | Routes traffic directly to internet          |
| **Associations** | Both public subnets | Applies same routing to both AZs             |

### Infrastructure Strategy

- **Direct Internet Access**: Public subnets can send/receive traffic directly via IGW
- **Simplicity**: One route table for all public subnets (consistent behavior)
- **ALB Communication**: Enables ALB to receive traffic from internet and send responses

### Route Table Logic

```
Traffic Destination: 0.0.0.0/0 (anywhere on the internet)
↓
Next Hop: Internet Gateway
↓
Result: Direct internet connectivity
```

### What Traffic Uses This?

- ALB health checks to internet endpoints
- ALB receiving HTTP/HTTPS requests from users
- NAT Gateway routing outbound traffic from private subnets
- Responses from ALB back to users

---

## NAT Gateways

### Terraform Code

```terraform
# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_1" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-1"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.ollama_igw]
}

resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name        = "${var.project_name}-nat-gw-1"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.ollama_igw]
}

# (Similar configuration for nat_gw_2)
```

### Purpose

Enable instances in **private subnets** to initiate outbound internet connections (without allowing inbound connections).

### Configuration Choices

| Setting        | Value            | Why This Value?                                              |
| -------------- | ---------------- | ------------------------------------------------------------ |
| **Elastic IP** | `domain = "vpc"` | Static public IP for consistent outbound traffic source      |
| `subnet_id`    | Public subnets   | NAT Gateway must be in public subnet with IGW access         |
| **Quantity**   | 2 (one per AZ)   | High availability - if one AZ fails, other continues working |
| `depends_on`   | Internet Gateway | Ensures IGW exists before creating NAT Gateway               |

### Infrastructure Strategy

- **Security**: Private instances never exposed directly to internet
- **Outbound Only**: Private instances can download updates, pull Docker images, call external APIs
- **High Availability**: Each AZ has its own NAT Gateway (no cross-AZ dependency)
- **Cost Optimization**: Charged per hour + data processed (design minimizes cross-AZ traffic)

### Traffic Flow

```
Private Instance → Private Route Table → NAT Gateway (in same AZ) → Internet Gateway → Internet
```

### What Uses NAT Gateway?

✅ **Typical Uses:**

- `apt-get update` / `yum update` on instances
- Backend calling external APIs (Ollama service, AWS services)
- Frontend build processes pulling dependencies
- AWS Systems Manager agent communicating with SSM endpoints
- Auto Scaling health checks to external endpoints

❌ **Does NOT Use NAT Gateway:**

- Inbound requests (blocked - security feature)
- Traffic between subnets within VPC
- Traffic from public subnets (use IGW directly)

### Why Two NAT Gateways?

**Single NAT Gateway (NOT recommended):**

```
Cost: ~$32/month
Risk: Single point of failure - if AZ goes down, ALL private instances lose internet
```

**Two NAT Gateways (our design):**

```
Cost: ~$64/month
Benefit: If AZ1 fails, instances in AZ2 continue functioning independently
```

---

## Private Route Tables

### Terraform Code

```terraform
resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.ollama_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt-1"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.ollama_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt-2"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}
```

### Purpose

Route outbound traffic from private subnets **through NAT Gateways** in the same Availability Zone.

### Configuration Choices

| Setting                   | Value                      | Why This Value?                            |
| ------------------------- | -------------------------- | ------------------------------------------ |
| `cidr_block`              | `0.0.0.0/0`                | All internet-bound traffic                 |
| `nat_gateway_id`          | NAT Gateway in **same AZ** | Avoids cross-AZ data transfer charges      |
| **Separate Route Tables** | One per AZ                 | Each AZ routes through its own NAT Gateway |

### Infrastructure Strategy

- **AZ Independence**: Each private subnet routes through NAT Gateway in same AZ
- **Cost Optimization**: Eliminates cross-AZ data transfer fees (~$0.01/GB)
- **High Availability**: If NAT Gateway 1 fails, subnet 2 unaffected
- **Simplified Troubleshooting**: Clear AZ-specific traffic paths

### Route Table Logic

**Private Route Table 1 (AZ1):**

```
Private Subnet 1 (AZ1)
↓
NAT Gateway 1 (AZ1) in Public Subnet 1
↓
Internet Gateway
↓
Internet
```

**Private Route Table 2 (AZ2):**

```
Private Subnet 2 (AZ2)
↓
NAT Gateway 2 (AZ2) in Public Subnet 2
↓
Internet Gateway
↓
Internet
```

### Why Separate Route Tables?

**Alternative (Shared Route Table):**

```
Problem: Both private subnets route through NAT Gateway in AZ1
Issue: If AZ1 fails, instances in AZ2 lose internet access even though AZ2 is healthy
Cross-AZ Cost: Data from AZ2 → NAT GW in AZ1 = $0.01/GB
```

**Our Design (Separate Route Tables):**

```
Benefit: Each private subnet routes through NAT Gateway in its own AZ
Resilience: If AZ1 fails, AZ2 continues working independently
Cost Savings: No cross-AZ data transfer
```

---

## Network ACL

### Terraform Code

```terraform
resource "aws_network_acl" "backend_nacl" {
  vpc_id     = aws_vpc.ollama_vpc.id
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  # Allow inbound backend traffic from ALB
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 8000
    to_port    = 8000
  }

  # Allow inbound frontend traffic from ALB
  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 3000
    to_port    = 3000
  }

  # Allow inbound ephemeral ports (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow HTTPS for SSM Session Manager
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${var.project_name}-backend-nacl"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

### Purpose

Provides a **subnet-level firewall** as an additional security layer beyond Security Groups.

### Configuration Choices

#### Ingress Rules 100-101: Application Traffic

**Rule 100: Backend Traffic**

| Setting               | Value                        | Why This Value?                          |
| --------------------- | ---------------------------- | ---------------------------------------- |
| `rule_no`             | `100`                        | Lower numbers = higher priority          |
| `protocol`            | `tcp`                        | HTTP traffic uses TCP                    |
| `from_port / to_port` | `8000`                       | Flask backend port                       |
| `cidr_block`          | `var.vpc_cidr` (10.0.0.0/16) | Only allow traffic from within VPC (ALB) |
| `action`              | `allow`                      | Permit this traffic                      |

**Rule 101: Frontend Traffic**

| Setting               | Value                        | Why This Value?                          |
| --------------------- | ---------------------------- | ---------------------------------------- |
| `rule_no`             | `101`                        | Second priority                          |
| `protocol`            | `tcp`                        | HTTP traffic uses TCP                    |
| `from_port / to_port` | `3000`                       | React frontend port (Vite dev server)    |
| `cidr_block`          | `var.vpc_cidr` (10.0.0.0/16) | Only allow traffic from within VPC (ALB) |
| `action`              | `allow`                      | Permit this traffic                      |

**Why `var.vpc_cidr`?**

- Restricts access to traffic originating from ALB (in public subnets)
- Blocks any external port 8000/3000 traffic (even if Security Group misconfigured)

#### Ingress Rule 110: Ephemeral Ports (Return Traffic)

| Setting               | Value        | Why This Value?                      |
| --------------------- | ------------ | ------------------------------------ |
| `rule_no`             | `110`        | Second priority                      |
| `protocol`            | `tcp`        | Response traffic uses TCP            |
| `from_port / to_port` | `1024-65535` | Ephemeral port range used by clients |
| `cidr_block`          | `0.0.0.0/0`  | Allow return traffic from any source |
| `action`              | `allow`      | Permit return traffic                |

**Why Ephemeral Ports?**

```
Example Flow:
1. Backend instance calls api.openai.com:443
2. Backend uses source port 54321 (random ephemeral port)
3. OpenAI responds to Backend:54321
4. Rule 110 allows this response traffic on port 54321
```

Without this rule, all outbound connections would fail because responses couldn't return.

#### Ingress Rule 120: SSM Session Manager Access

| Setting               | Value       | Why This Value?                          |
| --------------------- | ----------- | ---------------------------------------- |
| `rule_no`             | `120`       | Fourth priority                          |
| `protocol`            | `tcp`       | HTTPS uses TCP                           |
| `from_port / to_port` | `443`       | HTTPS port for SSM agent communication   |
| `cidr_block`          | `0.0.0.0/0` | SSM endpoints accessed via NAT Gateway   |
| `action`              | `allow`     | Permit SSM Session Manager communication |

**Why HTTPS/443?**

- AWS Systems Manager Session Manager uses HTTPS to establish secure sessions
- No SSH keys required - IAM-based authentication
- More secure than SSH (encrypted via TLS, logged to CloudTrail)
- Instances communicate with SSM endpoints over HTTPS

#### Egress Rule 100: All Outbound

| Setting      | Value       | Why This Value?           |
| ------------ | ----------- | ------------------------- |
| `rule_no`    | `100`       | Only outbound rule needed |
| `protocol`   | `-1` (all)  | Allow all protocols       |
| `cidr_block` | `0.0.0.0/0` | To any destination        |
| `action`     | `allow`     | Permit all outbound       |

**Why Allow All Outbound?**

- Backend needs to call external APIs (Ollama, AWS services)
- Instances need to download updates
- Outbound traffic is generally lower risk (initiated by trusted instances)
- Security Groups provide granular outbound control if needed

### Infrastructure Strategy

- **Defense in Depth**: Adds layer beyond Security Groups
- **Subnet-Level Protection**: Applies to ALL instances in private subnets automatically
- **Stateless**: Unlike Security Groups, must explicitly allow return traffic
- **Compliance**: Meets regulatory requirements for network segmentation

### Network ACL vs Security Group

| Feature        | Network ACL                            | Security Group                        |
| -------------- | -------------------------------------- | ------------------------------------- |
| **Scope**      | Subnet level                           | Instance level                        |
| **State**      | Stateless (need explicit return rules) | Stateful (auto-allows return traffic) |
| **Rule Type**  | Allow and Deny                         | Allow only                            |
| **Rule Order** | Processed in order (rule number)       | All rules evaluated                   |
| **Use Case**   | Broad subnet protection                | Granular instance control             |

**Defense in Depth Strategy:**

```
Internet → ALB Security Group → Private Instances Security Group → Network ACL → Instance
         (Layer 1)            (Layer 2)                        (Layer 3)
```

### Why Not DENY Rules?

This NACL only has ALLOW rules. Implicit DENY means anything not explicitly allowed is blocked.

**If you wanted to block specific traffic:**

```terraform
# Example: Block port 3306 (MySQL) from internet
ingress {
  rule_no    = 50
  protocol   = "tcp"
  action     = "deny"
  cidr_block = "0.0.0.0/0"
  from_port  = 3306
  to_port    = 3306
}
```

Lower rule numbers are processed first, so DENY at 50 would block before ALLOW at 100.

---

## Network Architecture Diagram

### High-Level Network Flow

```
                                  Internet
                                     │
                         ┌───────────┴────────────┐
                         │   Internet Gateway     │
                         └───────────┬────────────┘
                                     │
              ┌──────────────────────┴───────────────────────┐
              │                                               │
    ┌─────────▼─────────┐                         ┌─────────▼─────────┐
    │  Public Subnet 1  │                         │  Public Subnet 2  │
    │   (10.0.1.0/24)   │                         │   (10.0.2.0/24)   │
    │      AZ-1         │                         │      AZ-2         │
    ├───────────────────┤                         ├───────────────────┤
    │  NAT Gateway 1    │                         │  NAT Gateway 2    │
    │  ALB (part 1)     │                         │  ALB (part 2)     │
    └─────────┬─────────┘                         └─────────┬─────────┘
              │                                               │
              │         Application Load Balancer             │
              │          (spans both subnets)                 │
              └──────────────────┬────────────────────────────┘
                                 │
                   ┌─────────────┴──────────────┐
                   │     Route: /api/* → Backend│
                   │     Route: /* → Frontend   │
                   └─────────────┬──────────────┘
                                 │
              ┌──────────────────┴───────────────────────┐
              │                                           │
    ┌─────────▼─────────┐                     ┌─────────▼─────────┐
    │ Private Subnet 1  │                     │ Private Subnet 2  │
    │  (10.0.11.0/24)   │                     │  (10.0.12.0/24)   │
    │      AZ-1         │                     │      AZ-2         │
    ├───────────────────┤                     ├───────────────────┤
    │ Backend ASG       │                     │ Backend ASG       │
    │ (2-4 instances)   │                     │ (2-4 instances)   │
    │                   │                     │                   │
    │ Frontend ASG      │                     │ Frontend ASG      │
    │ (2-4 instances)   │                     │ (2-4 instances)   │
    └───────────────────┘                     └───────────────────┘
              │                                           │
              └────────────┐                 ┌───────────┘
                           │                 │
                           ▼                 ▼
                  Outbound via NAT Gateway in same AZ
```

### IP Address Allocation

```
VPC CIDR: 10.0.0.0/16 (65,536 IPs)
│
├── Public Subnet 1 (AZ-1):  10.0.1.0/24   (256 IPs)
├── Public Subnet 2 (AZ-2):  10.0.2.0/24   (256 IPs)
│
├── Private Subnet 1 (AZ-1): 10.0.11.0/24  (256 IPs)
├── Private Subnet 2 (AZ-2): 10.0.12.0/24  (256 IPs)
│
└── Future Expansion: 10.0.0.0 - 10.0.255.255
    (Reserved for databases, cache, etc.)
```

### Traffic Flow Examples

#### Inbound HTTP Request

```
User (Internet)
↓
[Security Layer 1] ALB Security Group (allow 80/443)
↓
Application Load Balancer
↓
Path Routing: /api/* vs /*
↓
[Security Layer 2] Backend/Frontend Security Groups (allow 8000/3000 from ALB)
↓
[Security Layer 3] Network ACL (allow from VPC CIDR)
↓
Backend or Frontend Instance (Private Subnet)
```

#### Outbound API Call

```
Backend Instance (Private Subnet)
↓
Private Route Table
↓
NAT Gateway (in same AZ's public subnet)
↓
Internet Gateway
↓
External API (e.g., api.openai.com)
```

---

## Design Decisions

### 1. Why Multi-AZ Deployment?

**Decision**: Deploy across 2 Availability Zones

**Rationale**:

- **High Availability**: AWS AZs are physically separate data centers. If one fails (power, cooling, network), the other continues serving traffic
- **ALB Requirement**: ALB requires at least 2 subnets in different AZs
- **Auto Scaling**: Instances can be distributed across AZs for balanced load
- **Cost**: Minimal additional cost (just extra NAT Gateway ~$32/month)

**Alternative Considered**: Single AZ

- **Cost Savings**: One NAT Gateway instead of two
- **Risk**: Complete service outage if AZ fails
- **Verdict**: ❌ Rejected - availability worth the cost

---

### 2. Why Public + Private Subnet Architecture?

**Decision**: Separate public and private subnets

**Rationale**:

- **Security Best Practice**: Application instances have no direct internet access
- **Attack Surface Reduction**: Attackers can't directly target backend instances
- **Compliance**: Meets PCI-DSS, HIPAA requirements for network segmentation
- **Flexibility**: Can add database subnet tier later

**Alternative Considered**: All instances in public subnets

- **Simpler**: No NAT Gateways needed, easier routing
- **Security Risk**: Every instance exposed to internet
- **Verdict**: ❌ Rejected - security is paramount

---

### 3. Why /24 Subnet Size?

**Decision**: Use /24 CIDR blocks (256 IPs each)

**Rationale**:

- **Public Subnets**: Only need ALB + NAT Gateway (~10 IPs). /24 provides plenty of room
- **Private Subnets**: Auto Scaling can grow to ~250 instances per AZ before exhaustion
- **AWS Reserved**: AWS reserves 5 IPs per subnet (.0, .1, .2, .3, .255)
- **Simplicity**: Easy to remember and troubleshoot (10.0.1.x, 10.0.2.x, etc.)

**Alternative Considered**: /26 (64 IPs) or /27 (32 IPs)

- **Cost Savings**: More efficient IP usage
- **Limitation**: May need to resize subnets as app scales
- **Verdict**: ❌ Rejected - /24 provides comfortable growth room

---

### 4. Why 10.0.0.0/16 VPC CIDR?

**Decision**: Use 10.0.0.0/16 (private IP range)

**Rationale**:

- **RFC 1918 Compliance**: Private address space (10.0.0.0 - 10.255.255.255)
- **Growth Room**: 65,536 IPs allows for many more subnets (databases, caches, etc.)
- **VPN Compatibility**: Doesn't conflict with common home/office networks (192.168.x.x)
- **AWS Best Practice**: Commonly used VPC size

**Alternative Considered**: 172.16.0.0/16

- **Also Private**: Valid RFC 1918 range
- **Conflict Risk**: Some corporate VPNs use 172.16.x.x
- **Verdict**: ✅ 10.0.0.0/16 is safer choice

---

### 5. Why Network ACL on Private Subnets Only?

**Decision**: Apply custom NACL only to private subnets (backend)

**Rationale**:

- **Layered Security**: Private subnets already protected by Security Groups; NACL adds second layer
- **Compliance**: Demonstrates defense-in-depth for audits
- **Public Subnet**: ALB already heavily controlled by Security Groups
- **Maintenance**: Fewer NACLs = simpler troubleshooting

**Alternative Considered**: NACLs on all subnets

- **More Secure**: Extra layer everywhere
- **Complexity**: Stateless rules are tricky; easy to break connectivity
- **Verdict**: ⚖️ Current approach balances security and simplicity

---

### 6. Why Separate NAT Gateways?

**Decision**: One NAT Gateway per Availability Zone

**Rationale**:

- **High Availability**: If NAT Gateway 1 fails, AZ2 continues working
- **No Cross-AZ Dependency**: Each AZ is fully independent
- **Cost Optimization**: Eliminates cross-AZ data transfer fees
- **Failure Domain Isolation**: Fault in AZ1 doesn't affect AZ2

**Alternative Considered**: Single NAT Gateway

- **Cost Savings**: ~$32/month vs ~$64/month
- **Risk**: Single point of failure for all private instances
- **Cross-AZ Cost**: Data transfer from AZ2 → NAT in AZ1 = $0.01/GB
- **Verdict**: ❌ Rejected - availability and cross-AZ costs justify dual NAT

**Cost Analysis:**

```
Single NAT Gateway:
  NAT Gateway: $32/month
  Cross-AZ Transfer: $0.01/GB × estimated 500 GB = $5/month
  Total: $37/month
  Risk: Complete outage if AZ fails

Dual NAT Gateways:
  NAT Gateways: $64/month
  Cross-AZ Transfer: $0/month
  Total: $64/month
  Benefit: Independent AZ operation

Premium for HA: $27/month (~$324/year)
```

---

### 7. Why Enable DNS Hostnames in VPC?

**Decision**: `enable_dns_hostnames = true`

**Rationale**:

- **Service Discovery**: Instances can reference each other by DNS names
- **ALB Integration**: ALB gets friendly DNS name (xxx.elb.amazonaws.com)
- **SSM Integration**: Systems Manager uses DNS for endpoint communication
- **CloudWatch**: Easier to identify instances in logs

**Alternative Considered**: Use IPs only

- **Simpler**: No DNS complexity
- **Brittle**: IP addresses change when instances replace
- **Verdict**: ❌ Rejected - DNS is essential for dynamic infrastructure

---

### 8. Why Systems Manager Instead of SSH?

**Decision**: Use AWS Systems Manager Session Manager for instance access

**Rationale**:

- **No Key Management**: Eliminates SSH key pair creation, storage, and rotation
- **IAM-Based Access**: Uses IAM policies for authentication/authorization
- **Audit Trail**: All sessions logged to CloudTrail automatically
- **No Bastion Hosts**: Saves cost and eliminates another security surface
- **Encrypted**: Sessions encrypted via TLS
- **Port 443 Only**: Works through firewalls (no port 22 needed)

**Alternative Considered**: SSH with Bastion Host

- **Traditional**: Well-understood by most engineers
- **Key Management**: Requires distributing, rotating, and securing SSH keys
- **Cost**: Requires bastion host instance (~$15-30/month)
- **Security**: Another server to patch and monitor
- **Verdict**: ❌ Rejected - SSM is more secure and simpler

---

## Summary: Overall Infrastructure Strategy

### Security Layers (Defense in Depth)

```
Layer 1: Internet Gateway + ALB Security Group
         ↓ (Filters internet traffic)
Layer 2: Private Subnets (No public IPs)
         ↓
Layer 3: Instance Security Groups (ALB-only access)
         ↓
Layer 4: Network ACL (Subnet-level firewall)
         ↓
Layer 5: Application (Authentication, authorization)
```

### High Availability Design

| Component          | HA Strategy              | Failure Impact                   |
| ------------------ | ------------------------ | -------------------------------- |
| VPC                | AWS-managed, multi-AZ    | None (AWS handles)               |
| Internet Gateway   | AWS-managed, redundant   | None (AWS handles)               |
| NAT Gateways       | 2× (one per AZ)          | Single AZ loses outbound only    |
| ALB                | Spans 2 AZs              | Seamless failover                |
| Backend Instances  | ASG across 2 AZs (min 2) | Auto-scales to maintain capacity |
| Frontend Instances | ASG across 2 AZs (min 2) | Auto-scales to maintain capacity |

### Cost Optimization

| Resource      | Monthly Cost | Optimization                               |
| ------------- | ------------ | ------------------------------------------ |
| NAT Gateways  | $64          | Necessary for HA; avoid cross-AZ traffic   |
| Elastic IPs   | $3.60        | Minimal; required for NAT Gateways         |
| Data Transfer | Variable     | Private subnets reduce internet egress     |
| CloudWatch    | ~$10         | Essential monitoring; set retention limits |

**Total Estimated Networking Cost**: ~$80-100/month

### Scalability

| Resource        | Current       | Max Growth     | Notes                        |
| --------------- | ------------- | -------------- | ---------------------------- |
| VPC CIDR        | 65,536 IPs    | No limit       | Can add more subnets         |
| Public Subnets  | 512 IPs total | ~500 usable    | More than enough for ALB/NAT |
| Private Subnets | 512 IPs total | ~500 instances | Can add subnets if needed    |
| NAT Gateway     | 45 Gbps each  | AWS scales     | Handles massive traffic      |
| IGW             | Unlimited     | AWS scales     | No throughput limit          |

---

## Next Steps

Now that networking is established, the next infrastructure components are:

1. **Security Groups** - Instance-level firewalls ([link to security-groups.md])
2. **Application Load Balancer** - Traffic distribution ([link to alb.md])
3. **Auto Scaling Groups** - Instance management ([link to asg.md])
4. **IAM Roles** - Permissions and access control ([link to iam.md])

---

## Troubleshooting

### Instance Can't Reach Internet

**Check:**

1. Instance in private subnet? → Must use NAT Gateway
2. Route table has route to NAT Gateway? → `0.0.0.0/0 → nat-xxx`
3. NAT Gateway in same AZ? → Check subnet-to-NAT mapping
4. Security Group allows outbound? → Check egress rules
5. Network ACL allows ephemeral ports? → Rule 110 allows 1024-65535

### Can't Connect via Session Manager

**Check:**

1. Instance has IAM role? → Check `AmazonSSMManagedInstanceCore` policy attached
2. Security Group allows HTTPS outbound? → Port 443 to 0.0.0.0/0
3. Network ACL allows HTTPS? → Rule 120 allows port 443
4. NAT Gateway working? → Instance needs internet to reach SSM endpoints
5. SSM agent installed? → Pre-installed on Amazon Linux 2, Ubuntu 16.04+
6. IAM permissions? → Your user needs `ssm:StartSession` permission

### ALB Can't Reach Backend

**Check:**

1. ALB in public subnets? → Check ALB subnet configuration
2. Backend in private subnets? → Target group registration
3. Security Groups allow traffic? → ALB SG → Backend SG
4. Network ACL allows port 8000? → Rule 100 allows from VPC
5. Health check passing? → Check `/health` endpoint

---

**Last Updated**: November 26, 2025
**Terraform Version**: >= 1.0
**AWS Provider Version**: ~> 5.0
**Architecture**: Simplified auto-scaling only (no storage, no single-instance mode)
