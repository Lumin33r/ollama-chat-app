# Multi-stage build
FROM node:18-alpine AS builder

WORKDIR /src

# Copy package files
COPY package*.json ./

# Install dependencies with retry for ARM64
RUN npm install || (echo "Retrying..." && rm -rf node_modules package-lock.json && npm install)

# Copy source code
COPY . .

# Build argument for API URL
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=$VITE_API_URL

# Build React app
RUN npm run build || (echo "Build failed, retrying..." && rm -rf node_modules && npm install && npm run build)

# Production stage
FROM nginx:stable-alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
