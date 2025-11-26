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
  value       = var.enable_auto_scaling ? aws_autoscaling_group.backend_asg[0].name : "Auto Scaling disabled"
}

output "frontend_asg_name" {
  description = "The name of the frontend Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.frontend_asg[0].name : "Auto Scaling disabled"
}

output "backend_asg_arn" {
  description = "The ARN of the backend Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.backend_asg[0].arn : null
}

output "frontend_asg_arn" {
  description = "The ARN of the frontend Auto Scaling Group"
  value       = var.enable_auto_scaling ? aws_autoscaling_group.frontend_asg[0].arn : null
}

# ========================================
# EC2 Instance Outputs (Single-Instance Mode)
# ========================================

output "ec2_instance_id" {
  description = "The ID of the EC2 instance (single-instance mode)"
  value       = aws_instance.ollama_app.id
}

output "ec2_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_eip.ollama_eip.public_ip
}

output "ec2_private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.ollama_app.private_ip
}

output "ec2_public_dns" {
  description = "The public DNS of the EC2 instance"
  value       = aws_instance.ollama_app.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ~/.ssh/${var.project_name}-key ubuntu@${aws_eip.ollama_eip.public_ip}"
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

output "single_instance_security_group_id" {
  description = "The ID of the single-instance security group"
  value       = aws_security_group.ollama_sg.id
}

# ========================================
# IAM Outputs
# ========================================

output "ec2_iam_role_arn" {
  description = "The ARN of the EC2 IAM role"
  value       = aws_iam_role.ollama_ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "The name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ollama_profile.name
}

# ========================================
# CloudWatch Outputs
# ========================================

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ollama_logs.name
}

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

    SINGLE EC2 INSTANCE (Development/Testing):
    ------------------------------------------
    SSH Command:         ssh -i ~/.ssh/${var.project_name}-key ubuntu@${aws_eip.ollama_eip.public_ip}
    Instance ID:         ${aws_instance.ollama_app.id}
    Public IP:           ${aws_eip.ollama_eip.public_ip}

    AUTO SCALING CONFIGURATION:
    ---------------------------
    Backend ASG:         ${var.enable_auto_scaling ? aws_autoscaling_group.backend_asg[0].name : "Disabled"}
      Min: ${var.backend_min_size}, Max: ${var.backend_max_size}, Desired: ${var.backend_desired_capacity}

    Frontend ASG:        ${var.enable_auto_scaling ? aws_autoscaling_group.frontend_asg[0].name : "Disabled"}
      Min: ${var.frontend_min_size}, Max: ${var.frontend_max_size}, Desired: ${var.frontend_desired_capacity}

    MONITORING & LOGGING:
    ---------------------
    CloudWatch Logs:     ${aws_cloudwatch_log_group.ollama_logs.name}
    View Logs:           aws logs tail ${aws_cloudwatch_log_group.ollama_logs.name} --follow

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
    3. Review security group rules and restrict SSH access
    4. Set up CloudWatch alarms and dashboards
    5. Configure application secrets and environment variables
    6. Test health checks and auto-scaling policies

    ========================================
  EOT
}
