#!/bin/bash
# Jenkins Server User Data Script
# Installs Jenkins, Docker, AWS CLI, and required tools

set -e

# Update system
dnf update -y

# Install Java 17 (required for Jenkins)
dnf install -y java-17-amazon-corretto-headless

# Add Jenkins repository
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
dnf install -y jenkins

# Install Docker
dnf install -y docker

# Install Git
dnf install -y git

# Install additional tools
dnf install -y jq unzip

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Terraform
TERRAFORM_VERSION="1.6.0"
cd /tmp
wget https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_$${TERRAFORM_VERSION}_linux_amd64.zip

# Install Trivy (container scanner)
rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.rpm

# Install Node.js and npm (for Snyk and other tools)
dnf install -y nodejs npm

# Install Python and pip
dnf install -y python3 python3-pip

# Install security scanning tools
pip3 install checkov

# Add jenkins user to docker group
usermod -aG docker jenkins

# Start and enable services
systemctl start docker
systemctl enable docker
systemctl start jenkins
systemctl enable jenkins

# Configure CloudWatch Logs agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/jenkins/jenkins.log",
            "log_group_name": "/aws/ec2/${project_name}",
            "log_stream_name": "jenkins-{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Create motd
cat > /etc/motd <<'EOF'
===============================================
   Jenkins CI/CD Server
   ${project_name}
===============================================

Jenkins Web UI: http://$(ec2-metadata --public-ipv4 | cut -d ' ' -f 2):8080

Initial Admin Password:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

Installed Tools:
- Jenkins (Java 17)
- Docker
- AWS CLI v2
- kubectl
- Terraform
- Trivy (container scanner)
- Checkov (IaC scanner)
- Node.js & npm
- Python 3 & pip

===============================================
EOF

# Create helper script to get initial password
cat > /usr/local/bin/jenkins-password <<'EOF'
#!/bin/bash
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Jenkins Initial Admin Password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
else
    echo "Jenkins is still initializing. Please wait a moment and try again."
fi
EOF
chmod +x /usr/local/bin/jenkins-password

echo "Jenkins installation complete. Waiting for initialization..."
sleep 30

# Log completion
echo "User data script completed at $(date)" >> /var/log/user-data.log
