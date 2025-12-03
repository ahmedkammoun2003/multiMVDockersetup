#!/bin/bash

echo "🚀 Provisioning App Server 1..."
export DEBIAN_FRONTEND=noninteractive

# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker vagrant

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create project directory
mkdir -p /opt/microservices
cd /opt/microservices

# Copy service code
cp -r /home/vagrant/account-service ./

# Create Docker Compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  account-service:
    build: ./account-service
    ports:
      - "5000:5000"
    environment:
      - DB_HOST=db
      - DB_NAME=microservices
      - DB_USER=app_user
      - DB_PASSWORD=securepassword123
      - JWT_SECRET=microservices-secret-key-2024
      - HOSTNAME=app1
    networks:
      - microservices-net

networks:
  microservices-net:
    driver: bridge
EOF

# Build and start service
docker-compose up -d --build

echo "✅ App Server 1 provisioned with Account Service on port 5000"