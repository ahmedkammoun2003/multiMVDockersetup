#!/usr/bin/env bash


BASE_URL="http://localhost:8080"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_info() { echo -e "👉 $1"; }

# -----------------------------------------------------------------
# 1️⃣ Health Checks
# -----------------------------------------------------------------
log_info "Checking service health..."



for service in "auth" "accounts" "transactions"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$service/health")
  if [[ "$HTTP_CODE" == "200" ]]; then
    log_success "$service service is healthy"
  else
    log_fail "$service service health check failed (HTTP $HTTP_CODE)"
  fi
done

# -----------------------------------------------------------------
# 2️⃣ Authentication (Login)
# -----------------------------------------------------------------
log_info "Attempting login with user1..."

LOGIN_PAYLOAD='{"username":"user1", "password":"password1"}'
LOGIN_RESP=$(curl -s -X POST -H "Content-Type: application/json" -d "$LOGIN_PAYLOAD" "$BASE_URL/auth/login")

TOKEN=$(echo "$LOGIN_RESP" | jq -r .token)

if [[ "$TOKEN" != "null" && -n "$TOKEN" ]]; then
  log_success "Login successful. Token received."
else
  log_fail "Login failed. Response: $LOGIN_RESP"
fi

# -----------------------------------------------------------------
# 3️⃣ Account Service Tests
# -----------------------------------------------------------------
log_info "Testing Account Service..."

# GET /accounts
log_info "GET /accounts..."
ACCOUNTS_RESP=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/accounts")
if echo "$ACCOUNTS_RESP" | jq -e . >/dev/null 2>&1; then
  log_success "GET /accounts returned valid JSON"
else
  log_fail "GET /accounts failed. Response: $ACCOUNTS_RESP"
fi

# POST /accounts
NEW_ACC_NUM="ACC-$(date +%s)"
NEW_ACCOUNT_PAYLOAD=$(cat <<EOF
{
  "user_id": "user1",
  "account_number": "$NEW_ACC_NUM",
  "balance": 5000,
  "account_type": "savings"
}
EOF
)

log_info "Creating new account ($NEW_ACC_NUM)..."
CREATE_RESP=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$NEW_ACCOUNT_PAYLOAD" \
  "$BASE_URL/accounts")

if [[ "$CREATE_RESP" == *"HTTP_CODE:201"* ]]; then
  log_success "Account created successfully"
else
  log_fail "Failed to create account. Response: $CREATE_RESP"
fi

# Verify Account Existence
log_info "Verifying account existence..."
VERIFY_RESP=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/accounts")
if echo "$VERIFY_RESP" | grep -q "$NEW_ACC_NUM"; then
  log_success "New account found in list"
else
  log_fail "New account not found in list"
fi

# -----------------------------------------------------------------
# 4️⃣ Transaction Service Tests
# -----------------------------------------------------------------
log_info "Testing Transaction Service..."

log_info "GET /transactions/$NEW_ACC_NUM..."
TRANS_RESP=$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/transactions/$NEW_ACC_NUM")

if [[ "$TRANS_RESP" == *"HTTP_CODE:200"* ]]; then
  log_success "GET /transactions succeeded"
else
  log_fail "GET /transactions failed. Response: $TRANS_RESP"
fi

# -----------------------------------------------------------------
# 5️⃣ Prometheus Metrics Check
# -----------------------------------------------------------------
log_info "Checking Prometheus metrics..."
PROM_RESP=$(curl -s "$BASE_URL/../prometheus/api/v1/query?query=up")
if echo "$PROM_RESP" | jq -e '.data.result | length > 0' >/dev/null 2>&1; then
  log_success "Prometheus is scraping metrics"
else
  log_fail "Prometheus metrics check failed"
fi

# -----------------------------------------------------------------
# 6️⃣ Database Connectivity Test
# -----------------------------------------------------------------
log_info "Testing PostgreSQL connectivity..."
DB_CHECK=$(psql "host=192.168.56.20 dbname=microservices user=app_user password=securepassword123" -c "SELECT 1;" 2>/dev/null | grep -q "1" && echo "ok" || echo "fail")
if [[ "$DB_CHECK" == "ok" ]]; then
  log_success "Database connection successful"
else
  log_fail "Database connection failed"
fi

# -----------------------------------------------------------------
# 7️⃣ Security Checks (UFW & Fail2Ban)
# -----------------------------------------------------------------
log_info "Checking UFW firewall status..."
if sudo ufw status verbose 2>/dev/null | grep -qi "Status: active"; then
  log_success "UFW is active"
else
  log_fail "UFW is not active"
fi

log_info "Checking Fail2Ban status (Corrected Logic)..."
FAIL2BAN_STATUS_OUTPUT=$(echo "password123" | sudo -S fail2ban-client status 2>/dev/null )
if echo "$FAIL2BAN_STATUS_OUTPUT" | grep -q "Status" && echo "$FAIL2BAN_STATUS_OUTPUT" | grep -q "Jail list"; then
  log_success "Fail2Ban is running"
else
  log_fail "Fail2Ban is not running or failed to connect to the server."
fi


# -----------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------
echo ""
echo "🎉 All tests passed successfully! The microservices stack is fully operational."
