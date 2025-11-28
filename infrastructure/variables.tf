variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
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
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c5f78ca5e1169a1a"
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
  description = "CIDR blocks allowed to SSH (kept for potential bastion host, not used in current config)"
  type        = list(string)
  default     = ["10.0.0.0/16"] # VPC CIDR only
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
