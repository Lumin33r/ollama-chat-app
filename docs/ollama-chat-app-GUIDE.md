# Ollama Chat App - Complete Development to Production Guide

**Project Goal**: Build a full-stack AI chat application with React frontend, Flask backend, Ollama AI model server, containerized deployment, and production-ready AWS infrastructure.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture Overview - Microservices Containerization](#architecture-overview---microservices-containerization)
  - [Containerized Microservices Architecture (Production-Ready)](#containerized-microservices-architecture-production-ready)
  - [Architecture Components](#architecture-components)
  - [Service Communication Flow](#service-communication-flow)
  - [Deployment Architecture (AWS/Production)](#deployment-architecture-awsproduction)
  - [Why Separate Containers? (Best Practices)](#why-separate-containers-best-practices)
- [Converting Local Development to Containers](#converting-local-development-to-containers)
- [Project Structure (Updated for Containers)](#project-structure-updated-for-containers)
- [Environment Configuration Architecture](#environment-configuration-architecture)
  - [Overview: Environment-Based Configuration Strategy](#overview-environment-based-configuration-strategy)
  - [Frontend Environment Configuration](#frontend-environment-configuration)
  - [Environment Variable Flow](#environment-variable-flow)
  - [Docker Compose Integration](#docker-compose-integration)
  - [Security Best Practices](#security-best-practices)
  - [Troubleshooting Environment Issues](#troubleshooting-environment-issues)
  - [Verification Commands](#verification-commands)
  - [Environment Configuration Summary](#environment-configuration-summary)
- [Docker Compose Implementation](#docker-compose-implementation)
- [Understanding Docker Compose Files](#understanding-docker-compose-files)
  - [Base Configuration: docker-compose.yml](#base-configuration-docker-composeyml)
  - [Development Configuration: docker-compose.dev.yml](#development-configuration-docker-composedevyml)
  - [Production Configuration: docker-compose.prod.yml](#production-configuration-docker-composeprodyml)
  - [Build Optimization: .dockerignore](#build-optimization-dockerignore)
  - [Working with Multiple Compose Files](#working-with-multiple-compose-files)
- [Building Docker Images](#building-docker-images)
  - [Build All Services](#build-all-services)
  - [Build Individual Services](#build-individual-services)
  - [Verify Built Images](#verify-built-images)
  - [Rebuild After Code Changes](#rebuild-after-code-changes)
  - [Troubleshooting Build Issues](#troubleshooting-build-issues)
- [Migration Steps: Local → Containers](#migration-steps-local--containers)
- [Phase 1: Project Setup & Development Environment](#phase-1-project-setup--development-environment)
- [Phase 2: Frontend Development (React + Vite)](#phase-2-frontend-development-react--vite)
- [Phase 3: Backend Development (Flask + Ollama)](#phase-3-backend-development-flask--ollama)
- [Phase 4: Multi-Platform Docker & Container Registry](#phase-4-multi-platform-docker--container-registry)
- [Phase 5: AWS Infrastructure with Terraform](#phase-5-aws-infrastructure-with-terraform)
- [Phase 6: CI/CD Pipeline with GitHub Actions](#phase-6-cicd-pipeline-with-github-actions)
- [Phase 7: Monitoring, Security & Operations](#phase-7-monitoring-security--operations)
- [Phase 8: Testing & Validation](#phase-8-testing--validation)
- [Implementation Checklist](#implementation-checklist)
- [Quick Start Commands](#quick-start-commands)
- [Docker Compose Command Reference](#docker-compose-command-reference)
- [Testing the Containerized Setup](#testing-the-containerized-setup)
- [Troubleshooting Containers](#troubleshooting-containers)
- [Comparing Local vs Containerized Development](#comparing-local-vs-containerized-development)
- [Best Practices for Containerized Development](#best-practices-for-containerized-development)
- [Deployment Workflow](#deployment-workflow)
- [Migration Checklist](#migration-checklist)
- [Related Documentation](#related-documentation)
- [Decision Points & Customization Options](#decision-points--customization-options)

---

## Project Overview

This guide walks through building `ollama-chat-app` under `codeplatoon/projects/` with:

- **Frontend**: React (Vite) Single Page App (SPA) communicating with Flask API
- **Backend**: Flask API forwarding requests to local Ollama instance
- **AI Engine**: Ollama running on private EC2 instances with EBS storage (≥20GB)
- **Containerization**: Multi-platform Docker images (amd64 & arm64) on GitHub Container Registry
- **Infrastructure**: AWS VPC with Terraform (public/private subnets, ALB, ASG, security layers)
- **CI/CD**: GitHub Actions for automated builds and deployments

---

## Architecture Overview - Microservices Containerization

### **Containerized Microservices Architecture (Production-Ready)**

This application follows a **microservices architecture** with separate containers for each service, orchestrated via Docker Compose for simplified deployment across any environment.

```
┌─────────────────────────────────────────────────────────────┐
│                       Docker Network                         │
│                    (ollama-network)                          │
│                                                              │
│  ┌────────────────────┐         ┌────────────────────┐     │
│  │  Ollama Container  │         │ Backend Container  │     │
│  │                    │         │                    │     │
│  │  - Ollama Service  │◄────────│  - Flask API      │     │
│  │  - AI Models       │         │  - Gunicorn       │     │
│  │  - Port: 11434     │         │  - Port: 8000     │     │
│  │  - Volume: models  │         │  - Connects to    │     │
│  │                    │         │    ollama:11434   │     │
│  └────────────────────┘         └─────────┬──────────┘     │
│           │                               │                 │
│           │                               │                 │
│           ▼                               ▼                 │
│  ┌─────────────────────────────────────────────────┐       │
│  │         Frontend Container (nginx)              │       │
│  │                                                  │       │
│  │  - React SPA (Built)                           │       │
│  │  - Nginx Static Server                         │       │
│  │  - Port: 3000 → 80                             │       │
│  │  - Proxies API requests to backend:8000        │       │
│  └─────────────────────────────────────────────────┘       │
│                            │                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             ▼
                    Internet (Users)
```

### **Architecture Components**

#### **1. Ollama Service Container**

```
┌──────────────────────────────────┐
│   ollama/ollama:latest           │
│                                  │
│   Service: Ollama AI Engine      │
│   Port: 11434                    │
│   Volume: ollama-models          │
│   Network: ollama-network        │
│                                  │
│   Responsibilities:              │
│   • Load and serve AI models     │
│   • Process inference requests   │
│   • Model management (pull/list) │
│   • Persistent model storage     │
│                                  │
│   Health: /api/tags              │
└──────────────────────────────────┘
```

#### **2. Backend Flask API Container**

```
┌──────────────────────────────────┐
│   ollama-backend:latest          │
│   (Python 3.11 + Flask)          │
│                                  │
│   Service: Flask API Server      │
│   Port: 8000                     │
│   Network: ollama-network        │
│                                  │
│   Responsibilities:              │
│   • REST API endpoints           │
│   • Request validation           │
│   • Ollama service proxy         │
│   • Session management           │
│   • CORS handling                │
│                                  │
│   Environment:                   │
│   • OLLAMA_HOST=ollama-service   │
│   • OLLAMA_PORT=11434            │
│                                  │
│   Health: /health                │
└──────────────────────────────────┘
```

#### **3. Frontend React SPA Container**

```
┌──────────────────────────────────┐
│   ollama-frontend:latest         │
│   (nginx + React build)          │
│                                  │
│   Service: Web Interface         │
│   Port: 3000 (exposed as 80)     │
│   Network: ollama-network        │
│                                  │
│   Responsibilities:              │
│   • Serve React SPA              │
│   • Static asset delivery        │
│   • Client-side routing          │
│   • API request proxying         │
│                                  │
│   Nginx Config:                  │
│   • / → React SPA                │
│   • /api → backend:8000          │
└──────────────────────────────────┘
```

### **Service Communication Flow**

```
User Browser
    │
    │ 1. HTTP Request (localhost:3000)
    ↓
┌─────────────────┐
│  Frontend       │
│  (nginx:80)     │
└────────┬────────┘
         │
         │ 2. API Request (/api/chat)
         ↓
┌─────────────────┐
│  Backend        │
│  (Flask:8000)   │
└────────┬────────┘
         │
         │ 3. Chat Request (ollama-service:11434/api/chat)
         ↓
┌─────────────────┐
│  Ollama         │
│  (Service:11434)│
└────────┬────────┘
         │
         │ 4. AI Response
         ↓
      Backend
         │
         │ 5. JSON Response
         ↓
     Frontend
         │
         │ 6. Display to User
         ↓
    User Browser
```

### **Deployment Architecture (AWS/Production)**

```
┌────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                VPC (10.0.0.0/16)                          │  │
│  │                                                           │  │
│  │  ┌───────────────────────────────────────────────────┐   │  │
│  │  │          Public Subnets (AZ-1, AZ-2)             │   │  │
│  │  │                                                   │   │  │
│  │  │  ┌────────────────────────────────────┐          │   │  │
│  │  │  │   Application Load Balancer        │          │   │  │
│  │  │  │   (Internet-facing)                │          │   │  │
│  │  │  └───────────┬────────────────────────┘          │   │  │
│  │  │              │                                    │   │  │
│  │  │              │ Route /api/* to Backend           │   │  │
│  │  │              │ Route /* to Frontend              │   │  │
│  │  └──────────────┼────────────────────────────────────┘   │  │
│  │                 │                                         │  │
│  │  ┌──────────────┼────────────────────────────────────┐   │  │
│  │  │              ↓      Private Subnets               │   │  │
│  │  │  ┌─────────────────────────────────────────┐     │   │  │
│  │  │  │   EC2 Auto Scaling Group (Backend)      │     │   │  │
│  │  │  │                                          │     │   │  │
│  │  │  │   Docker Containers:                    │     │   │  │
│  │  │  │   ┌────────────┐   ┌────────────┐      │     │   │  │
│  │  │  │   │  Ollama    │   │  Backend   │      │     │   │  │
│  │  │  │   │ Container  │◄──│ Container  │      │     │   │  │
│  │  │  │   │  :11434    │   │  :8000     │      │     │   │  │
│  │  │  │   └────────────┘   └────────────┘      │     │   │  │
│  │  │  │                                          │     │   │  │
│  │  │  └─────────────────────────────────────────┘     │   │  │
│  │  │                                                   │   │  │
│  │  │  ┌─────────────────────────────────────────┐     │   │  │
│  │  │  │   EC2 Auto Scaling Group (Frontend)     │     │   │  │
│  │  │  │                                          │     │   │  │
│  │  │  │   Docker Container:                     │     │   │  │
│  │  │  │   ┌────────────┐                        │     │   │  │
│  │  │  │   │  Frontend  │                        │     │   │  │
│  │  │  │   │ Container  │                        │     │   │  │
│  │  │  │   │  :80       │                        │     │   │  │
│  │  │  │   └────────────┘                        │     │   │  │
│  │  │  └─────────────────────────────────────────┘     │   │  │
│  │  │                                                   │   │  │
│  │  └───────────────────────────────────────────────────┘   │  │
│  │                                                           │  │
│  │  Persistent Storage:                                      │  │
│  │  └─ EBS Volume: /root/.ollama (Ollama models)           │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### **Why Separate Containers? (Best Practices)**

#### **Advantages:**

✅ **Independent Scaling** - Scale Ollama, backend, and frontend independently
✅ **Resource Isolation** - Each service has dedicated CPU/memory limits
✅ **Easier Updates** - Update one service without affecting others
✅ **Better Monitoring** - Track metrics per service
✅ **Fault Isolation** - Service failure doesn't crash entire stack
✅ **Development Flexibility** - Work on services independently
✅ **Security** - Minimize attack surface per container
✅ **Reusability** - Share Ollama container across multiple backends

#### **Container Benefits:**

- **Portability**: Same containers run locally, staging, and production
- **Consistency**: Eliminates "works on my machine" issues
- **Version Control**: Infrastructure as Code with Dockerfiles
- **Rapid Deployment**: Start entire stack with one command
- **Easy Rollbacks**: Revert to previous container versions instantly

---

## Converting Local Development to Containers

### **Step-by-Step Migration Guide**

#### **Current Local Architecture:**

```
Terminal 1: ollama serve              (Port 11434)
Terminal 2: python backend/app.py     (Port 8000)
Terminal 3: npm run dev (frontend)    (Port 3000)
```

#### **Target Containerized Architecture:**

```
docker-compose up
  ├── ollama-service container    (Port 11434)
  ├── backend container            (Port 8000)
  └── frontend container           (Port 3000)
```

---

## Project Structure (Updated for Containers)

```
projects/ollama-chat-app/
├── frontend/                    # React + Vite application
│   ├── src/
│   │   ├── components/         # React components
│   │   │   └── ChatInterface.jsx
│   │   ├── services/           # 🆕 Centralized services
│   │   │   └── api.js          # 🆕 Axios API configuration
│   │   └── App.jsx
│   ├── .env.development        # 🆕 Development environment config
│   ├── .env.production         # 🆕 Production environment template
│   ├── .env.example            # 🆕 Documentation template
│   ├── .gitignore              # 🆕 Updated with .env rules
│   ├── package.json
│   ├── vite.config.js
│   ├── Dockerfile              # Multi-stage: build → nginx
│   ├── Dockerfile.dev          # Development hot-reload version
│   ├── nginx.conf              # Production nginx configuration
│   └── README.md
├── backend/                     # Flask API server
│   ├── app.py                  # Main Flask application
│   ├── ollama_connector.py     # Ollama API wrapper
│   ├── requirements.txt
│   ├── Dockerfile              # Python + gunicorn
│   └── README.md
├── docker-compose.yml          # 🆕 Multi-service orchestration
├── docker-compose.dev.yml      # 🆕 Development overrides
├── docker-compose.prod.yml     # 🆕 Production configuration
├── .dockerignore               # 🆕 Docker build exclusions
├── scripts/                    # 🆕 Helper scripts
│   ├── start-dev.sh           # Start development environment
│   ├── stop-dev.sh            # Stop all services
│   └── ensure-models.sh       # Pull required Ollama models
├── infra/                      # Terraform infrastructure
│   ├── modules/
│   │   ├── vpc/               # VPC, subnets, IGW, NAT
│   │   ├── alb/               # Application Load Balancer
│   │   ├── ec2/               # Launch templates
│   │   ├── asg/               # Auto Scaling Groups
│   │   ├── security/          # Security Groups & NACLs
│   │   ├── iam/               # IAM roles & policies
│   │   └── outputs/           # Terraform outputs
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       ├── ci.yml             # Build & push images
│       └── deploy.yml         # Deployment automation
├── docs/
│   ├── ARCHITECTURE_DIAGRAM.drawio
│   ├── ARCHITECTURE_DIAGRAM.png
│   ├── DEPLOYMENT_GUIDE.md
│   └── SECURITY_GUIDE.md
└── README.md
```

---

## Environment Configuration Architecture

### **Overview: Environment-Based Configuration Strategy**

The application uses a **layered configuration approach** that separates environment-specific settings from code, enabling seamless transitions between development, staging, and production environments.

```
Configuration Hierarchy:
┌─────────────────────────────────────────────┐
│  Application Layer (React Components)       │
│  └─ Uses: import.meta.env.VITE_API_URL     │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  API Service Layer (src/services/api.js)    │
│  └─ Configures: axios baseURL from env     │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  Environment Files (.env.*)                 │
│  ├─ .env.development  (local dev)          │
│  ├─ .env.production   (cloud deploy)       │
│  └─ .env.example      (documentation)      │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  Docker Compose (runtime injection)         │
│  └─ Passes: VITE_API_URL to containers     │
└─────────────────────────────────────────────┘
```

### **Frontend Environment Configuration**

#### **1. Environment Files Structure**

```
frontend/
├── .env.development      # Development settings (committed)
├── .env.production       # Production template (committed)
├── .env.example          # Documentation (committed)
├── .env                  # Local overrides (gitignored)
├── .env.local            # Local secrets (gitignored)
├── .gitignore            # Excludes sensitive .env files
└── src/
    └── services/
        └── api.js        # Centralized API service
```

#### **2. Environment File Contents**

**`.env.development`** - Local Development Configuration

```bash
# Development API endpoint (backend container)
VITE_API_URL=http://localhost:8000

# Application name for dev environment
VITE_APP_NAME=Ollama Chat (Dev)

# Enable debug mode (optional)
VITE_DEBUG=true
```

**`.env.production`** - Production Template

```bash
# Production API endpoint (cloud/AWS deployment)
VITE_API_URL=https://api.yourdomain.com

# Application name for production
VITE_APP_NAME=Ollama Chat

# Disable debug in production
VITE_DEBUG=false
```

**`.env.example`** - Documentation for Developers

```bash
# Example environment configuration
# Copy this file to .env.development or .env.production and customize

# API Base URL - Points to Flask backend
VITE_API_URL=http://localhost:8000

# Application Display Name
VITE_APP_NAME=Ollama Chat

# Debug Mode (true/false)
VITE_DEBUG=false
```

#### **3. Centralized API Service**

**`frontend/src/services/api.js`** - Single Source of Truth for API Communication

```javascript
import axios from "axios";

// Get API URL from environment variable
// Vite exposes env vars prefixed with VITE_ via import.meta.env
const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";

// Create axios instance with base configuration
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 120000, // 120 seconds for AI model responses
});

// Request interceptor - logs outgoing requests
api.interceptors.request.use(
  (config) => {
    console.log(
      `🚀 API Request: ${config.method?.toUpperCase()} ${config.baseURL}${
        config.url
      }`
    );
    return config;
  },
  (error) => {
    console.error("❌ API Request Error:", error);
    return Promise.reject(error);
  }
);

// Response interceptor - logs responses and handles errors
api.interceptors.response.use(
  (response) => {
    console.log(`✅ API Response: ${response.config.url}`, response.data);
    return response;
  },
  (error) => {
    console.error(
      "❌ API Response Error:",
      error.response?.data || error.message
    );
    return Promise.reject(error);
  }
);

export default api;
```

**Key Features:**

- **Centralized Configuration**: Single place to manage API settings
- **Environment Awareness**: Automatically uses correct API URL per environment
- **Request/Response Logging**: Debug-friendly console output
- **Error Handling**: Consistent error format across the app
- **Timeout Management**: 120s timeout for long-running AI requests

#### **4. Component Usage Pattern**

**Before (Problematic Approach):**

```javascript
// ❌ BAD: Direct axios with relative URL
import axios from "axios";

const response = await axios.post("/api/chat", data);
// Problem: Calls http://localhost:3000/api/chat (frontend port)
```

**After (Correct Approach):**

```javascript
// ✅ GOOD: Use centralized API service
import api from "../services/api";

const response = await api.post("/api/chat", {
  prompt: userMessage,
  model: "llama2",
  messages: conversationHistory,
});
// Correctly calls http://localhost:8000/api/chat (backend port)
```

### **Environment Variable Flow**

#### **Development Workflow**

```
1. Developer sets .env.development
   └─ VITE_API_URL=http://localhost:8000

2. Vite dev server loads environment
   └─ import.meta.env.VITE_API_URL available

3. API service reads environment
   └─ API_BASE_URL = import.meta.env.VITE_API_URL

4. Components import API service
   └─ api.post('/api/chat', ...) → http://localhost:8000/api/chat

5. Docker Compose injects environment
   └─ docker-compose.dev.yml sets VITE_API_URL
```

#### **Production Workflow**

```
1. Build-time: Docker reads .env.production
   └─ ARG VITE_API_URL=https://api.yourdomain.com

2. Build-time: ENV var baked into image
   └─ ENV VITE_API_URL=$VITE_API_URL

3. Build-time: Vite bundles with env vars
   └─ npm run build (VITE_API_URL embedded in JS)

4. Runtime: nginx serves static bundle
   └─ API calls go to https://api.yourdomain.com
```

### **Docker Compose Integration**

#### **Development Configuration**

```yaml
# docker-compose.dev.yml
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
      args:
        - VITE_API_URL=http://localhost:8000 # Build argument
    environment:
      - VITE_API_URL=http://localhost:8000 # Runtime environment
      - NODE_ENV=development
    volumes:
      - ./frontend:/app
      - /app/node_modules
    ports:
      - "3000:3000"
      - "24678:24678" # Vite HMR WebSocket
```

**Why Both `args` and `environment`?**

- **`args`**: Passed to Dockerfile during `docker build` (for multi-stage builds)
- **`environment`**: Available in running container (for Vite dev server)

#### **Production Configuration**

```yaml
# docker-compose.prod.yml
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        # Inject from host environment or use default
        - VITE_API_URL=${API_URL:-https://api.yourdomain.com}
    environment:
      - NODE_ENV=production
    ports:
      - "80:80"
      - "443:443"
```

**Production Deployment:**

```bash
# Set production API URL before building
export API_URL=https://api.yourcompany.com

# Build with production config
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Deploy
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### **Security Best Practices**

#### **.gitignore Configuration**

```gitignore
# Frontend .gitignore
node_modules/
dist/
build/

# Environment variables - CRITICAL SECURITY
.env                      # ❌ Never commit (local overrides)
.env.local                # ❌ Never commit (local secrets)
.env.development.local    # ❌ Never commit (dev secrets)
.env.production.local     # ❌ Never commit (prod secrets)

# Keep these for documentation
!.env.example             # ✅ Commit (template)
!.env.development         # ✅ Commit (dev config)
!.env.production          # ✅ Commit (prod template)
```

**Why This Approach?**

- ✅ **Shared Defaults**: Team uses same dev/prod configs
- ✅ **Local Overrides**: Developers can customize without affecting others
- ✅ **No Secrets in Git**: API keys, tokens never committed
- ✅ **Documentation**: .env.example shows all available options

### **Troubleshooting Environment Issues**

#### **Issue 1: Frontend Calls Wrong URL**

**Symptom:** Browser console shows `http://localhost:3000/api/chat` instead of `http://localhost:8000/api/chat`

**Solution:**

```bash
# 1. Check environment file exists
ls -la frontend/.env.development

# 2. Verify content
cat frontend/.env.development
# Should show: VITE_API_URL=http://localhost:8000

# 3. Restart Vite dev server
docker-compose -f docker-compose.yml -f docker-compose.dev.yml restart frontend

# 4. Check in browser console
# Should see: 🚀 API Request: POST http://localhost:8000/api/chat
```

#### **Issue 2: Environment Variable Not Loading**

**Symptom:** `import.meta.env.VITE_API_URL` is undefined

**Causes & Fixes:**

```bash
# Cause 1: Missing VITE_ prefix
# ❌ API_URL=http://localhost:8000
# ✅ VITE_API_URL=http://localhost:8000

# Cause 2: Server not restarted after .env change
docker-compose -f docker-compose.yml -f docker-compose.dev.yml restart frontend

# Cause 3: .env file not in correct location
# ✅ frontend/.env.development (correct)
# ❌ frontend/src/.env.development (wrong)

# Cause 4: Syntax error in .env file
# ❌ VITE_API_URL = http://localhost:8000  (spaces around =)
# ✅ VITE_API_URL=http://localhost:8000   (no spaces)
```

#### **Issue 3: Production Build Using Dev URL**

**Symptom:** Production deployment calls `http://localhost:8000` instead of production URL

**Solution:**

```bash
# Option 1: Update .env.production
cat > frontend/.env.production << EOF
VITE_API_URL=https://api.yourcompany.com
VITE_APP_NAME=Ollama Chat
EOF

# Option 2: Pass at build time
docker build --build-arg VITE_API_URL=https://api.yourcompany.com \
  -f frontend/Dockerfile \
  -t ollama-frontend:prod \
  frontend/

# Option 3: Use docker-compose with environment variable
API_URL=https://api.yourcompany.com \
  docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
```

### **Verification Commands**

```bash
# Check environment in running container
docker exec ollama-frontend printenv | grep VITE

# Check build-time arguments
docker inspect ollama-frontend | jq '.[0].Config.Env'

# Check .env files are correct
cat frontend/.env.development
cat frontend/.env.production

# Test API service in browser console
fetch('http://localhost:8000/health')
  .then(r => r.json())
  .then(console.log)
```

### **Environment Configuration Summary**

| File               | Purpose              | Committed to Git | Used When                          |
| ------------------ | -------------------- | ---------------- | ---------------------------------- |
| `.env.development` | Default dev settings | ✅ Yes           | `npm run dev` or dev Docker        |
| `.env.production`  | Production template  | ✅ Yes           | Production build                   |
| `.env.example`     | Documentation        | ✅ Yes           | Reference for developers           |
| `.env`             | Local overrides      | ❌ No            | Any environment (highest priority) |
| `.env.local`       | Local secrets        | ❌ No            | Any environment (sensitive data)   |
| `.env.*.local`     | Env-specific secrets | ❌ No            | Specific environment secrets       |

**Priority Order (Vite):**

1. `.env.local` (highest priority)
2. `.env.[mode].local` (e.g., `.env.development.local`)
3. `.env.[mode]` (e.g., `.env.development`)
4. `.env` (lowest priority)

---

## Docker Compose Implementation

### **Complete Docker Compose Configuration**

Create `docker-compose.yml` in project root:

```yaml
version: "3.8"

# Shared network for all services
networks:
  ollama-network:
    driver: bridge

# Persistent volumes
volumes:
  ollama-models:
    driver: local

services:
  # Ollama AI Service
  ollama-service:
    image: ollama/ollama:latest
    container_name: ollama-service
    ports:
      - "11434:11434"
    volumes:
      # Persist models between container restarts
      - ollama-models:/root/.ollama
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    networks:
      - ollama-network

  # Backend Flask API
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ollama-backend
    ports:
      - "8000:8000"
    environment:
      # Connect to ollama-service via Docker network
      OLLAMA_HOST: ollama-service
      OLLAMA_PORT: 11434
      FLASK_ENV: production
      FLASK_DEBUG: "False"
    depends_on:
      ollama-service:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - ollama-network

  # Frontend React SPA
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        VITE_API_URL: http://localhost:8000
    container_name: ollama-frontend
    ports:
      - "3000:80"
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - ollama-network
```

### **Development Override: docker-compose.dev.yml**

```yaml
version: "3.8"

services:
  # Development backend with hot-reload
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    volumes:
      # Mount source code for hot-reload
      - ./backend:/app
    environment:
      FLASK_ENV: development
      FLASK_DEBUG: "True"
    command: python app.py

  # Development frontend with Vite dev server
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    volumes:
      # Mount source code for hot-reload
      - ./frontend:/app
      - /app/node_modules
    environment:
      VITE_API_URL: http://localhost:8000
    ports:
      - "3000:3000"
    command: npm run dev
```

### **Production Configuration: docker-compose.prod.yml**

```yaml
version: "3.8"

services:
  ollama-service:
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  backend:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
      replicas: 2
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  frontend:
    deploy:
      resources:
        limits:
          memory: 512M
      replicas: 2
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## Understanding Docker Compose Files

This section provides a comprehensive explanation of the multi-file Docker Compose strategy used in this project. Understanding these files is crucial for managing development, testing, and production environments effectively.

### **Overview: Multi-File Compose Strategy**

The project uses a **layered Docker Compose configuration** approach with three files:

1. **`docker-compose.yml`** - Base configuration (shared across all environments)
2. **`docker-compose.dev.yml`** - Development-specific overrides (hot-reload, debug mode)
3. **`docker-compose.prod.yml`** - Production-specific overrides (resource limits, replicas)

**Why Multiple Files?**

- **DRY Principle**: Define common configuration once in the base file
- **Environment Flexibility**: Override specific settings per environment without duplication
- **Maintainability**: Changes to shared configuration automatically propagate to all environments
- **Clear Separation**: Development and production concerns are isolated

**How to Use Multiple Compose Files:**

```bash
# Development (base + dev overrides)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Production (base + prod overrides)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Base only (not recommended for actual use)
docker-compose up
```

---

### **Base Configuration: docker-compose.yml**

**Purpose**: Defines the core service definitions, networks, volumes, and default configurations that apply to ALL environments.

#### **Key Sections Explained**

##### **1. Version and Networks**

```yaml
version: "3.8"

networks:
  ollama-network:
    driver: bridge
```

- **`version: "3.8"`**: Specifies Docker Compose file format version. Version 3.8 supports all modern features including health checks, resource limits, and deploy configurations.
- **`networks.ollama-network`**: Creates a custom bridge network for service communication.
  - **Why?** Isolated network allows services to discover each other by container name (e.g., `ollama-service:11434`)
  - **Bridge driver**: Default Docker network type, suitable for single-host deployments
  - **Service Discovery**: Containers can reference each other using service names as hostnames

##### **2. Volumes**

```yaml
volumes:
  ollama-models:
    driver: local
```

- **`ollama-models` volume**: Persistent storage for AI models (~4GB per model)
  - **Purpose**: Survive container restarts/deletions. Without this, you'd re-download models every time
  - **`driver: local`**: Stores data on host machine's filesystem (typically `/var/lib/docker/volumes/`)
  - **Mounting**: Later mapped to `/root/.ollama` inside the `ollama-service` container

##### **3. Ollama Service**

```yaml
services:
  ollama-service:
    image: ollama/ollama:latest
    container_name: ollama-service
    ports:
      - "11434:11434"
    volumes:
      - ollama-models:/root/.ollama
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    networks:
      - ollama-network
```

**Field-by-Field Breakdown:**

- **`image: ollama/ollama:latest`**

  - Uses official Ollama image from Docker Hub
  - **`latest` tag**: Always pulls most recent version (consider pinning versions in production: `ollama/ollama:v0.1.26`)

- **`container_name: ollama-service`**

  - Explicit container name (instead of auto-generated `project-ollama-service-1`)
  - **Service Discovery**: Backend references this via `OLLAMA_HOST=ollama-service`

- **`ports: ["11434:11434"]`**

  - **Format**: `HOST_PORT:CONTAINER_PORT`
  - **Purpose**: Expose Ollama API on host machine's port 11434
  - **When needed**: Direct host access for testing, or if services outside Docker need access

- **`volumes: [ollama-models:/root/.ollama]`**

  - Mounts named volume to Ollama's default model storage path
  - **Data persists** even if container is removed

- **`restart: unless-stopped`**

  - **Policy**: Auto-restart on failure, but not if manually stopped
  - **Alternatives**:
    - `always`: Restart even after manual stop (aggressive)
    - `on-failure`: Only restart on crash (less robust)
    - `no`: Never auto-restart (development debugging)

- **`healthcheck`**

  - **Purpose**: Docker monitors service readiness
  - **`test`**: Command to verify service is healthy (checks `/api/tags` endpoint)
  - **`interval: 30s`**: Check every 30 seconds
  - **`timeout: 10s`**: Consider unhealthy if check takes >10s
  - **`retries: 3`**: Mark unhealthy after 3 consecutive failures
  - **`start_period: 20s`**: Grace period during startup (don't mark unhealthy immediately)
  - **Why it matters**: `depends_on: condition: service_healthy` ensures backend waits for Ollama to be truly ready

- **`networks: [ollama-network]`**
  - Connects container to custom network for inter-service communication

##### **4. Backend Service**

```yaml
backend:
  build:
    context: ./backend
    dockerfile: Dockerfile
  container_name: ollama-backend
  ports:
    - "8000:8000"
  environment:
    OLLAMA_HOST: ollama-service
    OLLAMA_PORT: 11434
    FLASK_ENV: production
    FLASK_DEBUG: "False"
  depends_on:
    ollama-service:
      condition: service_healthy
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
  networks:
    - ollama-network
```

**Key Differences from Ollama Service:**

- **`build` vs `image`**

  - **`build.context: ./backend`**: Path to directory containing Dockerfile
  - **`build.dockerfile: Dockerfile`**: Specific Dockerfile to use (default is `Dockerfile`)
  - **When to use `build`**: Custom application code. **When to use `image`**: Pre-built images from registries

- **`environment` variables**

  - **`OLLAMA_HOST: ollama-service`**: Critical! Uses Docker network hostname instead of `localhost`
  - **Why?** Each container has its own `localhost`. Services communicate via network hostnames.
  - **`FLASK_ENV: production`**: Disables debug mode, optimizes for performance

- **`depends_on` with health check**
  ```yaml
  depends_on:
    ollama-service:
      condition: service_healthy
  ```
  - **Without `condition`**: Docker only waits for container to start (not ready to accept requests)
  - **With `condition: service_healthy`**: Docker waits until health check passes
  - **Result**: Backend won't start until Ollama is truly ready, preventing connection errors

##### **5. Frontend Service**

```yaml
frontend:
  build:
    context: ./frontend
    dockerfile: Dockerfile
    args:
      VITE_API_URL: http://localhost:8000
  container_name: ollama-frontend
  ports:
    - "3000:80"
  depends_on:
    - backend
  restart: unless-stopped
  networks:
    - ollama-network
```

**Notable Configurations:**

- **`build.args`**

  - **Purpose**: Pass build-time variables to Dockerfile
  - **`VITE_API_URL`**: Injected during `npm run build` step in Dockerfile
  - **Why build-time?** React apps are static files after build; API URL must be "baked in"

- **`ports: ["3000:80"]`**

  - **Mapping**: Host port 3000 → Container port 80 (nginx default)
  - **Access**: Browse to `http://localhost:3000` on host machine

- **`depends_on: [backend]`**
  - **Simple dependency**: No health check (frontend doesn't directly connect to backend during startup)
  - **Why?** nginx just serves static files. Backend connectivity is handled by browser API calls

---

### **Development Configuration: docker-compose.dev.yml**

**Purpose**: Override base configuration for **local development** with features like hot-reload, debug mode, and volume mounting for live code updates.

#### **Complete Development Override File**

```yaml
version: "3.8"

services:
  # Ollama: No changes needed for dev
  ollama-service:
    # Inherit all settings from docker-compose.yml
    # (No overrides required)

  # Backend: Enable debug mode + volume mounting for hot-reload
  backend:
    environment:
      FLASK_ENV: development
      FLASK_DEBUG: "True"
      FLASK_APP: app.py
    volumes:
      # Mount local code directory into container
      - ./backend:/app
    restart: "no" # Don't auto-restart (easier debugging)
    command: python app.py # Flask dev server instead of gunicorn

  # Frontend: Use Vite dev server with hot-reload
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev # Different Dockerfile for dev
    volumes:
      # Mount source code for live updates
      - ./frontend:/app
      # Exclude node_modules (use container's version)
      - /app/node_modules
    environment:
      VITE_API_URL: http://localhost:8000
    ports:
      - "3000:3000" # Vite dev server default port
    command: npm run dev # Vite dev server with HMR
    restart: "no"
```

#### **Development Overrides Explained**

##### **Backend Development Overrides**

```yaml
backend:
  environment:
    FLASK_ENV: development # Enables debug features
    FLASK_DEBUG: "True" # Auto-reload on code changes
    FLASK_APP: app.py # Entry point for Flask CLI
  volumes:
    - ./backend:/app # Live code mounting
  restart: "no" # Manual restart only
  command: python app.py # Dev server (not gunicorn)
```

**Key Development Features:**

1. **`FLASK_DEBUG: "True"`**

   - **Auto-reload**: Flask detects code changes and restarts automatically
   - **Detailed errors**: Stack traces in browser/API responses
   - **Interactive debugger**: Can inspect variables in error pages

2. **`volumes: [./backend:/app]`**

   - **Bind mount**: Host directory (`./backend`) → Container path (`/app`)
   - **Effect**: Edit code on host → Immediately available in container → Flask auto-reloads
   - **No rebuild needed**: Changes reflected instantly (unlike `COPY` in Dockerfile)

3. **`restart: "no"`**

   - **Why?** During debugging, you may want the container to stop on errors
   - **Production difference**: `unless-stopped` in base config ensures resilience

4. **`command: python app.py`**
   - **Overrides** `CMD` from Dockerfile (which uses gunicorn in production)
   - **Flask dev server**: Single-threaded, auto-reloading, better error messages
   - **Not for production**: Dev server is not thread-safe or performant

##### **Frontend Development Overrides**

```yaml
frontend:
  build:
    dockerfile: Dockerfile.dev # Different build process
  volumes:
    - ./frontend:/app # Mount source code
    - /app/node_modules # Exclude node_modules
  environment:
    VITE_API_URL: http://localhost:8000
  ports:
    - "3000:3000" # Vite dev server port
  command: npm run dev # Vite HMR
```

**Development-Specific Features:**

1. **`Dockerfile.dev` vs `Dockerfile`**

   - **Production Dockerfile**: Multi-stage build → Optimized nginx static files
   - **Development Dockerfile**: Node.js + Vite dev server (no nginx)
   - **Example `Dockerfile.dev`:**
     ```dockerfile
     FROM node:18-alpine
     WORKDIR /app
     COPY package*.json ./
     RUN npm install
     EXPOSE 3000
     CMD ["npm", "run", "dev"]
     ```

2. **Volume Mounting Strategy**

   ```yaml
   volumes:
     - ./frontend:/app # Mount entire directory
     - /app/node_modules # EXCEPT node_modules
   ```

   - **Why exclude `node_modules`?**
     - Host and container may have different OS/architectures (e.g., macOS host, Linux container)
     - Native dependencies (like `esbuild`) might not be compatible
     - **Solution**: Use container's `node_modules`, but mount source code

3. **`npm run dev` with HMR**
   - **Vite Hot Module Replacement**: Changes to `.jsx` files reflect in browser instantly (no page reload)
   - **Port 3000**: Vite's default dev server port
   - **WebSocket**: Vite uses WebSocket for HMR communication (ensure firewall allows it)

---

### **Production Configuration: docker-compose.prod.yml**

**Purpose**: Optimize for **production deployment** with resource limits, logging, and scalability configurations.

#### **Complete Production Override File**

```yaml
version: "3.8"

services:
  ollama-service:
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G
    restart: always # More aggressive than unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  backend:
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          memory: 1G
      replicas: 2 # Scale to 2 instances
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    # Production uses gunicorn from Dockerfile CMD (no override)

  frontend:
    deploy:
      resources:
        limits:
          memory: 512M
      replicas: 2 # Load balancing across 2 containers
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

#### **Production Optimizations Explained**

##### **Resource Limits**

```yaml
deploy:
  resources:
    limits: # Maximum resources
      cpus: "2.0" # Max 2 CPU cores
      memory: 2G # Hard limit: 2GB RAM
    reservations: # Minimum guaranteed resources
      memory: 1G # Reserved: 1GB RAM
```

**Why Resource Limits Matter:**

1. **Prevent Resource Exhaustion**

   - **Without limits**: One container can consume all host resources
   - **With limits**: Docker enforces caps, preventing cascade failures

2. **`limits` vs `reservations`**

   - **`limits`**: Maximum cap (Docker kills process if exceeded)
   - **`reservations`**: Minimum guarantee (Docker scheduler ensures availability)
   - **Example**: Backend gets 1GB guaranteed, can burst to 2GB if available

3. **CPU Limits**

   - **`cpus: '2.0'`**: Use up to 2 full CPU cores
   - **String format required**: `'2.0'` not `2.0` (YAML parsing quirk)

4. **Memory Limits for AI Workloads**
   - **Ollama**: 4GB reserved, 8GB limit (AI models are memory-intensive)
   - **Backend**: 1GB reserved, 2GB limit (Flask + request handling)
   - **Frontend**: 512MB limit (nginx is lightweight)

##### **Scaling with Replicas**

```yaml
deploy:
  replicas: 2 # Run 2 instances of this service
```

**Scaling Strategies:**

1. **Backend Replicas**

   - **Load Distribution**: Multiple Flask instances handle concurrent requests
   - **High Availability**: If one fails, the other continues serving
   - **Horizontal Scaling**: Add more replicas instead of bigger instances

2. **Frontend Replicas**

   - **CDN Alternative**: Multiple nginx instances serve static assets
   - **Redundancy**: Survive individual container failures

3. **Ollama Scaling (Not Recommended)**
   - **Why no `replicas` on Ollama?** Each instance would need its own models (4GB+ each)
   - **Better approach**: Use model sharding or dedicated Ollama clusters

##### **Logging Configuration**

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m" # Max 10MB per log file
    max-file: "3" # Keep 3 rotated files
```

**Production Logging Best Practices:**

1. **`json-file` driver**

   - **Default driver**: Logs stored as JSON on host
   - **Location**: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
   - **Alternatives**: `syslog`, `fluentd`, `awslogs`, `splunk`

2. **Log Rotation**

   - **`max-size: "10m"`**: Rotate when file reaches 10MB
   - **`max-file: "3"`**: Keep 3 files (total 30MB per container)
   - **Why?** Prevent disk exhaustion from unbounded log growth

3. **Viewing Rotated Logs**
   ```bash
   docker logs ollama-backend              # Current logs
   docker logs ollama-backend --tail 100   # Last 100 lines
   docker logs ollama-backend --follow     # Stream new logs
   ```

##### **Restart Policy**

```yaml
restart: always # More aggressive than base config
```

**Restart Policy Options:**

| Policy           | Development    | Production     | Use Case                                       |
| ---------------- | -------------- | -------------- | ---------------------------------------------- |
| `no`             | ✅ Recommended | ❌             | Debugging (don't auto-restart)                 |
| `unless-stopped` | ✅             | ⚠️             | Auto-restart, but respect manual stops         |
| `always`         | ❌             | ✅ Recommended | Maximum uptime, restart even after manual stop |
| `on-failure`     | ⚠️             | ⚠️             | Only restart on crash (exit code ≠ 0)          |

**Production Rationale:**

- **`always`**: Ensures service restarts after host reboots or Docker daemon restarts
- **Maximum Availability**: Container comes back even if admin manually stopped it (prevents accidental downtime)

---

### **Build Optimization: .dockerignore**

**Purpose**: Exclude unnecessary files from Docker build context, reducing build time and image size.

#### **Recommended .dockerignore**

```
# Dependencies (installed inside container)
node_modules/
venv/
__pycache__/
*.pyc
*.pyo
*.pyd

# Development files
.git/
.gitignore
.env
.env.local
*.log
npm-debug.log*

# IDE/Editor files
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Build artifacts
dist/
build/
*.egg-info/

# Infrastructure (not needed in container)
.terraform/
*.tfstate
*.tfstate.backup

# Documentation
README.md
docs/
*.md

# Testing
.pytest_cache/
.coverage
htmlcov/

# CI/CD
.github/
.gitlab-ci.yml
```

#### **How .dockerignore Works**

1. **Build Context**

   - **What?** Directory sent to Docker daemon during `docker build`
   - **Default**: Everything in `context` directory (e.g., `./backend`)
   - **Problem**: Sending large `node_modules/` or `.git/` slows build significantly

2. **Exclusion Patterns**

   - **Similar to `.gitignore`**: Glob patterns, comments, negation
   - **Example**: `*.log` excludes all log files

3. **Performance Impact**

   ```bash
   # WITHOUT .dockerignore
   Sending build context to Docker daemon: 250MB  # Includes node_modules

   # WITH .dockerignore
   Sending build context to Docker daemon: 5MB    # Excludes node_modules
   ```

4. **Security Benefit**
   - **Prevents leaks**: `.env` files, credentials, SSH keys don't end up in image layers
   - **Smaller attack surface**: Fewer files = fewer potential vulnerabilities

#### **Why Exclude Specific Files?**

| File/Directory       | Reason to Exclude                                                               |
| -------------------- | ------------------------------------------------------------------------------- |
| `node_modules/`      | Rebuilt inside container with `npm install` (prevents host/container conflicts) |
| `venv/`              | Python virtual env is container-specific                                        |
| `.git/`              | Version history not needed in runtime image (100MB+ wasted space)               |
| `.env`               | Secrets should use environment variables or Docker secrets                      |
| `dist/`, `build/`    | Build artifacts regenerated during Docker build                                 |
| `.terraform/`        | IaC state files irrelevant to application runtime                               |
| `README.md`, `docs/` | Documentation doesn't belong in production images                               |

---

### **Working with Multiple Compose Files**

#### **Command Patterns**

##### **Development Workflow**

```bash
# Start development environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Rebuild backend after dependency changes
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend

# View logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend

# Stop all services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Stop and remove volumes (clean slate)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
```

##### **Production Workflow**

```bash
# Start production environment (detached)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Scale backend to 4 instances
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --scale backend=4

# Rolling restart
docker-compose -f docker-compose.yml -f docker-compose.prod.yml restart backend

# Update and restart specific service
docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull backend
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d backend
```

#### **Simplifying Commands with Environment Variable**

Create an alias or script to avoid repetitive `-f` flags:

```bash
# In ~/.bashrc or ~/.zshrc
alias dc-dev='docker-compose -f docker-compose.yml -f docker-compose.dev.yml'
alias dc-prod='docker-compose -f docker-compose.yml -f docker-compose.prod.yml'

# Usage
dc-dev up
dc-prod up -d
dc-dev logs -f backend
```

#### **Verification: Which Configuration is Active?**

```bash
# Inspect merged configuration
docker-compose -f docker-compose.yml -f docker-compose.dev.yml config

# Check specific service
docker-compose -f docker-compose.yml -f docker-compose.dev.yml config backend

# Validate file syntax
docker-compose -f docker-compose.yml config --quiet
```

---

### **Common Docker Compose Workflow Scenarios**

#### **Scenario 1: First-Time Setup**

```bash
# 1. Clone repository
git clone <repo> && cd <project>

# 2. Pull Ollama models
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d ollama-service
docker exec ollama-service ollama pull llama2

# 3. Start all services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# 4. Verify
curl http://localhost:8000/health
curl http://localhost:3000
```

#### **Scenario 2: Code Changes (Hot-Reload)**

**With development configuration:**

1. Edit `backend/app.py` on host
2. Flask detects change → Auto-reloads (no restart needed)
3. Edit `frontend/src/App.jsx`
4. Vite HMR updates browser instantly

**No restart required!** This is the power of volume mounting + dev servers.

#### **Scenario 3: Dependency Changes**

```bash
# Backend: New Python package
echo "new-package==1.0.0" >> backend/requirements.txt

# Rebuild backend container
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend

# Restart with new image
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d backend

# Frontend: New npm package
cd frontend && npm install new-package
# Restart frontend container (will reinstall all packages)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml restart frontend
```

#### **Scenario 4: Troubleshooting Failed Container**

```bash
# Check container status
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps

# View logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs backend

# Inspect container
docker inspect ollama-backend

# Access shell inside container
docker exec -it ollama-backend /bin/bash

# Test network connectivity from inside container
docker exec ollama-backend curl http://ollama-service:11434/api/tags
```

#### **Scenario 5: Clean Environment Reset**

```bash
# Stop all services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Remove all containers, networks, and volumes
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v

# Remove all images (forces rebuild)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down --rmi all

# Fresh start
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

---

### **Advanced Configuration Tips**

#### **1. Environment Variable Files**

Create `.env` file in project root:

```bash
# .env
COMPOSE_PROJECT_NAME=ollama-chat-app
OLLAMA_MODEL=llama2
BACKEND_PORT=8000
FRONTEND_PORT=3000
```

Reference in `docker-compose.yml`:

```yaml
services:
  backend:
    ports:
      - "${BACKEND_PORT}:8000"
    environment:
      OLLAMA_MODEL: ${OLLAMA_MODEL}
```

**Automatic Loading**: Docker Compose loads `.env` automatically (no `-f .env` needed)

#### **2. Override Specific Settings Locally**

Create `docker-compose.override.yml` (auto-loaded, not committed to Git):

```yaml
# docker-compose.override.yml (local developer preferences)
services:
  backend:
    ports:
      - "9000:8000" # Use port 9000 on my machine
```

**Load Order**: `docker-compose.yml` → `docker-compose.override.yml` (override has precedence)

#### **3. Health Check-Based Startup Order**

Ensure backend waits for Ollama to be truly ready:

```yaml
services:
  backend:
    depends_on:
      ollama-service:
        condition: service_healthy # Wait for health check to pass
```

**Alternative (Legacy)**:
Use `wait-for-it.sh` script in entrypoint:

```dockerfile
# In backend Dockerfile
COPY wait-for-it.sh /wait-for-it.sh
ENTRYPOINT ["/wait-for-it.sh", "ollama-service:11434", "--"]
CMD ["python", "app.py"]
```

#### **4. Secrets Management (Production)**

Use Docker secrets instead of environment variables:

```yaml
services:
  backend:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

**Why?** Secrets are mounted as files, not exposed in `docker inspect` output.

---

### **Comparison: Development vs Production Configuration**

| Aspect              | Development (`docker-compose.dev.yml`) | Production (`docker-compose.prod.yml`)   |
| ------------------- | -------------------------------------- | ---------------------------------------- |
| **Restart Policy**  | `no` (manual restart for debugging)    | `always` (maximum uptime)                |
| **Backend Server**  | Flask dev server (`python app.py`)     | Gunicorn WSGI (`gunicorn -w 4 app:app`)  |
| **Frontend Server** | Vite dev server (port 3000)            | nginx static files (port 80)             |
| **Volume Mounting** | Yes (hot-reload: `./backend:/app`)     | No (use `COPY` in Dockerfile)            |
| **Resource Limits** | None (use all available)               | Enforced (`memory: 2G`, `cpus: '2.0'`)   |
| **Log Rotation**    | Disabled (unlimited logs)              | Enabled (`max-size: 10m`, `max-file: 3`) |
| **Replicas**        | 1 (single instance)                    | 2+ (horizontal scaling)                  |
| **Environment**     | `FLASK_DEBUG=True`                     | `FLASK_ENV=production`                   |
| **Build Time**      | Faster (no optimization)               | Slower (multi-stage, minification)       |
| **Image Size**      | Larger (includes dev dependencies)     | Smaller (production-only dependencies)   |

---

### **Summary: When to Use Each File**

| File                                             | Use Case                                          | Command Example                                                         |
| ------------------------------------------------ | ------------------------------------------------- | ----------------------------------------------------------------------- |
| `docker-compose.yml`                             | **Never alone** (base config only)                | `docker-compose up` ❌ (missing overrides)                              |
| `docker-compose.yml` + `docker-compose.dev.yml`  | **Local development** (hot-reload, debugging)     | `docker-compose -f docker-compose.yml -f docker-compose.dev.yml up`     |
| `docker-compose.yml` + `docker-compose.prod.yml` | **Production deployment** (optimized, scaled)     | `docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d` |
| `docker-compose.override.yml`                    | **Personal overrides** (local port changes, etc.) | Auto-loaded by `docker-compose up`                                      |

**Golden Rule**: Always use **base file + environment-specific file**. Never use base file alone in actual deployments.

---

## Building Docker Images

Once you have created your Dockerfiles and Docker Compose configuration, you need to build the Docker images before running the containers. This section provides complete instructions for building, verifying, and troubleshooting your containerized Ollama Chat App.

### **Prerequisites**

Before building images, verify your Docker installation:

```bash
# Verify Docker is installed
docker --version
# Should show: Docker version 24.x.x or higher

# Verify Docker Compose is installed
docker-compose --version
# Should show: Docker Compose version v2.x.x or higher

# Check Docker is running
docker ps
# Should show table of running containers (may be empty)

# Navigate to project root
cd ~/codeplatoon/projects/ollama-chat-app
```

---

### **Build All Services**

#### **Option 1: Using Docker Compose (Recommended)**

```bash
# Build all services using base + dev configuration
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

# Or with production configuration
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Build with no cache (clean build)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

# Build with progress output
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --progress=plain

# Build in parallel (faster)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --parallel
```

#### **Option 2: Using Build Script**

Create a helper script for easier building:

```bash
# Create build script
cat > build.sh << 'EOF'
#!/bin/bash

set -e  # Exit on error

echo "Building Ollama Chat App Docker Images"
echo ""

# Parse arguments
ENV=${1:-dev}  # Default to dev

if [ "$ENV" = "dev" ]; then
    echo "Building DEVELOPMENT images..."
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.dev.yml"
elif [ "$ENV" = "prod" ]; then
    echo "Building PRODUCTION images..."
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"
else
    echo "Invalid environment: $ENV"
    echo "Usage: ./build.sh [dev|prod]"
    exit 1
fi

# Build images
echo ""
echo "Building backend..."
docker-compose $COMPOSE_FILES build backend

echo ""
echo "Building frontend..."
docker-compose $COMPOSE_FILES build frontend

echo ""
echo "Pulling Ollama image..."
docker-compose $COMPOSE_FILES pull ollama-service

echo ""
echo "Build complete!"
echo ""
echo "Images created:"
docker-compose $COMPOSE_FILES images

echo ""
echo "To start services, run:"
echo "   docker-compose $COMPOSE_FILES up -d"
EOF

chmod +x build.sh

# Usage:
./build.sh dev      # Build development images
./build.sh prod     # Build production images
```

---

### **Build Individual Services**

If you only need to rebuild specific services:

```bash
# Build only backend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend

# Build only frontend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build frontend

# Ollama service uses pre-built image (just pull it)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml pull ollama-service
```

---

### **Verify Built Images**

After building, verify your images were created successfully:

```bash
# List all Docker images
docker images

# You should see:
# REPOSITORY                    TAG       IMAGE ID       CREATED         SIZE
# ollama-chat-app-backend      latest    abc123...      2 minutes ago   500MB
# ollama-chat-app-frontend     latest    def456...      1 minute ago    150MB
# ollama/ollama                latest    ghi789...      1 week ago      1.2GB

# Or using docker-compose
docker-compose -f docker-compose.yml -f docker-compose.dev.yml images

# Check image details
docker inspect ollama-chat-app-backend:latest

# Check image layers (useful for debugging size)
docker history ollama-chat-app-backend:latest

# Check image size
docker images ollama-chat-app-backend --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

---

### **Start Services After Building**

#### **Development Environment**

```bash
# Start all services in development mode
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Check service status
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps

# Test endpoints
curl http://localhost:11434/api/tags
curl http://localhost:8000/health
curl http://localhost:3000
```

#### **Production Environment**

```bash
# Start all services in production mode
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

# Check service status
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

---

### **Complete First-Time Setup Workflow**

#### **Development Setup**

```bash
# 1. Navigate to project
cd ~/codeplatoon/projects/ollama-chat-app

# 2. Build images
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

# 3. Start services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 4. Wait for services to be healthy (check logs)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# 5. Pull Ollama model
docker exec ollama-service ollama pull llama2

# 6. Verify Ollama model is available
docker exec ollama-service ollama list

# 7. Verify services are running
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps

# 8. Test endpoints
curl http://localhost:11434/api/tags
curl http://localhost:8000/health

# 9. Open in browser
# http://localhost:3000
```

#### **Production Setup**

```bash
# 1. Set environment variables (if needed)
export SECRET_KEY="your-secret-key-here"
export API_URL="https://api.yourdomain.com"

# 2. Navigate to project
cd ~/codeplatoon/projects/ollama-chat-app

# 3. Build production images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# 4. Start services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 5. Pull Ollama models
docker exec ollama-service ollama pull llama2
docker exec ollama-service ollama pull mistral

# 6. Verify services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps

# 7. Check health
curl http://localhost:8000/health

# 8. View logs
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f
```

---

### **Rebuild After Code Changes**

#### **Development (with hot-reload)**

In development mode, code changes are automatically reflected thanks to volume mounts:

```bash
# For Python code changes (backend/app.py):
# Flask detects changes automatically - NO REBUILD NEEDED

# For React code changes (frontend/src/**):
# Vite HMR updates browser automatically - NO REBUILD NEEDED

# Only rebuild if you change dependencies:

# Backend: If requirements.txt changed
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d backend

# Frontend: If package.json changed
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build frontend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d frontend

# If Dockerfile changed
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache backend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d backend
```

#### **Production (requires rebuild)**

In production, code is copied into the image, so rebuilds are required:

```bash
# Rebuild specific service
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build backend

# Restart with new image (zero downtime if configured with replicas)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-deps backend

# Or rebuild all services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

### **Troubleshooting Build Issues**

#### **Issue 1: Build fails with "no space left on device"**

```bash
# Check Docker disk usage
docker system df

# Clean up unused images
docker image prune -a

# Clean up unused containers
docker container prune

# Clean up unused volumes
docker volume prune

# Full cleanup (CAREFUL - removes everything unused)
docker system prune -a --volumes

# Check disk space
df -h
```

#### **Issue 2: Build fails with "Cannot connect to Docker daemon"**

```bash
# Check if Docker is running
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker

# Add user to docker group (to avoid sudo)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

#### **Issue 3: Build is very slow**

```bash
# Enable BuildKit for faster builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Build with BuildKit
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

# Or use --parallel flag
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --parallel

# Check .dockerignore is excluding large directories
cat .dockerignore
# Should include: node_modules, venv, .git, __pycache__
```

#### **Issue 4: Cache issues - old code still running**

```bash
# Build with --no-cache flag
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

# Or remove specific image and rebuild
docker rmi ollama-chat-app-backend
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend

# Force recreate containers
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --force-recreate
```

#### **Issue 5: Permission denied errors**

```bash
# Check file permissions
ls -la backend/Dockerfile
ls -la frontend/Dockerfile

# Fix file permissions
chmod 644 backend/Dockerfile
chmod 644 frontend/Dockerfile
chmod 644 docker-compose*.yml

# Fix directory permissions
chmod 755 backend
chmod 755 frontend

# Check ownership
ls -la backend/
# If files owned by root, fix with:
sudo chown -R $USER:$USER backend/
sudo chown -R $USER:$USER frontend/
```

#### **Issue 6: Module not found or import errors**

```bash
# Backend: Check requirements.txt is being copied
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache backend

# Verify requirements are installed in image
docker run --rm ollama-chat-app-backend pip list

# Check requirements.txt exists
cat backend/requirements.txt

# Frontend: Check package.json
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache frontend

# Verify dependencies in image
docker run --rm ollama-chat-app-frontend npm list

# Check package.json exists
cat frontend/package.json
```

#### **Issue 7: Frontend build fails with "ENOENT" errors**

```bash
# Clean node_modules and rebuild
cd frontend
rm -rf node_modules package-lock.json
npm install

# Rebuild frontend image
cd ..
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache frontend

# Check if .dockerignore is correct
cat frontend/.dockerignore
# Should include: node_modules, dist, build
```

#### **Issue 8: Backend build fails with Python errors**

```bash
# Test requirements.txt locally first
cd backend
python -m venv test_venv
source test_venv/bin/activate
pip install -r requirements.txt

# If that works, rebuild image
cd ..
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache backend

# Check Python version in Dockerfile matches your requirements
grep "FROM python" backend/Dockerfile
# Should be: FROM python:3.11-slim
```

---

### **Build Performance Tips**

#### **1. Use .dockerignore Effectively**

```bash
# Verify .dockerignore is working
cd ~/codeplatoon/projects/ollama-chat-app

# Check what's being sent to Docker daemon
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build backend 2>&1 | grep "Sending build context"

# Should show: Sending build context to Docker daemon  15MB
# Not: Sending build context to Docker daemon  1.2GB (too large)
```

Create comprehensive `.dockerignore` in project root:

```
# Dependencies (installed inside container)
node_modules/
venv/
__pycache__/
*.pyc
*.pyo
*.pyd

# Development files
.git/
.gitignore
.env
.env.local
*.log
npm-debug.log*

# IDE/Editor files
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Build artifacts
dist/
build/
*.egg-info/

# Infrastructure (not needed in container)
.terraform/
*.tfstate
*.tfstate.backup

# Documentation
README.md
docs/
*.md

# Testing
.pytest_cache/
.coverage
htmlcov/

# CI/CD
.github/
```

#### **2. Order Dockerfile Commands for Better Caching**

```dockerfile
# Good (leverages cache):
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

# Bad (cache invalidated often):
COPY . .
RUN pip install -r requirements.txt
```

#### **3. Use Multi-Stage Builds**

Example for frontend:

```dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# Final image only contains built files, not node_modules
```

#### **4. Enable BuildKit**

```bash
# Add to ~/.bashrc or ~/.zshrc
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

source ~/.bashrc

# Or per-command
DOCKER_BUILDKIT=1 docker-compose -f docker-compose.yml -f docker-compose.dev.yml build
```

---

### **Tagging and Versioning Images**

#### **Tag Images with Versions**

```bash
# Build images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Tag with version
docker tag ollama-chat-app-backend:latest ollama-chat-app-backend:1.0.0
docker tag ollama-chat-app-frontend:latest ollama-chat-app-frontend:1.0.0

# Tag with git commit
GIT_COMMIT=$(git rev-parse --short HEAD)
docker tag ollama-chat-app-backend:latest ollama-chat-app-backend:$GIT_COMMIT
docker tag ollama-chat-app-frontend:latest ollama-chat-app-frontend:$GIT_COMMIT

# View all tags
docker images | grep ollama-chat-app
```

#### **Build with Custom Tags**

```bash
# Set image tag via environment variable
VERSION=1.0.0 docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Update docker-compose.yml to use variable:
# services:
#   backend:
#     image: ollama-chat-app-backend:${VERSION:-latest}
```

---

### **Command Aliases for Convenience**

Add these to `~/.bashrc` or `~/.zshrc`:

```bash
# Docker Compose aliases
alias dc-dev-build='docker-compose -f docker-compose.yml -f docker-compose.dev.yml build'
alias dc-dev-up='docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d'
alias dc-dev-down='docker-compose -f docker-compose.yml -f docker-compose.dev.yml down'
alias dc-dev-logs='docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f'
alias dc-dev-ps='docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps'

alias dc-prod-build='docker-compose -f docker-compose.yml -f docker-compose.prod.yml build'
alias dc-prod-up='docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d'
alias dc-prod-down='docker-compose -f docker-compose.yml -f docker-compose.prod.yml down'
alias dc-prod-logs='docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f'
alias dc-prod-ps='docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps'
```

Then reload:

```bash
source ~/.bashrc

# Usage:
dc-dev-build       # Build development images
dc-dev-up          # Start development environment
dc-dev-logs        # View logs
dc-dev-down        # Stop development environment
```

---

### **Build Checklist**

Before deploying to production, verify:

- [ ] All services build without errors
- [ ] Images are tagged with version numbers
- [ ] `.dockerignore` excludes unnecessary files
- [ ] Health checks pass for all services
- [ ] Resource limits are set (production)
- [ ] Environment variables are configured
- [ ] Volumes persist data correctly
- [ ] Networks allow proper communication
- [ ] Logs are structured and rotated
- [ ] Security best practices followed

---

### **Next Steps After Building**

1. **Pull Ollama Models**

   ```bash
   docker exec ollama-service ollama pull llama2
   docker exec ollama-service ollama list
   ```

2. **Test Services**

   ```bash
   curl http://localhost:11434/api/tags
   curl http://localhost:8000/health
   curl http://localhost:3000
   ```

3. **Monitor Logs**

   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
   ```

4. **Access Application**
   - Frontend: http://localhost:3000
   - Backend: http://localhost:8000
   - Ollama: http://localhost:11434

---

## Migration Steps: Local → Containers

### **Step 1: Create Dockerfiles**

#### **Backend Dockerfile** (`backend/Dockerfile`)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose Flask port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run with gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

#### **Frontend Dockerfile** (`frontend/Dockerfile`)

```dockerfile
# Multi-stage build
FROM node:18-alpine AS builder

WORKDIR /app

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
```

#### **Frontend Dev Dockerfile** (`frontend/Dockerfile.dev`)

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Expose Vite dev server port
EXPOSE 3000

# Start Vite dev server
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
```

### **Step 2: Update Backend Connection Logic**

Update `backend/app.py` to use environment variables:

```python
import os

# Get Ollama host from environment (Docker service name or localhost)
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost')
OLLAMA_PORT = os.getenv('OLLAMA_PORT', '11434')

print(f"🤖 Connecting to Ollama at {OLLAMA_HOST}:{OLLAMA_PORT}")

ollama = OllamaConnector(
    base_url=f"http://{OLLAMA_HOST}:{OLLAMA_PORT}"
)
```

Update `backend/ollama_connector.py`:

```python
class OllamaConnector:
    def __init__(self, base_url="http://localhost:11434"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        print(f"🔗 OllamaConnector initialized: {base_url}")

    # ... rest of implementation
```

### **Step 3: Create Helper Scripts**

#### **scripts/start-dev.sh**

```bash
#!/bin/bash
set -e

echo "🚀 Starting Ollama Chat App (Development Mode)"

# Start services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

echo "⏳ Waiting for services to be healthy..."
sleep 10

# Pull required models
echo "📦 Ensuring Ollama models are available..."
docker exec ollama-service ollama pull llama2

echo "✅ Development environment ready!"
echo ""
echo "📊 Service URLs:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8000"
echo "   Ollama:    http://localhost:11434"
echo ""
echo "📝 View logs: docker-compose logs -f"
echo "🛑 Stop services: ./scripts/stop-dev.sh"
```

#### **scripts/stop-dev.sh**

```bash
#!/bin/bash
echo "🛑 Stopping Ollama Chat App..."
docker-compose down
echo "✅ Services stopped"
```

#### **scripts/ensure-models.sh**

```bash
#!/bin/bash
REQUIRED_MODELS=("llama2" "mistral")

for model in "${REQUIRED_MODELS[@]}"; do
    echo "Checking model: $model"
    if ! docker exec ollama-service ollama list | grep -q "$model"; then
        echo "📦 Pulling $model..."
        docker exec ollama-service ollama pull "$model"
    else
        echo "✅ $model already available"
    fi
done
```

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

---

## Phase 1: Project Setup & Development Environment

### Step 1.1: Create Project Structure

**Prerequisites**: Basic understanding of project organization, Docker installed
**Reference**: [tree-examples.md](./tree-examples.md) for folder structure patterns

```bash
# Navigate to projects directory
cd /home/lumineer/codeplatoon/projects

# Create main project directory structure
mkdir -p ollama-chat-app
cd ollama-chat-app

# Create top-level directories
mkdir -p frontend backend docs .github/workflows scripts

# Create infrastructure directories
mkdir -p infra/modules/{vpc,alb,ec2,asg,security,iam,outputs}

# Verify structure
tree ollama-chat-app -L 2
```

### Step 1.2: Initialize Git Repository

**Reference**: [git.md](./git.md) for Git workflow best practices

```bash
cd ollama-chat-app
git init
echo "node_modules/" >> .gitignore
echo "__pycache__/" >> .gitignore
echo "*.pyc" >> .gitignore
echo ".terraform/" >> .gitignore
echo "terraform.tfvars" >> .gitignore
```

---

## Phase 2: Frontend Development (React + Vite)

### Step 2.1: Create React Application

**Prerequisites**: Node.js environment setup
**Reference**: [vite.md](./vite.md) for Vite configuration details

```bash
cd frontend

# Initialize Vite React project
npm create vite@latest . -- --template react
npm install

# Install additional dependencies for chat UI
npm install axios lucide-react
```

### Step 2.2: Configure Vite for Production

**Key Configuration**: Environment variables and build optimization

**Create `vite.config.js`:**

```javascript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true,
  },
  preview: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: "dist",
    sourcemap: false,
    minify: "terser",
  },
});
```

### Step 2.3: Build Chat Interface

**Key Components**: Chat window, message handling, API integration

**Create basic chat components** (detailed implementation in frontend README)

### Step 2.4: Frontend Containerization

**Prerequisites**: Docker basics
**Reference**: [docker.md](./docker.md) for Docker best practices

**Create `frontend/Dockerfile`:**

```dockerfile
# Multi-stage build for production
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Production stage
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## Phase 3: Backend Development (Flask + Ollama)

### Step 3.1: Flask Application Setup

**Prerequisites**: Python environment
**Reference**: [flask.md](./flask.md) for Flask development patterns

```bash
cd backend

# Create virtual environment (or use uv - see py-uv.md)
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask gunicorn requests python-dotenv flask-cors
pip freeze > requirements.txt
```

### Step 3.2: Create Flask Application

**Create `backend/app.py`:**

```python
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from ollama_connector import OllamaConnector

app = Flask(__name__)
CORS(app)

# Initialize Ollama connector
ollama = OllamaConnector(
    host=os.getenv('OLLAMA_HOST', 'localhost'),
    port=os.getenv('OLLAMA_PORT', '11434')
)

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        prompt = data.get('prompt', '')
        session_id = data.get('session_id', 'default')

        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400

        response = ollama.generate_response(prompt, session_id)
        return jsonify({"response": response, "session_id": session_id})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

### Step 3.3: Ollama Integration

**Create `backend/ollama_connector.py`:**

```python
import requests
import json
from typing import Dict, Any

class OllamaConnector:
    def __init__(self, host='localhost', port='11434'):
        self.base_url = f"http://{host}:{port}"
        self.sessions = {}  # Simple in-memory session storage

    def generate_response(self, prompt: str, session_id: str = 'default') -> str:
        """Generate response from Ollama API"""
        try:
            payload = {
                "model": "llama2",  # Configure based on available models
                "prompt": prompt,
                "stream": False
            }

            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=60
            )
            response.raise_for_status()

            result = response.json()
            return result.get('response', 'No response from model')

        except requests.exceptions.RequestException as e:
            raise Exception(f"Ollama API error: {str(e)}")
```

### Step 3.4: Backend Containerization

**Create `backend/Dockerfile`:**

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 8000

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

---

## Phase 4: Multi-Platform Docker & Container Registry

### Step 4.1: Docker Buildx Setup

**Prerequisites**: Docker with buildx support
**Reference**: [docker.md](./docker.md) for advanced Docker features

```bash
# Create and use buildx builder
docker buildx create --use --name multiarch-builder
docker buildx inspect --bootstrap
```

### Step 4.2: Local Multi-Arch Testing

**Test both frontend and backend builds:**

```bash
# Frontend multi-arch build
cd frontend
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg VITE_API_URL="http://localhost:8000" \
  -t ollama-frontend:local .

# Backend multi-arch build
cd ../backend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ollama-backend:local .
```

### Step 4.3: GitHub Container Registry Setup

**Prerequisites**: GitHub repository and PAT token
**Configure secrets in GitHub repository:**

- `GHCR_TOKEN`: Personal Access Token with `packages:write` scope

---

## Phase 5: AWS Infrastructure with Terraform

### Step 5.1: VPC Network Foundation

**Prerequisites**: AWS CLI configured, Terraform installed
**References**:

- [aws-cli.md](./aws-cli.md) for AWS CLI setup
- [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for VPC networking concepts

**Create `infra/modules/vpc/main.tf`:**

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (for ALB and React instances)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Type = "Public"
  }
}

# Private Subnets (for Flask+Ollama instances)
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Type = "Private"
  }
}

# NAT Gateway for private subnet internet access
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}
```

### Step 5.2: Security Groups & Network ACLs

**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for security concepts

**Create `infra/modules/security/main.tf`:**

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Flask Backend Security Group
resource "aws_security_group" "backend" {
  name_prefix = "${var.project_name}-backend-"
  vpc_id      = var.vpc_id

  # Allow Flask traffic from ALB only
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow HTTPS outbound for updates
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP outbound for packages
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# Network ACL for Private Subnets (Defense in Depth)
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow inbound from ALB subnets on port 8000
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = var.public_subnet_cidr_blocks[0]
    from_port  = 8000
    to_port    = 8000
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = var.public_subnet_cidr_blocks[1]
    from_port  = 8000
    to_port    = 8000
  }

  # Allow return traffic on ephemeral ports
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "${var.project_name}-private-nacl"
  }
}
```

### Step 5.3: Application Load Balancer

**Create `infra/modules/alb/main.tf`:**

```hcl
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets           = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for Flask Backend
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
```

### Step 5.4: EC2 Launch Templates & Auto Scaling

**Prerequisites**: Understanding of EC2 and container deployment
**Reference**: [ec2-docker.md](./ec2-docker.md) for EC2 Docker deployment

**Create `infra/modules/ec2/main.tf`:**

```hcl
# Launch Template for Backend (Flask + Ollama)
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = var.ami_id
  instance_type = var.backend_instance_type

  vpc_security_group_ids = [var.backend_security_group_id]

  # EBS configuration for Ollama models
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = var.ollama_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/user_data_backend.sh", {
    backend_image = var.backend_image
    ollama_image  = var.ollama_image
    region        = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-backend"
      Type = "Backend"
    }
  }
}

# Auto Scaling Group for Backend
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.backend_target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.backend_min_size
  max_size         = var.backend_max_size
  desired_capacity = var.backend_desired_capacity

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg"
    propagate_at_launch = false
  }
}
```

---

## Phase 6: CI/CD Pipeline with GitHub Actions

### Step 6.1: Container Build & Push Workflow

**Create `.github/workflows/ci.yml`:**

```yaml
name: Build and Push Images

on:
  push:
    branches: [main, development]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME_FRONTEND: ${{ github.repository }}/ollama-frontend
  IMAGE_NAME_BACKEND: ${{ github.repository }}/ollama-backend

jobs:
  build-frontend:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_FRONTEND }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Frontend
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            VITE_API_URL=${{ vars.VITE_API_URL || 'https://api.example.com' }}

  build-backend:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME_BACKEND }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Backend
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Step 6.2: Infrastructure Deployment Workflow

**Create `.github/workflows/deploy.yml`:**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ["infra/**"]
  workflow_dispatch:
    inputs:
      action:
        description: "Terraform action"
        required: true
        default: "plan"
        type: choice
        options:
          - plan
          - apply
          - destroy

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infra

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION || 'us-east-1' }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -var-file="terraform.tfvars"

      - name: Terraform Apply
        if: github.event.inputs.action == 'apply' || (github.event_name == 'push' && github.ref == 'refs/heads/main')
        run: terraform apply -auto-approve -var-file="terraform.tfvars"
```

---

## Phase 7: Monitoring, Security & Operations

### Step 7.1: Application Monitoring

**Key Metrics to Monitor:**

- ALB response times and error rates
- EC2 instance health and resource utilization
- Auto Scaling Group scaling events
- EBS volume usage (Ollama models)

### Step 7.2: Security Hardening Checklist

**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md) for security verification

- [ ] Private subnets have no direct internet access
- [ ] Security Groups follow principle of least privilege
- [ ] NACLs provide defense-in-depth
- [ ] EBS volumes are encrypted
- [ ] IAM roles have minimal required permissions
- [ ] ALB has proper SSL/TLS configuration (if using HTTPS)

### Step 7.3: Cost Optimization

**Key Cost Factors:**

- **NAT Gateway**: Consider single NAT vs per-AZ NAT
- **Instance Types**: Right-size based on Ollama model requirements
- **EBS Storage**: Monitor actual model storage usage
- **ALB**: Review request patterns and idle time

---

## Phase 8: Testing & Validation

### Step 8.1: Local Development Testing

```bash
# Test multi-arch builds locally
docker buildx build --platform linux/amd64,linux/arm64 -t test-frontend ./frontend
docker buildx build --platform linux/amd64,linux/arm64 -t test-backend ./backend

# Test API endpoints
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello, how are you?"}'
```

### Step 8.2: Infrastructure Validation

**Use existing VPC verification scripts:**
**Reference**: [aws-networking-GUIDE.md](./aws-networking-GUIDE.md)

```bash
# Validate VPC setup
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ollama-chat-app-vpc"

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

### Step 8.3: End-to-End Testing

1. **Health Check**: Verify `/health` endpoint returns 200
2. **Chat Functionality**: Test chat API with sample prompts
3. **Load Testing**: Use tools like `ab` or `wrk` to test ALB→Flask→Ollama pipeline
4. **Failover Testing**: Terminate instances and verify ASG replacement

---

## Implementation Checklist

### Development Phase

- [ ] Create project structure and Git repository
- [ ] Build React frontend with Vite
- [ ] Develop Flask backend with Ollama integration
- [ ] Create multi-platform Dockerfiles
- [ ] Test local container builds

### Infrastructure Phase

- [ ] Design Terraform modules (VPC, ALB, EC2, ASG, Security)
- [ ] Configure GitHub Container Registry
- [ ] Set up AWS CLI and Terraform
- [ ] Deploy and test infrastructure
- [ ] Validate security configurations

### CI/CD Phase

- [ ] Create GitHub Actions workflows
- [ ] Configure repository secrets and variables
- [ ] Test automated builds and deployments
- [ ] Set up monitoring and alerting

### Production Phase

- [ ] Performance testing and optimization
- [ ] Security audit and hardening
- [ ] Documentation and runbooks
- [ ] Cost optimization review

---

## Quick Start Commands

### **🔹 Option 1: Using Docker Compose (Recommended)**

```bash
# 1. Clone project
git clone <repository-url>
cd ollama-chat-app

# 2. Start all services (Development)
docker-compose up -d

# 3. Pull Ollama models
docker exec ollama-service ollama pull llama2

# 4. Access application
# Frontend: http://localhost:3000
# Backend:  http://localhost:8000
# Ollama:   http://localhost:11434

# 5. View logs
docker-compose logs -f

# 6. Stop all services
docker-compose down
```

### **🔹 Option 2: Using Helper Scripts**

```bash
# Start development environment
./scripts/start-dev.sh

# Stop services
./scripts/stop-dev.sh

# Ensure models are available
./scripts/ensure-models.sh
```

### **🔹 Option 3: Production Deployment (AWS)**

```bash
# 1. Build and push containers
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
docker-compose push

# 2. Deploy infrastructure
cd infra
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply

# 3. Get ALB DNS
terraform output alb_dns_name
```

---

## Docker Compose Command Reference

### **Service Management**

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d backend

# Restart service
docker-compose restart backend

# Stop all services
docker-compose down

# Stop and remove volumes (⚠️ deletes Ollama models)
docker-compose down -v

# View service status
docker-compose ps

# View resource usage
docker-compose stats
```

### **Logs and Debugging**

```bash
# View all logs
docker-compose logs

# Follow logs (real-time)
docker-compose logs -f

# Logs for specific service
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100

# Logs with timestamps
docker-compose logs -t
```

### **Building and Updating**

```bash
# Build all containers
docker-compose build

# Build with no cache (force rebuild)
docker-compose build --no-cache

# Build specific service
docker-compose build backend

# Pull latest images
docker-compose pull

# Rebuild and restart
docker-compose up -d --build
```

### **Accessing Containers**

```bash
# Execute command in container
docker exec ollama-service ollama list

# Interactive shell in container
docker exec -it ollama-backend bash
docker exec -it ollama-frontend sh

# View container details
docker inspect ollama-backend
```

### **Development vs Production**

```bash
# Development (hot-reload)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production (optimized)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Specific environment
docker-compose --env-file .env.production up -d
```

---

## Testing the Containerized Setup

### **1. Health Checks**

```bash
# Test Ollama service
curl http://localhost:11434/api/tags

# Test backend health
curl http://localhost:8000/health

# Test frontend
curl -I http://localhost:3000
```

### **2. Functional Testing**

```bash
# Test chat endpoint
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Hello, how are you?",
    "model": "llama2"
  }'
```

### **3. Service Dependencies**

```bash
# Verify service connectivity
docker exec ollama-backend curl http://ollama-service:11434/api/tags

# Check network
docker network inspect ollama-network
```

### **4. Volume Verification**

```bash
# List volumes
docker volume ls | grep ollama

# Inspect volume
docker volume inspect ollama-models

# Check model storage
docker exec ollama-service du -sh /root/.ollama/models
```

---

## Troubleshooting Containers

### **Problem: Service Won't Start**

```bash
# Check service status
docker-compose ps

# View specific service logs
docker-compose logs backend

# Check health status
docker inspect ollama-backend | grep -A 10 Health
```

### **Problem: Ollama Models Not Found**

```bash
# List available models
docker exec ollama-service ollama list

# Pull missing model
docker exec ollama-service ollama pull llama2

# Check volume mount
docker volume inspect ollama-models
```

### **Problem: Backend Can't Connect to Ollama**

```bash
# Verify network connectivity
docker exec ollama-backend ping ollama-service

# Check environment variables
docker exec ollama-backend env | grep OLLAMA

# Verify Ollama is healthy
docker exec ollama-service curl http://localhost:11434/api/tags
```

### **Problem: Frontend Can't Reach Backend**

```bash
# Check nginx configuration
docker exec ollama-frontend cat /etc/nginx/nginx.conf

# Test backend from frontend container
docker exec ollama-frontend wget -O- http://backend:8000/health

# Verify VITE_API_URL build arg
docker inspect ollama-frontend | grep VITE_API_URL
```

### **Problem: Port Already in Use**

```bash
# Find process using port
sudo lsof -i :8000
sudo lsof -i :3000
sudo lsof -i :11434

# Kill process or change port in docker-compose.yml
ports:
  - "8001:8000"  # Map to different host port
```

### **Problem: Container Crashes on Start**

```bash
# Check container exit code
docker ps -a | grep ollama

# View full logs
docker logs ollama-backend

# Start container in foreground for debugging
docker-compose up backend

# Check resource limits
docker stats ollama-backend
```

---

## Comparing Local vs Containerized Development

| Aspect                | Local Development                 | Containerized                     |
| --------------------- | --------------------------------- | --------------------------------- |
| **Setup**             | 3 terminals, manual service start | Single `docker-compose up`        |
| **Dependencies**      | Manual installation per machine   | Defined in Dockerfile             |
| **Consistency**       | "Works on my machine" issues      | Identical across all environments |
| **Isolation**         | Shared system resources           | Isolated per service              |
| **Portability**       | OS-dependent                      | Runs anywhere Docker runs         |
| **Cleanup**           | Manual process termination        | `docker-compose down`             |
| **Scaling**           | Single instance only              | Easy replication with `replicas`  |
| **Updates**           | Update each service manually      | Rebuild image, restart container  |
| **Debugging**         | Direct access to processes        | Use `docker exec` or logs         |
| **Production Parity** | May differ from production        | Identical to production           |

---

## Best Practices for Containerized Development

### **1. Use .dockerignore**

Create `.dockerignore` in project root:

```
node_modules
npm-debug.log
__pycache__
*.pyc
.git
.env
.vscode
.idea
dist
build
.terraform
*.tfstate
*.tfstate.backup
```

### **2. Environment Variables**

Create `.env` file for local development:

```bash
# Docker Compose environment
COMPOSE_PROJECT_NAME=ollama-chat-app

# Backend
FLASK_ENV=development
FLASK_DEBUG=True
OLLAMA_HOST=ollama-service
OLLAMA_PORT=11434

# Frontend
VITE_API_URL=http://localhost:8000
```

### **3. Health Checks**

Always define health checks for dependency ordering:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### **4. Resource Limits**

Set appropriate limits to prevent resource exhaustion:

```yaml
deploy:
  resources:
    limits:
      cpus: "2.0"
      memory: 4G
    reservations:
      cpus: "1.0"
      memory: 2G
```

### **5. Logging Configuration**

Prevent log file bloat:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### **6. Volume Management**

Use named volumes for persistence:

```yaml
volumes:
  ollama-models:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/persistent/storage
```

---

## Deployment Workflow

### **Development → Staging → Production**

```bash
# 1. Development (local)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 2. Build for staging
docker-compose -f docker-compose.yml build
docker-compose push

# 3. Deploy to staging
ssh staging-server
docker-compose pull
docker-compose up -d

# 4. Smoke test staging
curl https://staging.example.com/health

# 5. Deploy to production
ssh production-server
docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 6. Verify production
curl https://app.example.com/health
```

---

## Migration Checklist

- [ ] Create Dockerfiles for all services
- [ ] Create docker-compose.yml configuration
- [ ] Update backend to use environment variables
- [ ] Create nginx.conf for frontend
- [ ] Add .dockerignore files
- [ ] Create helper scripts (start-dev.sh, stop-dev.sh)
- [ ] Test local docker-compose setup
- [ ] Verify service connectivity
- [ ] Test with Ollama models
- [ ] Document container-specific commands
- [ ] Update CI/CD for container builds
- [ ] Test staging deployment
- [ ] Deploy to production

---

## Related Documentation

- **[aws-networking-GUIDE.md](./aws-networking-GUIDE.md)** - VPC networking and security verification
- **[docker.md](./docker.md)** - Docker containerization best practices
- **[flask.md](./flask.md)** - Flask application development patterns
- **[vite.md](./vite.md)** - Vite build configuration and optimization
- **[aws-cli.md](./aws-cli.md)** - AWS CLI setup and usage
- **[ec2-docker.md](./ec2-docker.md)** - EC2 Docker deployment strategies

---

## Decision Points & Customization Options

### Architecture Decisions

1. **Ollama Placement**: Co-located with Flask vs dedicated instances
2. **OS Choice**: Amazon Linux 2 vs Ubuntu 22.04
3. **TLS**: ALB termination vs HTTP-only for development
4. **Instance Size**: t3.medium vs t3.large vs memory-optimized (r5/m6)
5. **Deployment Strategy**: Terraform-only vs Terraform + SSM for app updates

### Customization Variables

- VPC CIDR range and subnet allocation
- Instance types and Auto Scaling parameters
- Ollama model selection and EBS volume sizing
- Multi-AZ vs single-AZ NAT Gateway strategy
- GitHub Container Registry vs other registries

---

**Next Steps**: Choose your architecture decisions and begin with Phase 1: Project Setup & Development Environment. Each phase builds upon the previous, creating a robust, scalable AI chat application ready for production deployment.
