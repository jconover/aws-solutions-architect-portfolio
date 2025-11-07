#!/bin/bash
# Bastion Host User Data Script
# Sets up bastion host with necessary tools for accessing private resources

set -e

# Update system
dnf update -y

# Install useful tools
dnf install -y \
    postgresql15 \
    mysql \
    telnet \
    nc \
    tcpdump \
    htop \
    vim \
    git \
    jq \
    unzip

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Session Manager plugin
cd /tmp
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
dnf install -y session-manager-plugin.rpm
rm session-manager-plugin.rpm

# Create motd
cat > /etc/motd <<'EOF'
===============================================
   Bastion Host
   ${project_name}
===============================================

This bastion host provides secure access to:
- RDS databases in private subnets
- ECS tasks via AWS CLI
- EKS cluster via kubectl
- Private resources

Available Tools:
- AWS CLI v2
- Session Manager
- PostgreSQL client (psql)
- MySQL client
- kubectl
- Network tools (telnet, nc, tcpdump)

Example Usage:
# Connect to RDS
psql -h <rds-endpoint> -U dbadmin -d appdb

# Check ECS tasks
aws ecs list-tasks --cluster <cluster-name>

# Configure kubectl for EKS
aws eks update-kubeconfig --name <cluster-name>

===============================================
EOF

# Disable password authentication (SSH key only)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd

# Log completion
echo "Bastion host user data script completed at $(date)" >> /var/log/user-data.log
