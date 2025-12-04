from flask import Flask, jsonify, request
import jwt
import psycopg2
import os
from functools import wraps
import logging
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'db'),
    'database': os.getenv('DB_NAME', 'microservices'),
    'user': os.getenv('DB_USER', 'app_user'),
    'password': os.getenv('DB_PASSWORD', 'securepassword123'),
    'port': os.getenv('DB_PORT', '5432')
}

JWT_SECRET = os.getenv('JWT_SECRET', 'microservices-secret-key-2024')

def get_db_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logging.error(f"Database connection failed: {e}")
        return None

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            token = token.replace('Bearer ', '')
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            current_user = payload['user_id']
        except Exception as e:
            logging.warning(f"Token validation failed: {e}")
            return jsonify({'error': 'Token is invalid'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

@app.route('/accounts', methods=['GET'])
@token_required
def get_accounts(current_user):
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503
    
    try:
        cur = conn.cursor()
        cur.execute(
            'SELECT account_number, balance, account_type FROM accounts WHERE user_id = %s',
            (current_user,)
        )
        accounts = cur.fetchall()
        cur.close()
        
        account_list = [
            {
                'account_number': acc[0],
                'balance': float(acc[1]),
                'type': acc[2]
            }
            for acc in accounts
        ]
        
        return jsonify({
            'user_id': current_user,
            'accounts': account_list,
            'host': os.getenv('HOSTNAME', 'unknown')
        })
    except Exception as e:
        logging.error(f"Database query failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()

# -----------------------------------------------------------------
# 2️⃣ Create Account (POST /accounts)
# -----------------------------------------------------------------
@app.route('/accounts', methods=['POST'])
@token_required
def create_account(current_user):
    data = request.get_json()
    account_number = data.get('account_number')
    balance = data.get('balance', 0)
    account_type = data.get('account_type', 'checking')
    if not account_number:
        return jsonify({'error': 'account_number required'}), 400
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503
    try:
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO accounts (user_id, account_number, balance, account_type) VALUES (%s, %s, %s, %s)',
            (current_user, account_number, balance, account_type)
        )
        conn.commit()
        cur.close()
        return jsonify({'message': 'account created', 'account_number': account_number}), 201
    except Exception as e:
        logging.error(f"Database insert failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()

@app.route('/accounts/<account_number>', methods=['GET'])
@token_required
def get_account(current_user, account_number):
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503
    
    try:
        cur = conn.cursor()
        cur.execute(
            'SELECT account_number, balance, account_type FROM accounts WHERE user_id = %s AND account_number = %s',
            (current_user, account_number)
        )
        account = cur.fetchone()
        cur.close()
        
        if not account:
            return jsonify({'error': 'Account not found'}), 404
        
        return jsonify({
            'account_number': account[0],
            'balance': float(account[1]),
            'type': account[2]
        })
    except Exception as e:
        logging.error(f"Database query failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()

@app.route('/health', methods=['GET'])
@app.route('/accounts/health', methods=['GET'])
def health():
    db_status = 'healthy' if get_db_connection() else 'unhealthy'
    return jsonify({
        'service': 'account-service',
        'status': 'healthy',
        'database': db_status,
        'host': os.getenv('HOSTNAME', 'unknown')
    })

# Prometheus metrics
REQUEST_COUNT = Counter('account_requests_total', 'Total account requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('account_request_duration_seconds', 'Account request latency')
ACCOUNT_OPERATIONS = Counter('account_operations_total', 'Total account operations', ['operation'])
DB_CONNECTIONS = Gauge('account_db_connections', 'Number of database connections')

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    if hasattr(request, 'start_time'):
        latency = time.time() - request.start_time
        REQUEST_LATENCY.observe(latency)
        REQUEST_COUNT.labels(method=request.method, endpoint=request.path, status=response.status_code).inc()
    return response

@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)