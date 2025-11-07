# Frontend Dockerfile
# Multi-stage build with NGINX

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files from application directory
COPY application/frontend/package*.json ./

# Install dependencies (disable strict SSL for local development)
RUN npm config set strict-ssl false && \
    npm install && npm cache clean --force

# Copy source code from application directory
COPY application/frontend/ .

# Build application (if using build tool like webpack)
# RUN npm run build

# Production stage with NGINX
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config (from docker/frontend directory)
COPY docker/frontend/nginx.conf /etc/nginx/conf.d/

# Copy built application (or static files)
COPY --from=builder /app/public /usr/share/nginx/html

# Add health check script
RUN echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'curl -f http://localhost/health || exit 1' >> /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Install curl for health check
RUN apk add --no-cache curl

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /healthcheck.sh

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
