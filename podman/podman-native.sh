#!/bin/bash
# Native Podman deployment script (without compose or play kube)
# Creates a pod with three containers using native Podman commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting DevOps Portfolio with Native Podman${NC}"

# Navigate to project root
cd "$(dirname "$0")/.."

# Stop and remove existing containers and pod
echo -e "${YELLOW}Cleaning up existing resources...${NC}"
podman rm -f devops-backend devops-frontend devops-postgres 2>/dev/null || true
podman pod stop devops-portfolio 2>/dev/null || true
podman pod rm devops-portfolio 2>/dev/null || true

# Create a new pod with port mappings
echo -e "${GREEN}Creating Podman pod...${NC}"
podman pod create \
  --name devops-portfolio \
  --publish 8081:80 \
  --publish 3001:3000 \
  --publish 5433:5432

# Create volume for PostgreSQL data
echo -e "${GREEN}Creating PostgreSQL volume...${NC}"
podman volume create postgres-data 2>/dev/null || true

# Start PostgreSQL container
echo -e "${GREEN}Starting PostgreSQL container...${NC}"
podman run -d \
  --pod devops-portfolio \
  --name devops-postgres \
  -e POSTGRES_DB=devops_portfolio \
  -e POSTGRES_USER=dbadmin \
  -e POSTGRES_PASSWORD=securepassword123 \
  -v postgres-data:/var/lib/postgresql/data \
  -v "$(pwd)/application/database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:15-alpine

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
sleep 10

# Start backend container
echo -e "${GREEN}Starting backend container...${NC}"
podman run -d \
  --pod devops-portfolio \
  --name devops-backend \
  -e PORT=3000 \
  -e NODE_ENV=development \
  -e DB_HOST=localhost \
  -e DB_PORT=5432 \
  -e DB_NAME=devops_portfolio \
  -e DB_USER=dbadmin \
  -e DB_PASSWORD=securepassword123 \
  localhost/docker-backend:latest

# Wait for backend to be ready
echo -e "${YELLOW}Waiting for backend to be ready...${NC}"
sleep 5

# Create NGINX config for Podman pod
echo -e "${GREEN}Creating NGINX configuration...${NC}"
cat > "$(pwd)/podman/nginx-pod.conf" <<'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    location /health {
        access_log off;
        try_files /health.html =200;
    }

    # In a pod, all containers share network namespace
    # Backend is accessible via localhost
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Start frontend container
echo -e "${GREEN}Starting frontend container...${NC}"
podman run -d \
  --pod devops-portfolio \
  --name devops-frontend \
  -v "$(pwd)/podman/nginx-pod.conf:/etc/nginx/conf.d/nginx.conf:ro" \
  localhost/docker-frontend:latest

# Wait a moment for everything to stabilize
echo -e "${YELLOW}Waiting for services to stabilize...${NC}"
sleep 5

# Check pod status
echo -e "${GREEN}Pod status:${NC}"
podman pod ps
echo ""
echo -e "${GREEN}Container status:${NC}"
podman ps --filter pod=devops-portfolio

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Access the application at:"
echo -e "  ${GREEN}Frontend:${NC} http://localhost:8081"
echo -e "  ${GREEN}Backend API:${NC} http://localhost:3001/api/health"
echo -e "  ${GREEN}PostgreSQL:${NC} localhost:5433"
echo ""
echo "Useful commands:"
echo "  podman pod ps                              # List pods"
echo "  podman ps --filter pod=devops-portfolio    # List containers in pod"
echo "  podman logs devops-frontend                # View frontend logs"
echo "  podman logs devops-backend                 # View backend logs"
echo "  podman logs devops-postgres                # View database logs"
echo "  podman pod stop devops-portfolio           # Stop the pod"
echo "  podman pod start devops-portfolio          # Start the pod"
echo "  podman pod rm -f devops-portfolio          # Remove the pod"
echo ""
echo "Test the deployment:"
echo "  curl http://localhost:8081/api/health"
echo "  curl http://localhost:8081/api/items"
