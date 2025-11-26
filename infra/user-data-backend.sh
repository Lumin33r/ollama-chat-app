#!/bin/bash
set -e

# Log all output to a file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Backend Instance Setup ==="
echo "Project: ${project_name}"
echo "Git Repo: ${git_repo_url}"
echo "Ollama Model: ${ollama_model}"

# Update system packages
echo "=== Updating system packages ==="
apt-get update
apt-get upgrade -y

# Install dependencies
echo "=== Installing dependencies ==="
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    python3 \
    python3-pip \
    python3-venv

# Install Docker
echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
echo "=== Installing Docker Compose ==="
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch agent
echo "=== Installing CloudWatch agent ==="
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Clone application repository
echo "=== Cloning application repository ==="
cd /home/ubuntu
if [ ! -d "app" ]; then
    sudo -u ubuntu git clone ${git_repo_url} app
fi
cd app

# Install Ollama
echo "=== Installing Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
echo "=== Starting Ollama service ==="
systemctl enable ollama
systemctl start ollama

# Wait for Ollama to be ready
sleep 10

# Pull the specified model
echo "=== Pulling Ollama model: ${ollama_model} ==="
ollama pull ${ollama_model}

# Install Python dependencies
echo "=== Installing Python dependencies ==="
cd /home/ubuntu/app/backend
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
fi

# Start backend service with Docker Compose
echo "=== Starting backend service ==="
cd /home/ubuntu/app
docker-compose up -d backend

echo "=== Backend Instance Setup Complete ==="
