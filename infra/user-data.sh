#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Ollama Chat App deployment ==="
echo "Timestamp: $(date)"

# Update system
echo "=== Updating system ==="
apt-get update
apt-get upgrade -y

# Install dependencies
echo "=== Installing dependencies ==="
apt-get install -y \
    curl \
    git \
    unzip \
    jq \
    htop \
    docker.io \
    docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI
echo "=== Installing AWS CLI ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install CloudWatch agent
echo "=== Installing CloudWatch agent ==="
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Mount EBS volume for Ollama models
echo "=== Mounting EBS volume ==="
while [ ! -e /dev/nvme1n1 ]; do
    echo "Waiting for EBS volume..."
    sleep 5
done

# Format if not already formatted
if ! blkid /dev/nvme1n1; then
    mkfs -t ext4 /dev/nvme1n1
fi

mkdir -p /mnt/ollama-models
mount /dev/nvme1n1 /mnt/ollama-models

# Add to fstab for auto-mount on reboot
UUID=$(blkid -s UUID -o value /dev/nvme1n1)
echo "UUID=$UUID /mnt/ollama-models ext4 defaults,nofail 0 2" >> /etc/fstab

# Set permissions
chown -R ubuntu:ubuntu /mnt/ollama-models

# Clone repository
echo "=== Cloning repository ==="
cd /home/ubuntu
sudo -u ubuntu git clone ${git_repo_url} || echo "Repository already exists"
cd ${project_name}

# Remove obsolete version lines
sed -i '/^version:/d' docker-compose.yml
sed -i '/^version:/d' docker-compose.prod.yml 2>/dev/null || true

# Update docker-compose to use mounted volume
sed -i 's|ollama-models:/root/.ollama|/mnt/ollama-models:/root/.ollama|g' docker-compose.prod.yml

# Build and start containers
echo "=== Building containers ==="
sudo -u ubuntu docker compose -f docker-compose.yml -f docker-compose.prod.yml build

echo "=== Starting containers ==="
sudo -u ubuntu docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Wait for Ollama service to be ready
echo "=== Waiting for Ollama service ==="
sleep 30

# Pull Ollama model
echo "=== Pulling Ollama model: ${ollama_model} ==="
sudo -u ubuntu docker compose -f docker-compose.yml -f docker-compose.prod.yml exec -T ollama-service ollama pull ${ollama_model} || echo "Model pull failed, will retry manually"

# Set up systemd service for auto-start
echo "=== Setting up systemd service ==="
cat > /etc/systemd/system/${project_name}.service << 'SYSTEMD_EOF'
[Unit]
Description=Ollama Chat App
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/${project_name}
ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml down
User=ubuntu

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

systemctl enable ${project_name}
systemctl start ${project_name}

# Install and configure Nginx
echo "=== Installing Nginx ==="
apt-get install -y nginx

# Configure Nginx
cat > /etc/nginx/sites-available/${project_name} << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/${project_name} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

# Set up log rotation
cat > /etc/logrotate.d/${project_name} << 'LOGROTATE_EOF'
/var/log/user-data.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
}
LOGROTATE_EOF

echo "=== Deployment complete! ==="
echo "Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Backend API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
