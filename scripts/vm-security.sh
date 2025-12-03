#!/bin/bash

echo "🔒 Starting security hardening for $(hostname)..."
export DEBIAN_FRONTEND=noninteractive

# 1. Configure firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# VM-specific firewall rules
case $(hostname) in
    "bastion")
        ufw allow 22/tcp
        ufw allow 8080/tcp
        ufw allow 5002/tcp
        ufw allow 3000/tcp
        ufw allow 9090/tcp
        ;;
    "app1")
        ufw allow from 192.168.56.0/24 to any port 22
        ufw allow from 192.168.56.0/24 to any port 5000
        ;;
    "app2")
        ufw allow from 192.168.56.0/24 to any port 22
        ufw allow from 192.168.56.0/24 to any port 5001
        ;;
    "db")
        ufw allow from 192.168.56.11 to any port 5432
        ufw allow from 192.168.56.12 to any port 5432
        ufw allow from 192.168.56.10 to any port 5432
        ufw allow 22/tcp
        ;;
esac

ufw --force enable
# Set a password for the vagrant user (used later in the test)
echo "vagrant:password123" | chpasswd
# Configure sudoers to allow reading UFW status without password, but require password for modifications
sudo bash -c "echo 'Defaults:vagrant !requiretty' > /etc/sudoers.d/vagrant-pw"
sudo bash -c "echo 'vagrant ALL=(ALL) NOPASSWD: /usr/sbin/ufw status' >> /etc/sudoers.d/vagrant-pw"
sudo bash -c "echo 'vagrant ALL=(ALL) PASSWD: /usr/sbin/ufw, /usr/bin/fail2ban-client' >> /etc/sudoers.d/vagrant-pw"
sudo chmod 440 /etc/sudoers.d/vagrant-pw
echo "✅ Firewall configured"

# 2. SSH hardening
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-ssh/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowUsers vagrant" >> /etc/ssh/sshd_config
systemctl restart sshd
echo "✅ SSH hardened"

# 3. Install security tools
apt-get install -y fail2ban unattended-upgrades

# Configure fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban
echo "✅ Security tools installed"

# 4. System hardening
# Disable IPv6
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
sysctl -p

# Configure automatic security updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

echo "✅ System hardening completed for $(hostname)"