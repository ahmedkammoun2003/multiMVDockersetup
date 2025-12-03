#!/bin/bash

echo "🏥 Health Check for All Services..."

echo "1. Bastion Services:"
curl -s http://192.168.70.10:5002/health | jq .

echo ""
echo "2. App Server 1 (Account Service):"
curl -s http://192.168.70.11:5000/health | jq .

echo ""
echo "3. App Server 2 (Transaction Service):"
curl -s http://192.168.70.12:5001/health | jq .

echo ""
echo "4. API Gateway:"
curl -s http://192.168.70.10:8080/health | jq .

echo ""
echo "5. Database Connection Test:"
# Test from app1
echo "From App1:"
vagrant ssh app1 -c "docker exec \$(docker ps -q -f name=account) python -c \"
import psycopg2
try:
    conn = psycopg2.connect(host='db', database='microservices', user='app_user', password='securepassword123')
    print('✅ Database connection successful from App1')
    conn.close()
except Exception as e:
    print('❌ Database connection failed:', str(e))
\""

echo ""
echo "✅ Health check completed"