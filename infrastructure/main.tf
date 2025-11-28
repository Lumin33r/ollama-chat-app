terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC - Isolated network environment
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

# Internet Gateway
resource "aws_internet_gateway" "ollama_igw" {
  vpc_id = aws_vpc.ollama_vpc.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Public Subnets across multiple AZs (for ALB)
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

# Private Subnets across multiple AZs (for backend instances)
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

# Route Table for Public Subnet
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

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateways for Private Subnets (for outbound internet access)
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

resource "aws_eip" "nat_eip_2" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-2"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.ollama_igw]
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id

  tags = {
    Name        = "${var.project_name}-nat-gw-2"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.ollama_igw]
}

# Route Tables for Private Subnets
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

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}

# Network ACL for additional security layer on application instances
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
    rule_no    = 110
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 3000
    to_port    = 3000
  }

  # Allow inbound ephemeral ports (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow HTTPS outbound for Systems Manager
  ingress {
    protocol   = "tcp"
    rule_no    = 130
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

# Security Group for Application Load Balancer
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

# Security Group for Flask Backend Instances
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

# Security Group for React Frontend Instances
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

# ========================================
# IAM Roles and Policies
# ========================================

# NOTE: IAM resources removed due to insufficient IAM permissions
# User does not have iam:ListRolePolicies permission required by Terraform
#
# Trade-off: Instances will not have AWS Systems Manager Session Manager access
# Alternative: Use SSH key pairs for instance access if needed
#
# To re-enable SSM access, admin needs to:
# 1. Grant user iam:ListRolePolicies, iam:TagRole, iam:DeleteRole permissions
# 2. Uncomment IAM resources below
# 3. Uncomment iam_instance_profile blocks in launch templates

# resource "aws_iam_role" "ollama_ec2_role" {
#   name = "${var.project_name}-ec2-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "ssm_policy" {
#   role       = aws_iam_role.ollama_ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "ollama_profile" {
#   name = "${var.project_name}-instance-profile"
#   role = aws_iam_role.ollama_ec2_role.name
# }

# ========================================
# Application Load Balancer
# ========================================

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group for Flask Backend
resource "aws_lb_target_group" "backend_tg" {
  name     = "${var.project_name}-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ollama_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-backend-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group for React Frontend
resource "aws_lb_target_group" "frontend_tg" {
  name     = "${var.project_name}-frontend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ollama_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-frontend-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ALB Listener - HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }

  tags = {
    Name        = "${var.project_name}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ALB Listener Rule - Route /api/* to Backend
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/health"]
    }
  }

  tags = {
    Name        = "${var.project_name}-api-routing"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ========================================
# Launch Templates for Auto Scaling
# ========================================

# Launch Template for Flask Backend
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = var.ami_id
  instance_type = var.backend_instance_type

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # IAM instance profile removed - insufficient IAM permissions
  # Instances will not have SSM Session Manager access
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ollama_profile.name
  # }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-backend.sh", {
    project_name = var.project_name
    git_repo_url = var.git_repo_url
    ollama_model = var.ollama_model
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-backend-instance"
      Environment = var.environment
      Project     = var.project_name
      Tier        = "Backend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for React Frontend
resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "${var.project_name}-frontend-"
  image_id      = var.ami_id
  instance_type = var.frontend_instance_type

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  # IAM instance profile removed - insufficient IAM permissions
  # Instances will not have SSM Session Manager access
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ollama_profile.name
  # }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data-frontend.sh", {
    project_name = var.project_name
    git_repo_url = var.git_repo_url
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-frontend-instance"
      Environment = var.environment
      Project     = var.project_name
      Tier        = "Frontend"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# Auto Scaling Groups
# ========================================

# Auto Scaling Group for Flask Backend
resource "aws_autoscaling_group" "backend_asg" {
  name                      = "${var.project_name}-backend-asg"
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  target_group_arns         = [aws_lb_target_group.backend_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.backend_min_size
  max_size         = var.backend_max_size
  desired_capacity = var.backend_desired_capacity

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "Backend"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for React Frontend
resource "aws_autoscaling_group" "frontend_asg" {
  name                      = "${var.project_name}-frontend-asg"
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  target_group_arns         = [aws_lb_target_group.frontend_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.frontend_min_size
  max_size         = var.frontend_max_size
  desired_capacity = var.frontend_desired_capacity

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "Frontend"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# Auto Scaling Policies
# ========================================

# Auto Scaling Policies for Backend
resource "aws_autoscaling_policy" "backend_scale_up" {
  name                   = "${var.project_name}-backend-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}

resource "aws_autoscaling_policy" "backend_scale_down" {
  name                   = "${var.project_name}-backend-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}

# CloudWatch Alarms for Backend Scaling
resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors backend CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.backend_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_low" {
  alarm_name          = "${var.project_name}-backend-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors backend CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.backend_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }
}

# Auto Scaling Policies for Frontend
resource "aws_autoscaling_policy" "frontend_scale_up" {
  name                   = "${var.project_name}-frontend-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
}

resource "aws_autoscaling_policy" "frontend_scale_down" {
  name                   = "${var.project_name}-frontend-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
}

# CloudWatch Alarms for Frontend Scaling
resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "${var.project_name}-frontend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors frontend CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_low" {
  alarm_name          = "${var.project_name}-frontend-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors frontend CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.frontend_asg.name
  }
}
