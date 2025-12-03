#!/bin/bash

echo "🧪 Testing Microservices Deployment..."

# Get JWT token
echo "1. Getting authentication token..."
TOKEN_RESPONSE=$(curl -s -X POST http://192.168.70.10:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user1", "password": "password1"}')

echo "Auth response: $TOKEN_RESPONSE"

TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get token"
    exit 1
fi

echo "✅ Token obtained: ${TOKEN:0:50}..."

# Test Account Service
echo ""
echo "2. Testing Account Service..."
ACCOUNT_RESPONSE=$(curl -s -X GET http://192.168.70.10:8080/accounts \
  -H "Authorization: Bearer $TOKEN")

echo "Account Service response:"
echo $ACCOUNT_RESPONSE | jq .

# Test Transaction Service
echo ""
echo "3. Testing Transaction Service..."
TRANSACTION_RESPONSE=$(curl -s -X GET "http://192.168.70.10:8080/transactions/ACC001" \
  -H "Authorization: Bearer $TOKEN")

echo "Transaction Service response:"
echo $TRANSACTION_RESPONSE | jq .

# Test without token (should fail)
echo ""
echo "4. Testing without token (should fail)..."
UNAUTHORIZED_RESPONSE=$(curl -s -X GET http://192.168.70.10:8080/accounts)
echo "Unauthorized access response:"
echo $UNAUTHORIZED_RESPONSE | jq .

echo ""
echo "🎉 Microservices test completed!"