# 🚀 Quick Start - Monitoring with Grafana & Prometheus

## 1️⃣ Deploy Everything

```bash
cd ~/microservices-vm-security
vagrant up
```

⏱️ Wait 5-10 minutes for all VMs to provision

## 2️⃣ Access Monitoring Tools

| Tool | URL | Credentials |
|------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | No auth |
| **API Gateway** | http://localhost:8080 | - |

## 3️⃣ Generate Traffic

```bash
vagrant ssh bastion -c "/home/vagrant/scripts/run_api_test.sh"
```

## 4️⃣ View Metrics

### In Grafana:
1. Open http://localhost:3000
2. Login with admin/admin
3. Go to Dashboards → Microservices Overview Dashboard
4. See real-time metrics! 📊

### In Prometheus:
1. Open http://localhost:9090
2. Try these queries:

```promql
# Request rate
rate(auth_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(auth_request_duration_seconds_bucket[5m]))

# Service health
up{job="auth-service"}
```

## 5️⃣ Check Metrics Endpoints

```bash
# Auth service
curl http://localhost:5002/metrics

# Account service (through bastion)
vagrant ssh bastion -c "curl http://192.168.56.11:5000/metrics"

# Transaction service (through bastion)
vagrant ssh bastion -c "curl http://192.168.56.12:5001/metrics"
```

## 📊 What You'll See

- **Request Rates**: Requests per second for each service
- **Latency**: P50, P95, P99 response times
- **Error Rates**: 4xx and 5xx responses
- **Service Health**: Up/Down status

## 🔧 Troubleshooting

```bash
# Check all containers
vagrant ssh bastion -c "docker ps"

# Check Prometheus targets
open http://localhost:9090/targets

# Restart services
vagrant ssh bastion -c "cd /opt/microservices && docker-compose restart"
```

## 📚 More Info

- Full documentation: `MONITORING.md`
- Changes summary: `GRAFANA_PROMETHEUS_CHANGES.md`
- Main README: `README.md`

---

**That's it!** You now have full monitoring of your microservices! 🎉
