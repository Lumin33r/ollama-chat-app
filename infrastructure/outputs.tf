# ========================================
# VPC and Network Outputs
# ========================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.ollama_vpc.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.ollama_vpc.cidr_block
}

output "public_subnet_1_id" {
  description = "The ID of public subnet 1"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  description = "The ID of public subnet 2"
  value       = aws_subnet.public_subnet_2.id
}

output "private_subnet_1_id" {
  description = "The ID of private subnet 1"
  value       = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  description = "The ID of private subnet 2"
  value       = aws_subnet.private_subnet_2.id
}

output "nat_gateway_1_id" {
  description = "The ID of NAT Gateway 1"
  value       = aws_nat_gateway.nat_gw_1.id
}

output "nat_gateway_2_id" {
  description = "The ID of NAT Gateway 2"
  value       = aws_nat_gateway.nat_gw_2.id
}

output "backend_nacl_id" {
  description = "The ID of the backend Network ACL"
  value       = aws_network_acl.backend_nacl.id
}

# ========================================
# Application Load Balancer Outputs
# ========================================

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.app_lb.arn
}

output "alb_zone_id" {
  description = "The Zone ID of the Application Load Balancer"
  value       = aws_lb.app_lb.zone_id
}

output "application_url" {
  description = "The URL to access the application via ALB"
  value       = "http://${aws_lb.app_lb.dns_name}"
}

output "backend_api_url" {
  description = "The URL to access the backend API via ALB"
  value       = "http://${aws_lb.app_lb.dns_name}/api"
}

# ========================================
# Target Group Outputs
# ========================================

output "backend_target_group_arn" {
  description = "The ARN of the backend target group"
  value       = aws_lb_target_group.backend_tg.arn
}

output "frontend_target_group_arn" {
  description = "The ARN of the frontend target group"
  value       = aws_lb_target_group.frontend_tg.arn
}

# ========================================
# Auto Scaling Group Outputs
# ========================================

output "backend_asg_name" {
  description = "The name of the backend Auto Scaling Group"
  value       = aws_autoscaling_group.backend_asg.name
}

output "frontend_asg_name" {
  description = "The name of the frontend Auto Scaling Group"
  value       = aws_autoscaling_group.frontend_asg.name
}

output "backend_asg_arn" {
  description = "The ARN of the backend Auto Scaling Group"
  value       = aws_autoscaling_group.backend_asg.arn
}

output "frontend_asg_arn" {
  description = "The ARN of the frontend Auto Scaling Group"
  value       = aws_autoscaling_group.frontend_asg.arn
}

# ========================================
# Security Group Outputs
# ========================================

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "backend_security_group_id" {
  description = "The ID of the backend security group"
  value       = aws_security_group.backend_sg.id
}

output "frontend_security_group_id" {
  description = "The ID of the frontend security group"
  value       = aws_security_group.frontend_sg.id
}

# ========================================
# IAM Outputs
# ========================================

# IAM outputs removed - IAM resources not created due to insufficient permissions
# output "ec2_iam_role_arn" {
#   description = "The ARN of the EC2 IAM role"
#   value       = aws_iam_role.ollama_ec2_role.arn
# }

# output "ec2_instance_profile_name" {
#   description = "The name of the EC2 instance profile"
#   value       = aws_iam_instance_profile.ollama_profile.name
# }

# ========================================
# Deployment Instructions
# ========================================

output "deployment_instructions" {
  description = "Instructions for deploying and accessing the application"
  value       = <<-EOT

    ========================================
    Ollama Chat App - Deployment Summary
    ========================================

    APPLICATION ACCESS:
    -------------------
    Frontend URL:        http://${aws_lb.app_lb.dns_name}
    Backend API URL:     http://${aws_lb.app_lb.dns_name}/api
    Health Check:        http://${aws_lb.app_lb.dns_name}/health

    AUTO SCALING CONFIGURATION:
    ---------------------------
    Backend ASG:         ${aws_autoscaling_group.backend_asg.name}
      Min: ${var.backend_min_size}, Max: ${var.backend_max_size}, Desired: ${var.backend_desired_capacity}

    Frontend ASG:        ${aws_autoscaling_group.frontend_asg.name}
      Min: ${var.frontend_min_size}, Max: ${var.frontend_max_size}, Desired: ${var.frontend_desired_capacity}

    INSTANCE ACCESS:
    ----------------
    ⚠️  No IAM role configured - SSM Session Manager NOT available
    Access via SSH requires:
      1. Add key_name to launch templates
      2. Create bastion host in public subnet
      3. Configure security groups for SSH access (port 22)

    INFRASTRUCTURE DETAILS:
    -----------------------
    VPC ID:              ${aws_vpc.ollama_vpc.id}
    VPC CIDR:            ${aws_vpc.ollama_vpc.cidr_block}
    Public Subnets:      ${aws_subnet.public_subnet_1.id}, ${aws_subnet.public_subnet_2.id}
    Private Subnets:     ${aws_subnet.private_subnet_1.id}, ${aws_subnet.private_subnet_2.id}
    NAT Gateways:        ${aws_nat_gateway.nat_gw_1.id}, ${aws_nat_gateway.nat_gw_2.id}

    NEXT STEPS:
    -----------
    1. Update DNS records to point to ALB: ${aws_lb.app_lb.dns_name}
    2. Configure SSL/TLS certificate on ALB for HTTPS
    3. Set up CloudWatch alarms and dashboards
    4. Configure application secrets and environment variables
    5. Test health checks and auto-scaling policies
    6. Use Session Manager to access instances for troubleshooting

    ========================================
  EOT
}
