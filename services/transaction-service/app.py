from flask import Flask, jsonify, request
import jwt
import psycopg2
import os
import logging
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

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
        return psycopg2.connect(**DB_CONFIG)
    except Exception as e:
        logging.error(f"Database connection failed: {e}")
        return None

def validate_token(token):
    if not token:
        return None
    try:
        token = token.replace('Bearer ', '')
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except Exception as e:
        logging.warning(f"Token validation failed: {e}")
        return None

@app.route('/transactions/<account_number>', methods=['GET'])
def get_transactions(account_number):
    auth_header = request.headers.get('Authorization')
    user = validate_token(auth_header)
    
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503
    
    try:
        cur = conn.cursor()
        cur.execute(
            'SELECT amount, transaction_type, description, created_at FROM transactions WHERE account_number = %s ORDER BY created_at DESC',
            (account_number,)
        )
        transactions = cur.fetchall()
        cur.close()
        
        transaction_list = [
            {
                'amount': float(t[0]),
                'type': t[1],
                'description': t[2],
                'timestamp': t[3].isoformat()
            }
            for t in transactions
        ]
        
        return jsonify({
            'account_number': account_number,
            'transactions': transaction_list,
            'host': os.getenv('HOSTNAME', 'unknown')
        })
    except Exception as e:
        logging.error(f"Database query failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500
    finally:
        conn.close()

@app.route('/health', methods=['GET'])
@app.route('/transactions/health', methods=['GET'])
def health():
    db_status = 'healthy' if get_db_connection() else 'unhealthy'
    return jsonify({
        'service': 'transaction-service',
        'status': 'healthy',
        'database': db_status,
        'host': os.getenv('HOSTNAME', 'unknown')
    })

# Prometheus metrics
REQUEST_COUNT = Counter('transaction_requests_total', 'Total transaction requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('transaction_request_duration_seconds', 'Transaction request latency')
TRANSACTION_OPERATIONS = Counter('transaction_operations_total', 'Total transaction operations', ['operation'])
DB_CONNECTIONS = Gauge('transaction_db_connections', 'Number of database connections')

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
    app.run(host='0.0.0.0', port=5001)