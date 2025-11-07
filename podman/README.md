# Podman Deployment Guide

This directory contains configurations for deploying the DevOps Portfolio application using Podman, a daemonless container engine that's compatible with Docker.

## Overview

Podman offers two deployment methods:

1. **Podman Compose** - Uses `podman-compose` (similar to Docker Compose)
2. **Podman Play Kube** - Uses Kubernetes YAML directly with `podman play kube`

## Prerequisites

- **Podman** installed (version 4.0+)
- **podman-compose** (optional, for compose method)
- Docker images built (backend and frontend)

### Installing Podman

**macOS:**
```bash
brew install podman
podman machine init
podman machine start
```

**Linux:**
```bash
# Fedora/RHEL/CentOS
sudo dnf install podman

# Ubuntu/Debian
sudo apt-get install podman
```

### Installing podman-compose (Optional)

```bash
pip3 install podman-compose
```

## Deployment Methods

### Method 1: Podman Compose (Recommended for Development)

Uses the familiar Docker Compose syntax with Podman.

**Quick Start:**
```bash
cd podman
./podman-up.sh
```

**Manual Steps:**
```bash
# Navigate to podman directory
cd podman

# Build and start services
podman-compose up -d --build

# View logs
podman-compose logs -f

# Check status
podman-compose ps

# Stop services
podman-compose down
```

**Access Points:**
- Frontend: http://localhost:8081
- Backend API: http://localhost:3001/api/health
- PostgreSQL: localhost:5433

**Features:**
- Automatic service discovery via network
- Health checks for all services
- Persistent PostgreSQL data
- Automatic container restart

### Method 2: Podman Play Kube (Kubernetes-Compatible)

Uses Kubernetes YAML format, making it compatible with Kubernetes deployments.

**Quick Start:**
```bash
cd podman
./podman-play.sh
```

**Manual Steps:**
```bash
# Navigate to podman directory
cd podman

# Build images first (if not already built)
podman build -t localhost/docker-backend:latest -f ../docker/backend/Dockerfile ..
podman build -t localhost/docker-frontend:latest -f ../docker/frontend/Dockerfile ..

# Deploy the pod
podman play kube devops-portfolio-pod.yaml

# Check pod status
podman pod ps
podman ps --filter pod=devops-portfolio

# View logs
podman pod logs devops-portfolio

# Stop and remove pod
podman kube down devops-portfolio-pod.yaml
```

**Access Points:**
- Frontend: http://localhost:8081
- Backend API: http://localhost:3001/api/health
- PostgreSQL: localhost:5433

**Features:**
- All containers run in a single pod (shared network namespace)
- Containers communicate via localhost (no service discovery needed)
- Kubernetes-compatible YAML
- ConfigMaps for configuration management
- Persistent volume for database

## Key Differences from Docker

### Network Configuration

**Podman Pod:**
- All containers in a pod share the same network namespace
- Containers communicate via `localhost:<port>`
- Example: Frontend connects to backend at `http://localhost:3000`

**Podman Compose:**
- Containers use bridge network with service discovery
- Containers communicate via service names
- Example: Frontend connects to backend at `http://backend:3000`

### Port Mappings

To avoid conflicts with Docker and Kubernetes deployments:
- Frontend: **8081** (instead of 8080)
- Backend: **3001** (instead of 3000)
- PostgreSQL: **5433** (instead of 5432)

## File Structure

```
podman/
├── README.md                      # This file
├── devops-portfolio-pod.yaml      # Kubernetes YAML for Podman play kube
├── podman-compose.yml             # Compose file for podman-compose
├── nginx-podman.conf              # NGINX config for compose deployment
├── podman-up.sh                   # Helper script for compose deployment
└── podman-play.sh                 # Helper script for play kube deployment
```

## Common Commands

### Podman Compose

```bash
# Start services
podman-compose up -d

# View logs (all services)
podman-compose logs -f

# View logs (specific service)
podman-compose logs -f backend

# Restart a service
podman-compose restart backend

# Stop all services
podman-compose down

# Remove volumes
podman-compose down -v
```

### Podman Play Kube

```bash
# Deploy pod
podman play kube devops-portfolio-pod.yaml

# List pods
podman pod ps

# View all containers in pod
podman ps --filter pod=devops-portfolio

# View pod logs (all containers)
podman pod logs devops-portfolio

# View specific container logs
podman logs devops-portfolio-frontend
podman logs devops-portfolio-backend
podman logs devops-portfolio-postgres

# Stop pod
podman pod stop devops-portfolio

# Start pod
podman pod start devops-portfolio

# Remove pod
podman kube down devops-portfolio-pod.yaml
# OR
podman pod rm -f devops-portfolio
```

## Troubleshooting

### Port Already in Use

If ports 8081, 3001, or 5433 are already in use:

**For Podman Compose:**
Edit `podman-compose.yml` and change the port mappings:
```yaml
ports:
  - "8082:80"  # Change first number to available port
```

**For Podman Play Kube:**
Edit `devops-portfolio-pod.yaml` and change the hostPort:
```yaml
ports:
- containerPort: 80
  hostPort: 8082  # Change to available port
```

### Images Not Found

Build the images manually:
```bash
cd ..
podman build -t localhost/docker-backend:latest -f docker/backend/Dockerfile .
podman build -t localhost/docker-frontend:latest -f docker/frontend/Dockerfile .
```

### Database Connection Issues

Wait 30 seconds after starting for PostgreSQL to initialize:
```bash
# Check if PostgreSQL is ready
podman exec devops-postgres pg_isready -U dbadmin -d devops_portfolio
```

### Container Logs

View container logs to diagnose issues:
```bash
# Podman Compose
podman-compose logs backend
podman-compose logs postgres

# Podman Play Kube
podman logs devops-portfolio-backend
podman logs devops-portfolio-postgres
```

### Reset Everything

**Podman Compose:**
```bash
podman-compose down -v
podman-compose up -d --build --force-recreate
```

**Podman Play Kube:**
```bash
podman kube down devops-portfolio-pod.yaml
podman volume rm postgres-data-pvc
podman play kube devops-portfolio-pod.yaml
```

## Comparison: Compose vs Play Kube

| Feature | Podman Compose | Podman Play Kube |
|---------|---------------|------------------|
| Syntax | Docker Compose YAML | Kubernetes YAML |
| Learning Curve | Easy (if familiar with Docker) | Medium (Kubernetes concepts) |
| Networking | Bridge network | Shared network namespace |
| Container Communication | Service names | localhost |
| Portability | Docker/Podman only | Kubernetes/Podman |
| Resource Limits | Limited support | Full Kubernetes resources |
| Configuration | Environment variables | ConfigMaps & Secrets |
| Best For | Local development | K8s compatibility |

## Integration with Other Deployments

This Podman setup coexists with:
- **Docker Compose** (port 8080) - See `../docker/docker-compose.yml`
- **Kubernetes** (NodePort 30080) - See `../kubernetes/local/`

Each deployment uses different ports to avoid conflicts.

## Production Considerations

For production deployments:
1. Use secrets management instead of plaintext passwords
2. Configure proper resource limits
3. Set up health checks and monitoring
4. Use volume backups for database
5. Consider using Podman with systemd for auto-restart
6. Review security best practices in Podman documentation

## Additional Resources

- [Podman Documentation](https://docs.podman.io/)
- [Podman Compose GitHub](https://github.com/containers/podman-compose)
- [Podman Play Kube Documentation](https://docs.podman.io/en/latest/markdown/podman-play-kube.1.html)
- [Kubernetes YAML Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
