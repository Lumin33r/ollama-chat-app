variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ollama-chat-app"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0f00d706c4a80fd93"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge"
  # Options: t3.xlarge, g4dn.xlarge, g5.xlarge
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.0.12.0/24"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change to your IP for security
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
  # Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/ollama-key
  # Then: cat ~/.ssh/ollama-key.pub
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "ebs_volume_size" {
  description = "EBS volume size for Ollama models in GB"
  type        = number
  default     = 100
}

variable "git_repo_url" {
  description = "Git repository URL for the application"
  type        = string
  default     = "https://github.com/yourusername/ollama-chat-app.git"
}

variable "ollama_model" {
  description = "Ollama model to pull on startup"
  type        = string
  default     = "llama3.2:1b"
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_auto_scaling" {
  description = "Enable Auto Scaling Groups for backend and frontend"
  type        = bool
  default     = true
}

variable "backend_min_size" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 2
}

variable "backend_max_size" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 4
}

variable "backend_desired_capacity" {
  description = "Desired number of backend instances"
  type        = number
  default     = 2
}

variable "frontend_min_size" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 2
}

variable "frontend_max_size" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 4
}

variable "frontend_desired_capacity" {
  description = "Desired number of frontend instances"
  type        = number
  default     = 2
}

variable "backend_instance_type" {
  description = "Instance type for Flask backend"
  type        = string
  default     = "t3.medium"
}

variable "frontend_instance_type" {
  description = "Instance type for React frontend"
  type        = string
  default     = "t3.small"
}
