#!/bin/bash

echo "🚀 Provisioning Bastion Host..."
export DEBIAN_FRONTEND=noninteractive

# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io postgresql-client
usermod -aG docker vagrant

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create project directory
mkdir -p /opt/microservices
cd /opt/microservices

# Copy service code
cp -r /home/vagrant/services/auth-service ./auth-service
cp -r /home/vagrant/services/account-service ./account-service
cp -r /home/vagrant/services/transaction-service ./transaction-service

# Create Docker Compose file for bastion services
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  auth-service:
    build: ./auth-service
    ports:
      - "5002:5002"
    environment:
      - JWT_SECRET=microservices-secret-key-2024
      - HOSTNAME=bastion
    networks:
      - microservices-net

  nginx-gateway:
    image: nginx:alpine
    ports:
      - "8080:8080"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    networks:
      - microservices-net
    depends_on:
      - auth-service

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - microservices-net

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SECURITY_ADMIN_USER=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana-provisioning:/etc/grafana/provisioning
    networks:
      - microservices-net
    depends_on:
      - prometheus

volumes:
  grafana-storage:

networks:
  microservices-net:
    driver: bridge
EOF

# Create Nginx configuration
cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream auth_service {
        server auth-service:5002;
    }

    upstream account_service {
        server 192.168.56.11:5000;
    }

    upstream transaction_service {
        server 192.168.56.12:5001;
    }

    upstream prometheus {
        server prometheus:9090;
    }

    server {
        listen 8080;
        
        # Auth service routes
        location /auth/ {
            proxy_pass http://auth_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Account service routes
        location /accounts {
            proxy_pass http://account_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Authorization $http_authorization;
        }

        # Transaction service routes  
        location /transactions {
            proxy_pass http://transaction_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Authorization $http_authorization;
        }

        # Health checks
        location /health {
            proxy_pass http://account_service/health;
        }

        # Prometheus metrics
        location /prometheus/ {
            proxy_pass http://prometheus/;
            proxy_set_header Host $host;
        }
    }
}
EOF

# Create Prometheus configuration
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'microservices-cluster'
    environment: 'production'

scrape_configs:
  - job_name: 'auth-service'
    static_configs:
      - targets: ['auth-service:5002']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'account-service'
    static_configs:
      - targets: ['192.168.56.11:5000']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'transaction-service'
    static_configs:
      - targets: ['192.168.56.12:5001']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: /metrics

  - job_name: 'nginx-gateway'
    static_configs:
      - targets: ['nginx-gateway:8080']
    metrics_path: /metrics
    scrape_interval: 15s

  - job_name: 'node-exporter-bastion'
    static_configs:
      - targets: ['192.168.56.10:9100']
    scrape_interval: 30s

  - job_name: 'node-exporter-app1'
    static_configs:
      - targets: ['192.168.56.11:9100']
    scrape_interval: 30s

  - job_name: 'node-exporter-app2'
    static_configs:
      - targets: ['192.168.56.12:9100']
    scrape_interval: 30s

  - job_name: 'node-exporter-db'
    static_configs:
      - targets: ['192.168.56.20:9100']
    scrape_interval: 30s

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['192.168.56.20:9187']
    scrape_interval: 30s
EOF

# Create Grafana provisioning directories
mkdir -p grafana-provisioning/datasources
mkdir -p grafana-provisioning/dashboards

# Create Grafana datasource configuration
cat > grafana-provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: "5s"
EOF

# Create Grafana dashboard provider configuration
cat > grafana-provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Microservices Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Copy dashboard JSON
cp /home/vagrant/scripts/grafana-dashboard.json grafana-provisioning/dashboards/ 2>/dev/null || echo "Dashboard file will be added later"


# Build and start services
docker-compose up -d --build

echo "✅ Bastion host provisioned with:"
echo "   - Auth Service on port 5002"
echo "   - API Gateway on port 8080"
echo "   - Prometheus on port 9090"
echo "   - Grafana on port 3000"