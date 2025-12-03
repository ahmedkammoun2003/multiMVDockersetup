#!/bin/bash

echo "🗄️ Setting up PostgreSQL database on $(hostname)..."
export DEBIAN_FRONTEND=noninteractive

# Install PostgreSQL
apt-get update
apt-get install -y postgresql postgresql-contrib

# Configure PostgreSQL
sudo -u postgres psql << EOF
-- Create database and user
CREATE DATABASE microservices;
CREATE USER app_user WITH PASSWORD 'securepassword123';
GRANT ALL PRIVILEGES ON DATABASE microservices TO app_user;

-- Configure PostgreSQL to listen on network
ALTER SYSTEM SET listen_addresses = '*';
EOF

# Configure client authentication
cat > /etc/postgresql/*/main/pg_hba.conf << 'EOF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    microservices   app_user        192.168.56.11/32        md5
host    microservices   app_user        192.168.56.12/32        md5
host    microservices   app_user        192.168.56.10/32        md5
host    all             all             192.168.56.0/24         reject
EOF

# Restart PostgreSQL
systemctl restart postgresql

# Create tables and sample data
sudo -u postgres psql -d microservices << EOF
-- Create accounts table
CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00,
    account_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    account_number VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample accounts
INSERT INTO accounts (user_id, account_number, balance, account_type) VALUES
('user1', 'ACC001', 1000.00, 'checking'),
('user1', 'ACC002', 5000.00, 'savings'),
('user2', 'ACC003', 2000.00, 'checking')
ON CONFLICT (account_number) DO NOTHING;

-- Insert sample transactions
INSERT INTO transactions (account_number, amount, transaction_type, description) VALUES
('ACC001', 100.00, 'deposit', 'Initial deposit'),
('ACC001', -50.00, 'withdrawal', 'ATM withdrawal'),
('ACC002', 1000.00, 'deposit', 'Salary deposit'),
('ACC003', 200.00, 'deposit', 'Transfer')
ON CONFLICT DO NOTHING;

-- Grant permissions to app_user
GRANT SELECT, INSERT, UPDATE ON accounts TO app_user;
GRANT SELECT, INSERT, UPDATE ON transactions TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;
EOF

echo "✅ PostgreSQL database setup completed"