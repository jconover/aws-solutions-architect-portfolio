# Backend Dockerfile
# Multi-stage build for Node.js application

FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files from application directory
COPY application/backend/package*.json ./

# Install dependencies (disable strict SSL for local development)
RUN npm config set strict-ssl false && \
    npm install --only=production && \
    npm cache clean --force

# Production stage
FROM node:18-alpine

# Add non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code from application directory
COPY --chown=nodejs:nodejs application/backend/ .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "server.js"]
