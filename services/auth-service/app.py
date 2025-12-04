from flask import Flask, jsonify, request
import jwt
import datetime
import hashlib
import os
import logging
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Mock user database
users_db = {
    "user1": {
        "password_hash": hashlib.sha256("password1".encode()).hexdigest(),
        "user_id": "user1",
        "email": "user1@example.com"
    },
    "user2": {
        "password_hash": hashlib.sha256("password2".encode()).hexdigest(),
        "user_id": "user2", 
        "email": "user2@example.com"
    }
}

JWT_SECRET = os.getenv('JWT_SECRET', 'microservices-secret-key-2024')
JWT_EXPIRY_HOURS = 24

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    
    user = users_db.get(username)
    if not user:
        logging.warning(f"Failed login attempt for unknown user: {username}")
        return jsonify({'error': 'Invalid credentials'}), 401
    
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    if user['password_hash'] != password_hash:
        logging.warning(f"Failed login attempt for user: {username}")
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Generate JWT token
    payload = {
        'user_id': user['user_id'],
        'email': user['email'],
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=JWT_EXPIRY_HOURS),
        'iat': datetime.datetime.utcnow()
    }
    
    token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
    
    logging.info(f"Successful login for user: {username}")
    return jsonify({
        'token': token,
        'user_id': user['user_id'],
        'email': user['email'],
        'expires_in': JWT_EXPIRY_HOURS * 3600
    })

@app.route('/auth/validate', methods=['POST'])
def validate():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return jsonify({'valid': True, 'user_id': payload['user_id']})
    except Exception as e:
        logging.warning(f"Token validation failed: {e}")
        return jsonify({'valid': False, 'error': 'Invalid token'}), 401

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'service': 'auth-service', 
        'status': 'healthy',
        'host': os.getenv('HOSTNAME', 'unknown')
    })
@app.route('/auth/health', methods=['GET'])
def auth_health():
    return jsonify({
        'service': 'auth-service',
        'status': 'healthy',
        'host': os.getenv('HOSTNAME', 'unknown')
    })

# Prometheus metrics
REQUEST_COUNT = Counter('auth_requests_total', 'Total auth requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('auth_request_duration_seconds', 'Auth request latency')
LOGIN_ATTEMPTS = Counter('auth_login_attempts_total', 'Total login attempts', ['status'])
ACTIVE_SESSIONS = Gauge('auth_active_sessions', 'Number of active sessions')

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
    app.run(host='0.0.0.0', port=5002)