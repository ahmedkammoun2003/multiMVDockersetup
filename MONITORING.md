# Grafana and Prometheus Monitoring Setup

## Overview

All microservices are now connected to Prometheus for metrics collection and Grafana for visualization.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Bastion Host (192.168.56.10)            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Grafana    │  │  Prometheus  │  │     Nginx    │      │
│  │   :3000      │──│    :9090     │──│    :8080     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│  Auth Service  │  │ Account Service│  │ Transaction    │
│  :5002/metrics │  │ :5000/metrics  │  │ Service        │
│  (Bastion)     │  │  (App1)        │  │ :5001/metrics  │
└────────────────┘  └────────────────┘  │  (App2)        │
                                        └────────────────┘
```

## Metrics Endpoints

Each service exposes Prometheus metrics at `/metrics`:

- **Auth Service**: `http://192.168.56.10:5002/metrics`
- **Account Service**: `http://192.168.56.11:5000/metrics`
- **Transaction Service**: `http://192.168.56.12:5001/metrics`

## Available Metrics

### Auth Service
- `auth_requests_total` - Total number of requests (labels: method, endpoint, status)
- `auth_request_duration_seconds` - Request latency histogram
- `auth_login_attempts_total` - Login attempts (labels: status)
- `auth_active_sessions` - Number of active sessions

### Account Service
- `account_requests_total` - Total number of requests
- `account_request_duration_seconds` - Request latency histogram
- `account_operations_total` - Account operations (labels: operation)
- `account_db_connections` - Database connection count

### Transaction Service
- `transaction_requests_total` - Total number of requests
- `transaction_request_duration_seconds` - Request latency histogram
- `transaction_operations_total` - Transaction operations (labels: operation)
- `transaction_db_connections` - Database connection count

## Accessing Grafana

1. **URL**: http://localhost:3000 (or http://192.168.56.10:3000)
2. **Default Credentials**:
   - Username: `admin`
   - Password: `admin`

3. **Pre-configured Dashboard**: "Microservices Overview Dashboard"
   - Request rates by service
   - P95 latency metrics
   - Service health status

## Accessing Prometheus

1. **URL**: http://localhost:9090 (or http://192.168.56.10:9090)
2. **Query Examples**:

```promql
# Request rate for all services
rate(auth_requests_total[5m])
rate(account_requests_total[5m])
rate(transaction_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(auth_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(account_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(transaction_request_duration_seconds_bucket[5m]))

# Service health (1 = up, 0 = down)
up{job="auth-service"}
up{job="account-service"}
up{job="transaction-service"}

# Error rate (4xx and 5xx responses)
rate(auth_requests_total{status=~"4..|5.."}[5m])
```

## Grafana Dashboard Features

The pre-configured dashboard includes:

1. **Request Rate Panel**: Shows requests per second for each service
2. **Latency Gauge**: Displays P95 latency for all services
3. **Health Status**: Real-time service availability

## Creating Custom Dashboards

1. Log into Grafana (http://localhost:3000)
2. Click "+" → "Dashboard"
3. Add a new panel
4. Select "Prometheus" as the data source
5. Enter your PromQL query
6. Configure visualization options
7. Save the dashboard

## Alerting (Optional Enhancement)

You can configure alerts in Grafana:

1. Go to "Alerting" → "Alert rules"
2. Create a new alert rule
3. Example: Alert when service is down
   ```promql
   up{job="auth-service"} == 0
   ```
4. Configure notification channels (email, Slack, etc.)

## Troubleshooting

### Metrics not appearing in Prometheus

```bash
# Check if services are exposing metrics
vagrant ssh bastion -c "curl http://localhost:5002/metrics"
vagrant ssh app1 -c "curl http://localhost:5000/metrics"
vagrant ssh app2 -c "curl http://localhost:5001/metrics"

# Check Prometheus targets
# Visit http://localhost:9090/targets
```

### Grafana dashboard not loading

```bash
# Check Grafana logs
vagrant ssh bastion -c "docker logs microservices-grafana-1"

# Restart Grafana
vagrant ssh bastion -c "cd /opt/microservices && docker-compose restart grafana"
```

### Prometheus not scraping

```bash
# Check Prometheus configuration
vagrant ssh bastion -c "docker exec microservices-prometheus-1 cat /etc/prometheus/prometheus.yml"

# Check Prometheus logs
vagrant ssh bastion -c "docker logs microservices-prometheus-1"
```

## Quick Start

```bash
# 1. Start all VMs
vagrant up

# 2. Wait for services to be ready (2-3 minutes)

# 3. Generate some traffic
vagrant ssh bastion -c "/home/vagrant/scripts/run_api_test.sh"

# 4. Access Grafana
open http://localhost:3000
# Login: admin/admin

# 5. View the "Microservices Overview Dashboard"

# 6. Access Prometheus
open http://localhost:9090
```

## Advanced Queries

### Request Success Rate
```promql
sum(rate(auth_requests_total{status=~"2.."}[5m])) / sum(rate(auth_requests_total[5m])) * 100
```

### Average Response Time
```promql
rate(auth_request_duration_seconds_sum[5m]) / rate(auth_request_duration_seconds_count[5m])
```

### Requests by Endpoint
```promql
sum by (endpoint) (rate(auth_requests_total[5m]))
```

## Monitoring Best Practices

1. **Set up alerts** for critical metrics (service down, high error rate, high latency)
2. **Monitor trends** over time to identify performance degradation
3. **Use labels** effectively to filter and aggregate metrics
4. **Create dashboards** for different audiences (ops, devs, business)
5. **Document your metrics** so team members understand what they mean

## Next Steps

- Add custom business metrics (e.g., successful transactions, account creations)
- Set up log aggregation with Loki
- Configure distributed tracing with Jaeger
- Add node exporters for system metrics
- Set up PostgreSQL exporter for database metrics
