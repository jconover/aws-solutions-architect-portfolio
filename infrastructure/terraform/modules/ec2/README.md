# EC2 Module

This module creates EC2 instances for Jenkins CI/CD server and optional bastion host.

## Features

### Jenkins Server
- Amazon Linux 2023 with latest security patches
- Pre-installed Jenkins with Java 17
- Docker for building and running containers
- AWS CLI v2 for AWS operations
- kubectl for EKS management
- Terraform for infrastructure operations
- Security scanning tools (Trivy, Checkov)
- Elastic IP for stable addressing
- CloudWatch logging integration
- Proper security group configuration

### Bastion Host (Optional)
- Lightweight Amazon Linux 2023
- PostgreSQL and MySQL clients for database access
- AWS CLI and Session Manager for AWS operations
- Network debugging tools
- Elastic IP for stable addressing
- SSH key-only authentication

## Usage

```hcl
module "ec2" {
  source = "../../modules/ec2"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id

  public_subnet_ids = module.vpc.public_subnet_ids
  key_name          = "your-ssh-key-name"

  # Jenkins Configuration
  create_jenkins                = true
  jenkins_instance_type         = "t3.medium"
  jenkins_volume_size           = 50
  jenkins_use_elastic_ip        = true
  jenkins_iam_instance_profile  = module.iam.jenkins_instance_profile_name
  allowed_jenkins_cidrs         = ["YOUR_IP/32"]  # Restrict to your IP

  # Bastion Configuration
  create_bastion        = true
  bastion_instance_type = "t3.micro"

  # Security
  allowed_ssh_cidrs = ["YOUR_IP/32"]  # Restrict SSH to your IP

  common_tags = local.common_tags
}
```

## Security Considerations

### Jenkins Security
1. **Restrict Access**: Set `allowed_jenkins_cidrs` and `allowed_ssh_cidrs` to your IP only
2. **Initial Setup**: Change admin password immediately after first login
3. **HTTPS**: Configure HTTPS with valid certificate (not included in this module)
4. **Firewall**: Security group allows only necessary ports (22, 8080, 50000)
5. **Updates**: Keep Jenkins and plugins updated regularly

### Bastion Security
1. **SSH Key Only**: Password authentication is disabled
2. **IP Restriction**: Limit SSH access via `allowed_ssh_cidrs`
3. **Minimal Tools**: Only necessary tools are installed
4. **Session Manager**: Supports AWS Session Manager for keyless access
5. **Logging**: All access is logged to CloudWatch

## Accessing Jenkins

After deployment:

```bash
# Get Jenkins URL
terraform output jenkins_url

# SSH to Jenkins server
ssh -i your-key.pem ec2-user@<jenkins-ip>

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# Or use helper script
jenkins-password
```

## Accessing Bastion

```bash
# SSH to bastion
ssh -i your-key.pem ec2-user@<bastion-ip>

# Or use Session Manager (no SSH key needed)
aws ssm start-session --target <instance-id>

# Connect to RDS from bastion
psql -h <rds-endpoint> -U dbadmin -d appdb
```

## Outputs

- `jenkins_url`: URL to access Jenkins web interface
- `jenkins_instance_id`: EC2 instance ID for Jenkins
- `jenkins_elastic_ip`: Elastic IP of Jenkins server
- `bastion_instance_id`: EC2 instance ID for bastion
- `bastion_elastic_ip`: Elastic IP of bastion host
- `jenkins_security_group_id`: Security group for Jenkins
- `bastion_security_group_id`: Security group for bastion

## Cost Considerations

- **Jenkins (t3.medium)**: ~$30/month
- **Bastion (t3.micro)**: ~$7.50/month
- **Elastic IPs**: Free when attached, $3.60/month if detached
- **Storage**: $0.08/GB/month for gp3

Total estimated cost: ~$40-50/month for both instances

## Notes

- User data scripts may take 5-10 minutes to complete
- Jenkins initialization takes additional 2-3 minutes after installation
- Check `/var/log/cloud-init-output.log` for user data execution logs
- CloudWatch agent requires proper IAM permissions (included in IAM module)
