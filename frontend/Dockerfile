# Multi-stage build for React frontend
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first (for better Docker layer caching)
COPY package*.json ./

# Install ALL dependencies with error handling for ARM64
RUN npm install || (echo "First install failed, retrying..." && rm -rf node_modules package-lock.json && npm install)

# Copy source code
COPY . .

# Build argument for API URL
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=$VITE_API_URL

# Build the React app with retry logic
RUN npm run build || (echo "Build failed, cleaning and retrying..." && rm -rf node_modules package-lock.json && npm install && npm run build)

# Production stage - only runtime dependencies
FROM nginx:stable-alpine

# Copy built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
