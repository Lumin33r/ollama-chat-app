#!/bin/bash
set -e

# Log all output to a file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Frontend Instance Setup ==="
echo "Project: ${project_name}"
echo "Git Repo: ${git_repo_url}"

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
    git

# Install Docker
echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
echo "=== Installing Docker Compose ==="
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js (for building frontend)
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

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

# Build and start frontend service with Docker Compose
echo "=== Starting frontend service ==="
cd /home/ubuntu/app
docker-compose up -d frontend

echo "=== Frontend Instance Setup Complete ==="
