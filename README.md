# 🛡️ Microservices VM Security Demo

A **complete, reproducible** environment that showcases:

- **Three micro‑services** (Auth, Account, Transaction) built with Docker.
- **NGINX API gateway**, **Prometheus**, **Grafana** for observability.
- **PostgreSQL** database with hardened user permissions.
- **Security hardening** (UFW firewall, Fail2Ban, IPv6 disabled, SSH hardening) applied to every VM.
- **Infrastructure‑as‑code** using **Vagrant** + **VirtualBox** (no external cloud needed).

> The project is deliberately crafted to be **premium‑looking** (rich UI, glass‑morphism, dark mode) while staying fully functional on a local machine.

---

## 📦 Project Structure

```
microservices-vm-security/
├─ Vagrantfile                # VM definitions & provisioning
├─ scripts/
│   ├─ provision-bastion.sh   # Installs Docker, copies services, starts compose
│   ├─ provision-app1.sh      # Installs Docker, runs Account service
│   ├─ provision-app2.sh      # Installs Docker, runs Transaction service
│   ├─ setup-database.sh      # PostgreSQL install + schema + sample data
│   ├─ vm-security.sh        # UFW, Fail2Ban, sysctl hardening
│   └─ run_api_test.sh        # Comprehensive functional test (see below)
├─ services/
│   ├─ auth-service/          # JWT Authentication
│   ├─ account-service/       # Account Management
│   └─ transaction-service/   # Transaction History
└─ README.md                  # You are reading this!
```

---

## 🚀 Quick Start

**Prerequisites**:
- Ubuntu 20.04 host (or any Linux with VirtualBox & Vagrant installed).
- `vagrant`, `virtualbox`, `jq`, `curl`.

```bash
# 1️⃣ Clone the repo (if you haven't already)
git clone <repo‑url>
cd microservices-vm-security

# 2️⃣ Bring up the VMs (first run will download the base box)
vagrant up
```

The Vagrantfile creates **four VMs**:

| VM | Role | IP (host‑only) | Ports exposed |
|----|------|----------------|---------------|
| **bastion** | NGINX gateway, Prometheus, Grafana | `192.168.56.10` | 8080 (NGINX), 9090 (Prometheus), 3000 (Grafana) |
| **app1** | Account service (Docker) | `192.168.56.11` | 5000 |
| **app2** | Transaction service (Docker) | `192.168.56.12` | 5001 |
| **db** | PostgreSQL | `192.168.56.20` | 5432 |

All VMs share a **host‑only network** (`192.168.56.0/24`).  
UFW rules are automatically applied (only required ports are open).

---

## 🧪 Comprehensive Testing

The project ships with a single, all‑in‑one test script: `scripts/run_api_test.sh`. It performs the following checks:

1. **Health checks** for Auth, Account, and Transaction services.
2. **Login** to the Auth service and retrieve a JWT.
3. **GET /accounts** – verifies JSON response.
4. **POST /accounts** – creates a new account and checks HTTP 201.
5. **GET /accounts** again – ensures the new account appears.
6. **GET /transactions/<account>** – validates the transaction endpoint.
7. **Final summary** – prints a success banner if everything passed.

### Run the Automated Test

```bash
vagrant ssh bastion -c "/home/vagrant/scripts/run_api_test.sh"
```

**Expected output** – a series of `✅` messages followed by:

```
🎉 All tests passed successfully! The microservices stack is fully operational.
```

---

## 🛠️ Manual Testing & Inspection

If you need to debug or explore the system manually, the following commands are handy.

### 1. SSH into the Bastion VM
```bash
vagrant ssh bastion
```

### 2. Service Health Endpoints
```bash
curl http://localhost:8080/auth/health
curl http://localhost:8080/accounts/health
curl http://localhost:8080/transactions/health
```

Each should return a JSON payload with `status: "healthy"`.

### 3. Authentication (Obtain JWT)
```bash
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"user1", "password":"password1"}' \
  http://localhost:8080/auth/login | jq -r .token)

echo "Token: $TOKEN"
```

### 4. Account Operations
```bash
# List accounts
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/accounts | jq .

# Create a new account (replace <ACCOUNT_ID> with a unique value)
NEW_ACC="MANUAL-$(date +%s)"
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"user1\", \"account_number\": \"$NEW_ACC\", \"balance\": 1000, \"account_type\": \"checking\"}" \
  http://localhost:8080/accounts
```

### 5. Transaction Checks
```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/transactions/$NEW_ACC | jq .
```

### 6. Database Connectivity Test
From the **bastion** VM you can directly query PostgreSQL to ensure the DB is reachable:
```bash
psql "host=192.168.56.20 dbname=microservices user=app_user password=securepassword123" -c "SELECT 1;"
```

A successful `SELECT 1` indicates the DB is up and the credentials are correct.

### 7. Prometheus Metrics
```bash
curl http://localhost:9090/api/v1/query?query=up
```

You should see a JSON response with `up` metrics for each service (value `1`).

### 8. Grafana Dashboard Access
Open a browser on your host and navigate to:
- **Grafana**: `http://192.168.56.10:3000` (default credentials `admin / admin`).
- **Prometheus UI**: `http://192.168.56.10:9090`.

### 9. Security Checks
```bash
# UFW status (should show only allowed ports)
sudo ufw status verbose

# Fail2Ban status (jail list and active bans)
sudo fail2ban-client status
```

### 10. Log Inspection
```bash
# Docker logs for each service (run from bastion)
for svc in auth-service account-service transaction-service; do
  echo "--- $svc logs ---"
  docker logs $(docker ps --filter "name=$svc" -q)
  echo "\n"
done
```

---

## 🔐 Security Hardening (What `vm-security.sh` Does)

- **UFW firewall** – default deny, only required ports open.
- **Fail2Ban** – protects SSH from brute‑force attacks.
- **Kernel hardening** – disables IPv6, disables source routing, enables `sysctl` protections.
- **SSH hardening** – root login disabled, key‑based authentication enforced.
- **Docker daemon** – runs with least privileges; containers isolated via host‑only network.

All hardening steps run **during provisioning**, so the VMs are secure from the moment they boot.

---

## 📊 Observability

- **Grafana** – `http://192.168.56.10:3000` (admin / admin) – dashboards for CPU, memory, Docker stats.
- **Prometheus** – `http://192.168.56.10:9090` – scrapes `/health` endpoints of each service.
- **NGINX** – `http://192.168.56.10:8080` – reverse‑proxies `/auth/`, `/accounts/`, `/transactions/`.

---
## 🔎 Inspecting the Project

You can explore the inner workings of the stack directly from the **bastion** VM:

```bash
# List all running Docker containers (services)
docker ps --format "{{.Names}} – {{.Image}} – {{.Ports}}"

# View logs of a specific service (replace <service> with auth-service, account-service, or transaction-service)
docker logs <service>

# Enter a container’s shell for deeper debugging
docker exec -it <service> /bin/sh
```

If you need to see the source code of any service, they are mounted inside the VM at `/home/vagrant/services/<service-name>`.

```bash
cd /home/vagrant/services/auth-service   # example for auth service
ls -R                                 # view the full directory tree
```

These commands, combined with the manual testing steps above, give you full visibility into the running system.
## 📂 Clean‑up (Take Down Everything)

To completely remove the environment and free up resources:

```bash
# Stop and destroy all VMs
vagrant destroy -f
```

This deletes the VMs and their disks. To start fresh, simply run `vagrant up` again.

---

## 🛠️ Troubleshooting

- **VMs fail to come up?**  Run `vagrant destroy -f` and retry `vagrant up`. VirtualBox networking can sometimes get stuck.
- **Tests fail?**  Inspect Docker logs (`docker logs <container_id>`) on the bastion VM. The test script also prints the raw HTTP response on failure.
- **Database connection errors?**  Verify the `db` VM is running (`vagrant status`) and reachable (`ping 192.168.56.20`). Check the PostgreSQL logs: `sudo journalctl -u postgresql` on the `db` VM.
- **Prometheus not scraping?**  Ensure the services expose `/health` on the correct ports and that the firewall allows traffic from the bastion VM.

---

## 🎉 TL;DR

```bash
git clone multiMVDockersetup
cd microservices-vm-security
vagrant up               # spin up 4 VMs, install Docker, DB, services, hardening
vagrant ssh bastion -c "/home/vagrant/scripts/run_api_test.sh"   # run full functional test
```

Enjoy a **secure, observable, fully‑functional micro‑services playground** right on your laptop! 🚀
