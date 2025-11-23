# Ollama Chat App - Development & Deployment Guide

A comprehensive guide for local development, git workflow, service testing, and AWS deployment of the Ollama Chat application.

## Table of Contents

- [Quick Start - Daily Development Routine](#quick-start---daily-development-routine)
  - [Service Testing and Verification](#service-testing-and-verification)
- [Initial Project Setup](#initial-project-setup)
  - [Option A: Clone Existing Repository](#option-a-clone-existing-repository)
  - [Option B: Initialize New Repository from Scratch](#option-b-initialize-new-repository-from-scratch)
- [Local Development Environment](#local-development-environment)
- [Frontend Development Guide](#frontend-development-guide)
- [Git Workflow & Best Practices](#git-workflow--best-practices)
- [Development Workflow](#development-workflow)
- [AWS Production Deployment](#aws-production-deployment)
- [CI/CD with GitHub Actions](#cicd-with-github-actions)
- [Troubleshooting](#troubleshooting)

---

## Quick Start - Daily Development Routine

### **Start of Development Session**

#### **1. System Startup & Prerequisites**

- [ ] **Start Docker Desktop**

  ```bash
  #From Windows Start Menu, start Docker Desktop
  # Linux: Start Docker daemon
  sudo systemctl start docker
  sudo systemctl status docker  # Verify running

  # Verify Docker is working
  docker ps
  docker version
  ```

- [ ] **Open VS Code in Project Directory**

  ```bash
  cd ~/codeplatoon/projects/ollama-chat-app
  code .

  # Or if already in VS Code, use: Ctrl+K Ctrl+O to open folder
  ```

#### **2. Update Local Repository**

- [ ] **Sync with Remote Repository**

  ```bash
  # Check current status
  git status
  git branch

  # Fetch latest changes from remote
  git fetch origin

  # Update main branch
  git checkout main
  git pull origin main

  # List recent commits to see what's new
  git log --oneline -10
  ```

- [ ] **Check for Conflicts or Issues**

  ```bash
  # Verify working directory is clean
  git status

  # Check if any branches need updating
  git branch -vv
  ```

#### **3. Create or Switch to Feature Branch**

- [ ] **Determine What You're Working On**

  ```bash
  # Check existing branches
  git branch -a

  # Option A: Create new feature branch
  git checkout -b feature/your-feature-name
  # Examples:
  # git checkout -b feature/chat-history-persistence
  # git checkout -b feature/user-authentication
  # git checkout -b bugfix/cors-error-handling

  # Option B: Switch to existing feature branch
  git checkout feature/existing-branch

  # Option C: Continue from where you left off
  git checkout feature/your-current-work
  git rebase main  # Keep branch up to date with main
  ```

#### **4. Start Development Services**

- [ ] **Backend Setup (Terminal 1)**

  ```bash
  cd backend

  # Activate Python virtual environment
  source venv/bin/activate

  # Verify environment
  which python  # Should show venv path

  # Install any new dependencies (if requirements.txt updated)
  uv pip install -r requirements.txt

  # Start Flask development server
  python app.py

  # Expected output:
  # * Running on http://0.0.0.0:8000
  # * Debug mode: on
  ```

- [ ] **Frontend Setup (Terminal 2)**

  ```bash
  cd frontend

  # Install any new dependencies (if package.json updated)
  npm install

  # Start Vite development server
  npm run dev

  # Expected output:
  # Local:   http://localhost:3000/
  # ready in 500ms
  ```

- [ ] **Verify Services are Running**

  ```bash
  # In Terminal 3:
  # Test backend
  curl http://localhost:8000/health
  # Expected: {"status": "healthy"}

  # Test frontend
  curl http://localhost:3000
  # Should return HTML

  # Open in browser
  xdg-open http://localhost:3000
  ```

- [ ] **Start Ollama Service**

  ```bash
  # Start Ollama service in background
  ollama serve &

  # Or if running in Docker
  docker run -d \
    -p 11434:11434 \
    --name ollama \
    ollama/ollama

  # Pull the model if not already available
  ollama pull llama2
  ```

- [ ] **Verify Ollama Service is Running**

  ```bash
  # Check Ollama service health
  curl http://localhost:11434/api/tags

  # Expected output: JSON with list of available models
  # {"models": [{"name": "llama2:latest", ...}]}

  # Test basic chat functionality
  curl -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
      "model": "llama2",
      "prompt": "Hello, how are you?",
      "stream": false
    }'

  # Expected: JSON response with model output
  ```

### **During Development Session**

#### **5. Choose Files to Work On**

- [ ] **Review Your Task/Issue**

  ```bash
  # Check GitHub issues or project board
  # Understand requirements before coding

  # Common development scenarios:
  ```

- [ ] **Frontend Work**: Navigate to files

  - `frontend/src/components/` - UI components
  - `frontend/src/App.jsx` - Main app logic
  - `frontend/src/index.css` - Global styles
  - `frontend/vite.config.js` - Build configuration

- [ ] **Backend Work**: Navigate to files

  - `backend/app.py` - API endpoints
  - `backend/ollama_connector.py` - Business logic
  - `backend/requirements.txt` - Dependencies

- [ ] **Full Stack Work**: Work on both simultaneously
  - Use VS Code split editor (`Ctrl+\`)
  - Keep related files side-by-side

#### **6. Efficient VS Code Setup**

- [ ] **File Navigation**

  ```
  Ctrl+P          # Quick file opener
  Ctrl+Shift+F    # Search across all files
  Ctrl+Shift+E    # Toggle file explorer
  Ctrl+B          # Toggle sidebar
  Ctrl+`          # Toggle terminal
  ```

- [ ] **Editor Management**

  ```
  Ctrl+\          # Split editor
  Ctrl+W          # Close editor
  Ctrl+Tab        # Switch between open files
  Ctrl+1/2/3      # Focus on editor group
  ```

- [ ] **Code Editing**
  ```
  Ctrl+Space      # IntelliSense suggestions
  Alt+Up/Down     # Move line up/down
  Shift+Alt+Down  # Duplicate line
  Ctrl+/          # Toggle line comment
  Ctrl+Shift+K    # Delete line
  ```

#### **7. Development Workflow**

- [ ] **Make Incremental Changes**

  - Edit one feature/fix at a time
  - Save frequently (`Ctrl+S`)
  - Test changes immediately in browser (auto-reload)

- [ ] **Check Changes as You Go**

  ```bash
  # In Terminal 3:
  # View current changes
  git status
  git diff

  # View specific file changes
  git diff frontend/src/App.jsx
  ```

- [ ] **Test Continuously**

  - Frontend: Check browser for UI changes
  - Backend: Test API with curl or browser
  - Integration: Verify frontend-backend communication

  ```bash
  # Quick API test
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d '{"prompt": "test message", "session_id": "test"}'
  ```

### **Service Testing and Verification**

#### **8A. Ollama Service Testing**

- [ ] **Start Ollama Service**

  ```bash
  # Start Ollama service in background
  ollama serve &

  # Or if running in Docker
  docker run -d \
    -p 11434:11434 \
    --name ollama \
    ollama/ollama

  # Pull the model if not already available
  ollama pull llama2
  ```

- [ ] **Verify Ollama Service is Running**

  ```bash
  # Check Ollama service health
  curl http://localhost:11434/api/tags

  # Expected output: JSON with list of available models
  # {"models": [{"name": "llama2:latest", ...}]}

  # Test basic chat functionality
  curl -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
      "model": "llama2",
      "prompt": "Hello, how are you?",
      "stream": false
    }'

  # Expected: JSON response with model output
  ```

- [ ] **Test Model Availability**

  ```bash
  # List all available models
  ollama list

  # Expected output:
  # NAME          ID          SIZE    MODIFIED
  # llama2:latest abc123...   3.8 GB  2 hours ago
  ```

#### **8B. Backend Flask API Testing**

- [ ] **Verify Backend is Running**

  ```bash
  cd backend
  source venv/bin/activate
  python app.py

  # Should see output:
  # * Running on http://0.0.0.0:8000
  # * Debug mode: on
  ```

- [ ] **Test Backend Health Endpoint**

  ```bash
  # In a separate terminal
  curl http://localhost:8000/health

  # Expected response:
  # {"status":"healthy"}

  # Check response code (should be 200)
  curl -I http://localhost:8000/health
  ```

- [ ] **Test Backend Chat Endpoint**

  ```bash
  # Test basic chat functionality
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d '{
      "prompt": "What is artificial intelligence?",
      "session_id": "test-session-123"
    }'

  # Expected: JSON response with AI-generated text
  # {"response": "Artificial intelligence is...", "session_id": "test-session-123"}

  # Test with conversation context
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d '{
      "prompt": "Tell me more about that",
      "session_id": "test-session-123",
      "context": "Previous conversation about AI..."
    }'
  ```

- [ ] **Test Error Handling**

  ```bash
  # Test with missing prompt
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d '{
      "session_id": "test-session-123"
    }'

  # Expected: 400 Bad Request with error message

  # Test with invalid JSON
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d 'invalid json'

  # Expected: 400 Bad Request
  ```

#### **8C. Backend Unit Testing (ollama_connector.py)**

- [ ] **Run Unit Tests with pytest**

  ```bash
  cd backend
  source venv/bin/activate

  # Install pytest if not already installed
  pip install pytest pytest-mock

  # Run all tests
  pytest tests/ -v

  # Run specific test file
  pytest tests/test_ollama_connector.py -v

  # Run with coverage report
  pytest tests/ --cov=. --cov-report=term-missing
  ```

- [ ] **Manual Testing of ollama_connector Module**

  ```bash
  # Test in Python interactive shell
  cd backend
  source venv/bin/activate
  python

  # In Python shell:
  >>> from ollama_connector import OllamaConnector
  >>> connector = OllamaConnector()
  >>>
  >>> # Test list_models
  >>> models = connector.list_models()
  >>> print(models)
  # Expected: ['llama2:latest', ...]
  >>>
  >>> # Test chat method
  >>> response = connector.chat("What is 2+2?")
  >>> print(response)
  # Expected: Text response from Ollama
  >>>
  >>> # Test chat with context
  >>> response = connector.chat(
  ...     "What did I just ask you?",
  ...     context="User previously asked about 2+2"
  ... )
  >>> print(response)
  # Expected: Reference to previous math question
  >>>
  >>> exit()
  ```

- [ ] **Test Error Conditions**

  ```bash
  # Stop Ollama service to test error handling
  pkill ollama

  # Run connector test - should handle gracefully
  python
  >>> from ollama_connector import OllamaConnector
  >>> connector = OllamaConnector()
  >>> response = connector.chat("test")
  # Expected: Error message or exception handling
  >>> exit()

  # Restart Ollama service
  ollama serve &
  ```

#### **8D. Frontend Testing**

- [ ] **Start Frontend Development Server**

  ```bash
  cd frontend
  npm install  # If dependencies not installed
  npm run dev

  # Expected output:
  # VITE v5.4.21  ready in XXX ms
  # ➜  Local:   http://localhost:3000/
  # ➜  Network: use --host to expose
  ```

- [ ] **Verify Frontend is Accessible**

  ```bash
  # Test frontend loads
  curl -I http://localhost:3000

  # Expected: 200 OK with HTML content-type

  # Open in browser
  xdg-open http://localhost:3000  # Linux
  # or
  open http://localhost:3000      # macOS
  # or navigate manually in browser
  ```

- [ ] **Browser Console Testing**

  - Open browser DevTools (F12)
  - Check Console tab for errors
  - Verify no CORS errors
  - Check Network tab for API calls
  - Test chat functionality by sending messages

- [ ] **Frontend Linting and Build Tests**

  ```bash
  cd frontend

  # Run ESLint
  npm run lint

  # Fix auto-fixable issues
  npm run lint -- --fix

  # Build for production (tests bundling)
  npm run build

  # Expected: dist/ folder created with compiled assets

  # Preview production build
  npm run preview
  # Opens at http://localhost:4173
  ```

#### **8E. Integration Testing**

- [ ] **End-to-End User Flow Testing**

  1. **Start All Services** (Ollama, Backend, Frontend)
  2. **Open Frontend in Browser** (http://localhost:3000)
  3. **Test Chat Interface:**
     - Enter a message in the chat input
     - Verify message appears in chat history
     - Verify AI response is received and displayed
     - Check response time (should be reasonable)
  4. **Test Multiple Messages:**
     - Send follow-up questions
     - Verify context is maintained across conversation
     - Check session_id is preserved
  5. **Test Error Scenarios:**
     - Stop Ollama service mid-conversation
     - Verify frontend shows appropriate error message
     - Restart Ollama and verify recovery

- [ ] **Browser DevTools Verification**

  ```
  F12 to open DevTools

  Console Tab:
    - No red errors
    - Check for warnings that need attention

  Network Tab:
    - Filter: XHR/Fetch
    - Verify POST to /api/chat returns 200 OK
    - Inspect request/response payloads
    - Check response times

  Application Tab:
    - Check localStorage for session data
    - Verify sessionStorage if used
  ```

- [ ] **CORS and Cross-Origin Testing**

  ```bash
  # Test CORS headers from backend
  curl -X OPTIONS http://localhost:8000/api/chat \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: POST" \
    -v

  # Should see:
  # Access-Control-Allow-Origin: http://localhost:3000
  # Access-Control-Allow-Methods: POST, OPTIONS
  ```

### **Testing Your Changes (Pre-Commit)**

#### **8F. Pre-Commit Testing Checklist**

- [ ] **Frontend Testing**

  ```bash
  cd frontend

  # Run linter
  npm run lint

  # Fix auto-fixable issues
  npm run lint -- --fix

  # Build for production (ensure no build errors)
  npm run build

  # Preview production build
  npm run preview
  ```

- [ ] **Backend Testing**

  ```bash
  cd backend
  source venv/bin/activate

  # Run unit tests
  python -m pytest tests/ -v

  # Check imports work
  python -c "import app; print('Backend OK')"

  # Manual API testing
  curl http://localhost:8000/health

  # Test chat endpoint
  curl -X POST http://localhost:8000/api/chat \
    -H "Content-Type: application/json" \
    -d '{"prompt": "test", "session_id": "test"}'
  ```

- [ ] **Integration Testing**
  - Test complete user flows in browser
  - Check browser console for errors
  - Verify API calls in Network tab
  - Test responsive design (mobile/desktop)
  - Verify all services communicate correctly
  - Test edge cases and error scenarios

### **Committing Your Work**

#### **9. Stage and Review Changes**

- [ ] **Review What Changed**

  ```bash
  # See all changes
  git status

  # Review changes in detail
  git diff

  # Review staged changes
  git diff --cached
  ```

- [ ] **Stage Specific Files**

  ```bash
  # Stage specific files (RECOMMENDED)
  git add frontend/src/components/NewComponent.jsx
  git add frontend/src/components/NewComponent.css
  git add backend/app.py

  # Or stage all changes (be careful)
  git add .

  # Verify what's staged
  git status
  ```

- [ ] **Review Before Committing**

  ```bash
  # Double-check staged changes
  git diff --staged

  # If you staged something by mistake
  git reset HEAD <filename>  # Unstage specific file
  git reset HEAD .           # Unstage everything
  ```

#### **10. Commit with Good Message**

- [ ] **Write Descriptive Commit Message**

  ```bash
  # Use conventional commit format: <type>: <description>

  git commit -m "feat: add message persistence to chat interface

  - Implement localStorage integration for chat history
  - Add conversation save/load functionality
  - Update ChatInterface component with auto-save
  - Add error handling for storage quota exceeded

  Closes #42"

  # Commit types:
  # feat:     New feature
  # fix:      Bug fix
  # docs:     Documentation changes
  # style:    Formatting, missing semicolons, etc.
  # refactor: Code restructuring
  # test:     Adding tests
  # chore:    Maintenance tasks
  ```

- [ ] **Verify Commit**

  ```bash
  # Check commit was created
  git log --oneline -1

  # View commit details
  git show HEAD
  ```

### **Syncing Your Work**

#### **11. Push to Remote Repository**

- [ ] **Push Your Branch**

  ```bash
  # First time pushing this branch
  git push -u origin feature/your-feature-name

  # Subsequent pushes
  git push

  # Verify push succeeded
  git status  # Should say "up to date with origin/..."
  ```

- [ ] **Handle Push Rejections**

  ```bash
  # If remote has changes you don't have
  git pull --rebase origin feature/your-feature-name

  # Resolve any conflicts if they occur
  # Then push again
  git push
  ```

### **End of Session Checklist**

#### **12. Create Pull Request (if ready)**

- [ ] **Open GitHub PR**
  - Go to repository on GitHub
  - Click "Compare & pull request" button
  - Fill in PR template:
    - **Title**: Clear, descriptive title
    - **Description**: What changed and why
    - **Testing**: How you tested the changes
    - **Screenshots**: If UI changes
  - Link related issues: "Closes #42"
  - Request reviewers
  - Add labels (feature, bug, etc.)

#### **13. Clean Up (Optional)**

- [ ] **Stop Development Services**

  ```bash
  # In backend terminal (Terminal 1)
  Ctrl+C  # Stop Flask server
  deactivate  # Exit Python virtual environment

  # In frontend terminal (Terminal 2)
  Ctrl+C  # Stop Vite server
  # Stop the Ollama service gracefully
  pkill ollama

  # Verify it stopped
  ps aux | grep ollama
  # Should show no ollama processes

  # Alternative: If running in foreground (you started with 'ollama serve')
  # Press Ctrl+C in the terminal where it's running

  ```

- [ ] **Save VS Code Workspace State**

  - VS Code auto-saves workspace
  - Close VS Code or leave open for next session

- [ ] **Document Your Progress**
  ```bash
  # Optional: Add notes for next session
  # Update GitHub issue with status comment
  # Update project board
  # Document any blockers or questions
  ```

### **Next Session Quick Start**

#### **14. Resume Development**

- [ ] **Start Docker** (if needed)
- [ ] **Open VS Code** in project folder
- [ ] **Update main branch**
  ```bash
  git checkout main
  git pull origin main
  ```
- [ ] **Switch to your feature branch**
  ```bash
  git checkout feature/your-feature-name
  git rebase main  # Keep up to date
  ```
- [ ] **Start services** (backend & frontend)
- [ ] **Continue coding!**

---

### **Quick Reference Commands**

#### **Essential Git Commands**

```bash
# Daily workflow
git status                              # Check current state
git fetch origin                        # Get latest from remote
git pull origin main                    # Update main branch
git checkout -b feature/new-feature     # Create new branch
git add <files>                         # Stage changes
git commit -m "type: description"       # Commit changes
git push -u origin feature/branch-name  # Push new branch
git push                                # Push to existing branch

# Branch management
git branch                              # List local branches
git branch -a                           # List all branches
git checkout branch-name                # Switch branches
git branch -d branch-name               # Delete merged branch

# Undo operations
git reset HEAD <file>                   # Unstage file
git checkout -- <file>                  # Discard file changes
git revert <commit-hash>                # Revert commit
git reset --hard HEAD~1                 # Undo last commit (dangerous!)

# View changes
git diff                                # View unstaged changes
git diff --staged                       # View staged changes
git log --oneline -10                   # View commit history
git show HEAD                           # View last commit details
```

#### **VS Code Keyboard Shortcuts**

```bash
# Navigation
Ctrl+P              # Quick open file
Ctrl+Shift+P        # Command palette
Ctrl+Shift+F        # Find in files
Ctrl+Shift+E        # File explorer
Ctrl+B              # Toggle sidebar

# Editing
Ctrl+/              # Toggle comment
Ctrl+D              # Select next occurrence
Alt+Up/Down         # Move line
Shift+Alt+Up/Down   # Copy line up/down
Ctrl+Shift+K        # Delete line

# Terminal
Ctrl+`              # Toggle terminal
Ctrl+Shift+`        # New terminal
```

#### **Development Server Commands**

```bash
# Backend
cd backend && source venv/bin/activate && python app.py

# Frontend
cd frontend && npm run dev

# Production builds
cd frontend && npm run build && npm run preview
```

---

## Initial Project Setup

### **Option A: Clone Existing Repository**

#### **1. Clone and Initial Setup**

```bash
# Clone the repository (use HTTPS or SSH)
# HTTPS:
git clone https://github.com/YOUR_USERNAME/ollama-chat-app.git
# OR SSH (recommended if SSH keys configured):
git clone git@github.com:YOUR_USERNAME/ollama-chat-app.git

cd ollama-chat-app

# Verify remote is set
git remote -v
# Should show:
# origin  https://github.com/YOUR_USERNAME/ollama-chat-app.git (fetch)
# origin  https://github.com/YOUR_USERNAME/ollama-chat-app.git (push)

# Check project structure
tree -I 'node_modules|venv|__pycache__|.git' -L 3

# Expected structure:
# ollama-chat-app/
# ├── backend/              # Flask API server
# ├── frontend/             # React application
# ├── infra/                # Infrastructure as Code (Terraform)
# ├── .github/workflows/    # CI/CD pipelines
# ├── docs/                 # Documentation
# └── startup_and_dev.md    # This guide
```

#### **2. Initial Git Configuration**

```bash
# Configure git (if not done globally)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Check current status
git status
git log --oneline -5

# Create your development branch
git checkout -b feature/your-name-setup
```

---

### **Option B: Initialize New Repository from Scratch**

If you're starting a new project without cloning:

#### **1. Initialize Git Repository**

```bash
# Navigate to project directory
cd ~/codeplatoon/projects/ollama-chat-app

# Initialize git repository
git init

# Check status
git status
# Should show: On branch main (or master)
# No commits yet
```

#### **2. Configure Git**

```bash
# Set your identity (globally or per-repository)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Set default branch name to main
git config --global init.defaultBranch main

# Set default editor (optional)
git config --global core.editor "code --wait"  # VS Code
# OR
git config --global core.editor "nano"         # Nano

# Enable color output
git config --global color.ui auto

# Verify configuration
git config --list
```

#### **3. Create .gitignore File**

Before your first commit, create a `.gitignore` file:

```bash
# Create .gitignore at project root
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/
backend/venv/
*.egg-info/
.pytest_cache/
.coverage
htmlcov/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
frontend/node_modules/
frontend/dist/
frontend/build/
.pnp.*

# Environment variables
.env
.env.local
.env.*.local
*.env
.env.production
.env.development

# IDE & Editors
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# OS Files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs
*.log
logs/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Docker
.dockerignore

# Testing & Coverage
coverage/
.nyc_output/
*.lcov
.pytest_cache/

# Build artifacts
dist/
build/
*.egg
out/

# Temporary files
*.tmp
*.temp
.cache/
EOF

# Verify .gitignore was created
cat .gitignore
```

#### **4. Make Your First Commit**

```bash
# Stage all files
git add .

# Review what will be committed
git status

# Create first commit
git commit -m "feat: initial commit - ollama chat application

- Add Flask backend with Ollama integration
- Add React frontend with Vite build system
- Add Docker configuration for containerization
- Add nginx configuration for production deployment
- Add comprehensive documentation"

# Verify commit
git log --oneline -1
```

#### **5. Connect to GitHub Remote**

##### **Create GitHub Repository First:**

1. Go to https://github.com
2. Click "New Repository" (+ icon in top right)
3. Name: `ollama-chat-app`
4. Description: "AI-powered chat application using Ollama"
5. **DO NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

##### **Add Remote and Push:**

```bash
# Add GitHub remote (HTTPS)
git remote add origin https://github.com/YOUR_USERNAME/ollama-chat-app.git

# OR add GitHub remote (SSH - recommended if SSH keys configured)
git remote add origin git@github.com:YOUR_USERNAME/ollama-chat-app.git

# Verify remote was added
git remote -v

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub (first time)
git push -u origin main

# Verify push succeeded
git status
# Should show: Your branch is up to date with 'origin/main'
```

---

### **First Time Setup (New Developer)**

#### **3. Prerequisites Installation**

**System Requirements:**

```bash
# Install Node.js 18+ (for frontend)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python 3.8+ (for backend)
sudo apt-get update
sudo apt-get install python3 python3-pip python3-venv

# Install Docker (for containerization)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install uv (modern Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Verify installations
node --version    # Should be 18+
python3 --version # Should be 3.8+
docker --version  # Should be 20+
uv --version      # Should be 0.4+
```

---

## Local Development Environment

### **Backend Development Setup**

#### **1. Python Environment Setup**

```bash
# Navigate to backend directory
cd backend

# Create virtual environment using uv
uv venv venv
source venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt

# Verify installation
python -c "import flask; print('Flask version:', flask.__version__)"
```

#### **2. Environment Configuration**

```bash
# Create environment variables file
cat > .env << 'EOF'
# Backend Configuration
FLASK_ENV=development
FLASK_DEBUG=True
FLASK_APP=app.py

# Ollama Configuration
OLLAMA_HOST=localhost
OLLAMA_PORT=11434

# CORS Configuration
CORS_ORIGINS=http://localhost:3000
EOF

# Load environment variables
source .env
```

#### **3. Start Backend Server**

```bash
# Method 1: Direct Flask development server
python app.py

# Method 2: Using Flask CLI
flask run --host=0.0.0.0 --port=8000

# Method 3: Using Gunicorn (production-like)
gunicorn -w 4 -b 0.0.0.0:8000 app:app

# Verify backend is running
curl http://localhost:8000/health
# Expected: {"status": "healthy"}
```

### **Frontend Development Setup**

#### **1. Node.js Environment Setup**

```bash
# Open new terminal and navigate to frontend
cd frontend

# Install dependencies
npm install

# Verify installation
npm list --depth=0
```

#### **2. Frontend Configuration**

```bash
# Check Vite configuration
cat vite.config.js

# The proxy should be configured to:
# '/api': 'http://localhost:8000'
```

#### **3. Start Frontend Development Server**

```bash
# Start Vite development server
npm run dev

# Should output:
# Local:   http://localhost:3000/
# Network: use --host to expose

# Verify frontend is running
curl http://localhost:3000
```

### **Full Stack Development**

#### **1. Start Both Services (Recommended)**

```bash
# Terminal 1: Backend
cd backend
source venv/bin/activate
python app.py

# Terminal 2: Frontend
cd frontend
npm run dev

# Terminal 3: Development commands
# Available for git commands, testing, etc.
```

#### **2. Verify Full Stack Integration**

```bash
# Test backend health
curl http://localhost:8000/health

# Test frontend loading
curl -s http://localhost:3000 | grep -i "title"

# Test API proxy through frontend
curl -X POST http://localhost:3000/api/health

# Open application in browser
xdg-open http://localhost:3000
```

---

## Frontend Development Guide

### **React Application Architecture**

The frontend is a modern React application built with Vite, featuring a ChatGPT-like interface for AI conversations.

#### **Technology Stack:**

- **React 18**: Modern functional components with hooks
- **Vite**: Fast build tool and development server
- **Axios**: HTTP client for API communication
- **Lucide React**: Icon library for UI elements
- **CSS Modules**: Component-scoped styling
- **localStorage**: Client-side data persistence

### **Project Structure Deep Dive**

```
frontend/
├── src/
│   ├── main.jsx                    # React application entry point
│   ├── App.jsx                     # Main application component & state management
│   ├── App.css                     # Global application styles
│   ├── index.css                   # CSS reset & global styles
│   └── components/                 # Reusable UI components
│       ├── Sidebar.jsx             # Conversation history & navigation
│       ├── Sidebar.css             # Sidebar component styles
│       ├── ChatInterface.jsx       # Main chat interface & message handling
│       └── ChatInterface.css       # Chat interface styles
├── public/                         # Static assets served directly
├── package.json                    # Dependencies & scripts
├── vite.config.js                  # Vite configuration & API proxy
├── index.html                      # HTML template
├── nginx.conf                      # Production nginx configuration
└── Dockerfile                      # Container build instructions
```

### **Component Architecture**

#### **App.jsx - Main Application**

**Purpose**: Root component managing global state and layout
**Responsibilities**:

- **State Management**: Manages conversations, current conversation, loading states
- **Data Persistence**: Saves/loads conversations from localStorage
- **Component Orchestration**: Renders and coordinates child components
- **API Integration**: Handles conversation creation and management

```jsx
// Key state management pattern:
const [conversations, setConversations] = useState([]);
const [currentConversation, setCurrentConversation] = useState(null);
const [loading, setLoading] = useState(false);

// localStorage integration for persistence
useEffect(() => {
  const saved = localStorage.getItem("ollama-conversations");
  if (saved) setConversations(JSON.parse(saved));
}, []);
```

#### **Sidebar.jsx - Navigation Component**

**Purpose**: Conversation history and navigation management
**Key Features**:

- **Conversation List**: Displays all saved conversations with timestamps
- **Active State Management**: Highlights currently selected conversation
- **New Chat Creation**: Provides interface to start new conversations
- **Responsive Design**: Adapts to mobile/desktop screen sizes

```jsx
// Props interface pattern:
const Sidebar = ({
  conversations,
  currentConversation,
  onConversationSelect,
  onNewChat,
}) => {
  // Component logic for conversation management
};
```

#### **ChatInterface.jsx - Core Chat Component**

**Purpose**: Main chat interface for message exchange
**Responsibilities**:

- **Message Display**: Renders conversation history with proper formatting
- **Input Handling**: Manages message input with keyboard shortcuts
- **API Communication**: Sends messages to Flask backend
- **Loading States**: Shows typing indicators during API calls
- **Auto-scroll**: Automatically scrolls to latest messages
- **Error Handling**: Manages and displays API errors gracefully

### **Development Workflow**

#### **1. Starting Frontend Development**

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies (first time only)
npm install

# Start development server
npm run dev

# Development server will start on http://localhost:3000
# Features automatic hot reload for instant feedback
```

#### **2. Development Server Features**

```bash
# Available npm scripts:
npm run dev      # Start development server with hot reload
npm run build    # Build production bundle
npm run preview  # Preview production build locally
npm run lint     # Run ESLint for code quality

# Development server provides:
# - Hot Module Replacement (HMR)
# - Automatic browser refresh
# - Source maps for debugging
# - API proxy to backend (configured in vite.config.js)
```

#### **3. API Integration Pattern**

The frontend communicates with the Flask backend through a proxy configuration:

```javascript
// vite.config.js proxy configuration
export default defineConfig({
  server: {
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
});

// Usage in components:
const response = await axios.post("/api/chat", {
  message: userMessage,
  conversation_id: currentConversationId,
});
```

### **Component Development Process**

#### **1. Creating New Components**

```bash
# Component creation workflow:
mkdir -p src/components/NewComponent
touch src/components/NewComponent/NewComponent.jsx
touch src/components/NewComponent/NewComponent.css
touch src/components/NewComponent/index.js

# Component template structure:
```

```jsx
// NewComponent.jsx template
import "./NewComponent.css";

const NewComponent = ({ prop1, prop2, onAction }) => {
  // Component logic here

  return <div className="new-component">{/* Component JSX */}</div>;
};

export default NewComponent;
```

#### **2. Styling Guidelines**

```css
/* Component-specific CSS following BEM methodology */
.new-component {
  /* Base component styles */
}

.new-component__element {
  /* Element within component */
}

.new-component--modifier {
  /* Component variant styles */
}

/* Responsive design pattern */
@media (max-width: 768px) {
  .new-component {
    /* Mobile styles */
  }
}
```

#### **3. State Management Patterns**

```jsx
// Local component state
const [localState, setLocalState] = useState(initialValue);

// Effect for side effects
useEffect(() => {
  // Component lifecycle logic
  return () => {
    // Cleanup function
  };
}, [dependencies]);

// Prop drilling pattern for state sharing
const ParentComponent = () => {
  const [sharedState, setSharedState] = useState();

  return <ChildComponent state={sharedState} onStateChange={setSharedState} />;
};
```

### **Testing & Quality Assurance**

#### **1. Development Testing**

```bash
# Manual testing workflow:
npm run dev                    # Start dev server
# 1. Test UI components in browser
# 2. Test responsive design (mobile/desktop)
# 3. Test API integration with backend running
# 4. Test error handling scenarios

# Production build testing:
npm run build                  # Build for production
npm run preview               # Test production build
# Verify all features work in production mode
```

#### **2. Code Quality Checks**

```bash
# ESLint for code quality
npm run lint                   # Check for linting errors
npm run lint -- --fix         # Auto-fix fixable issues

# Manual code review checklist:
# - Component props properly typed
# - State updates follow React patterns
# - Event handlers prevent default when needed
# - Accessibility attributes included
# - Error boundaries implemented for robustness
```

#### **3. Browser Compatibility Testing**

```bash
# Test in multiple browsers:
# - Chrome (primary development)
# - Firefox
# - Safari (if available)
# - Mobile browsers (Chrome Mobile, Safari Mobile)

# Check browser console for:
# - JavaScript errors
# - Network request failures
# - Performance warnings
# - Accessibility issues
```

### **Production Build Process**

#### **1. Build Optimization**

```bash
# Production build creates optimized bundle
npm run build

# Build output analysis:
ls -la dist/                   # Check generated files
du -sh dist/                   # Check bundle size

# Vite automatically provides:
# - Code splitting
# - Tree shaking
# - Minification
# - Asset optimization
# - Source map generation (configurable)
```

#### **2. Build Configuration**

```javascript
// vite.config.js production optimizations
export default defineConfig({
  build: {
    outDir: 'dist',              # Output directory
    sourcemap: false,            # Disable source maps for production
    minify: 'esbuild',          # Use esbuild for minification
    rollupOptions: {
      output: {
        manualChunks: {          # Code splitting configuration
          vendor: ['react', 'react-dom'],
          utils: ['axios', 'lucide-react']
        }
      }
    }
  }
});
```

### **Docker Integration**

#### **1. Development Container**

```dockerfile
# Development Dockerfile for consistent environment
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host"]
```

#### **2. Production Container**

The production Dockerfile uses multi-stage builds for optimal image size:

```dockerfile
# Build stage - includes all dependencies
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci                      # Clean install for reproducible builds
COPY . .
ARG VITE_API_URL                # Build-time API URL configuration
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build               # Create production bundle

# Production stage - nginx serving static files
FROM nginx:stable-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### **Deployment Considerations**

#### **1. Environment Configuration**

```bash
# Environment-specific builds:

# Development
VITE_API_URL=http://localhost:8000

# Staging
VITE_API_URL=https://api-staging.ollama-chat.com

# Production
VITE_API_URL=https://api.ollama-chat.com

# Build with environment variables:
docker build --build-arg VITE_API_URL="https://api.ollama-chat.com" -t frontend:prod .
```

#### **2. Performance Optimization**

```javascript
// Code splitting for better performance
const LazyComponent = React.lazy(() => import("./LazyComponent"));

// Memoization for expensive calculations
const ExpensiveComponent = React.memo(({ data }) => {
  const expensiveValue = useMemo(() => heavyCalculation(data), [data]);

  return <div>{expensiveValue}</div>;
});

// Debounced input for better UX
const DebouncedInput = ({ onSearch }) => {
  const debouncedSearch = useMemo(() => debounce(onSearch, 300), [onSearch]);

  return <input onChange={(e) => debouncedSearch(e.target.value)} />;
};
```

### **Troubleshooting Frontend Issues**

#### **1. Development Server Issues**

```bash
# Port already in use
sudo lsof -ti:3000 | xargs kill -9
# Or use different port:
npm run dev -- --port 3001

# Node modules issues
rm -rf node_modules package-lock.json
npm install

# Cache issues
rm -rf node_modules/.vite
npm run dev
```

#### **2. Build Issues**

```bash
# Memory issues during build
export NODE_OPTIONS="--max-old-space-size=4096"
npm run build

# Missing dependencies
npm ls                         # Check for missing dependencies
npm install --save missing-package

# TypeScript errors (if using TypeScript)
npx tsc --noEmit              # Check types without emitting
```

#### **3. API Integration Issues**

```bash
# CORS issues in development
# Check vite.config.js proxy configuration
# Ensure backend allows localhost:3000 origin

# Network requests failing
# Check browser network tab
# Verify backend is running on correct port
curl http://localhost:8000/health

# Proxy configuration debugging
# Add logging to vite.config.js:
proxy: {
  '/api': {
    target: 'http://localhost:8000',
    changeOrigin: true,
    configure: (proxy, _options) => {
      proxy.on('error', (err, _req, _res) => {
        console.log('proxy error', err);
      });
    }
  }
}
```

---

## Git Workflow & Best Practices

### **Branch Strategy**

#### **Main Branches:**

- `main` - Production-ready code
- `develop` - Integration branch for features
- `staging` - Pre-production testing

#### **Feature Branches:**

- `feature/frontend-chat-interface`
- `feature/backend-ollama-integration`
- `feature/auth-system`
- `bugfix/cors-headers`
- `hotfix/security-patch`

### **Daily Development Workflow**

#### **1. Starting a New Development Session**

```bash
# Update your local repository
git fetch origin
git checkout main
git pull origin main

# Create/switch to your feature branch
git checkout -b feature/your-feature-name
# OR if branch exists:
git checkout feature/your-feature-name
git rebase main  # Keep branch up to date
```

#### **2. Making Changes**

```bash
# Check status before starting
git status
git branch -v

# Make your changes...
# Edit files, test locally, etc.

# Check what changed
git diff
git status

# Stage specific files (recommended)
git add backend/app.py
git add frontend/src/components/NewComponent.jsx

# OR stage all changes (be careful)
git add .

# Commit with descriptive message
git commit -m "feat: add chat message persistence

- Add localStorage integration for chat history
- Update ChatInterface component to save/load messages
- Add error handling for storage failures

Closes #42"
```

#### **3. Good Commit Messages**

```bash
# Format: <type>: <description>
#
# <body>
#
# <footer>

# Types:
feat:     # New feature
fix:      # Bug fix
docs:     # Documentation changes
style:    # Formatting changes
refactor: # Code restructuring
test:     # Adding tests
chore:    # Maintenance tasks

# Examples:
git commit -m "feat: implement user authentication system"
git commit -m "fix: resolve CORS issue in production deployment"
git commit -m "docs: update API documentation with new endpoints"
git commit -m "refactor: extract Ollama service into separate module"
```

#### **4. Pushing and Pull Requests**

```bash
# Push your branch
git push origin feature/your-feature-name

# If first time pushing this branch:
git push -u origin feature/your-feature-name

# Create Pull Request via GitHub Web UI
# - Compare: feature/your-feature-name → main
# - Add descriptive title and description
# - Request reviewers
# - Link related issues
```

### **Collaborative Development**

#### **1. Handling Conflicts**

```bash
# Update main branch
git checkout main
git pull origin main

# Rebase your feature branch
git checkout feature/your-feature-name
git rebase main

# If conflicts occur:
# 1. Fix conflicts in files
# 2. Stage resolved files: git add <filename>
# 3. Continue rebase: git rebase --continue

# Force push after rebase (be careful!)
git push --force-with-lease origin feature/your-feature-name
```

#### **2. Code Review Process**

```bash
# Before submitting PR:
# 1. Test locally
npm run dev          # Frontend
python app.py        # Backend
npm run build        # Production build test

# 2. Run linting
npm run lint         # Frontend
python -m flake8 .   # Backend (if configured)

# 3. Check for secrets/sensitive data
git log --oneline -5
git diff main..HEAD
```

### **Release Workflow**

#### **1. Preparing Release**

```bash
# Create release branch from main
git checkout main
git pull origin main
git checkout -b release/v1.2.0

# Update version numbers
# backend/app.py: __version__ = "1.2.0"
# frontend/package.json: "version": "1.2.0"

# Create release commit
git add .
git commit -m "chore: bump version to 1.2.0"

# Push release branch
git push origin release/v1.2.0
```

#### **2. Tagging Release**

```bash
# After release is approved and merged:
git checkout main
git pull origin main

# Create annotated tag
git tag -a v1.2.0 -m "Release version 1.2.0

Features:
- Real-time chat functionality
- User authentication
- Message persistence

Bug Fixes:
- Fixed CORS headers
- Resolved memory leaks in frontend

Breaking Changes:
- API endpoint restructuring
- Updated authentication flow"

# Push tag
git push origin v1.2.0
```

---

## Development Workflow

### **Frontend Development**

#### **1. Component Development**

```bash
# Start frontend dev server
cd frontend
npm run dev

# Create new component
mkdir -p src/components/NewComponent
touch src/components/NewComponent/NewComponent.jsx
touch src/components/NewComponent/NewComponent.css
touch src/components/NewComponent/index.js

# Development process:
# 1. Write component code
# 2. Test in browser (hot reload)
# 3. Add CSS styling
# 4. Integration testing
# 5. Commit changes

# Git workflow for frontend changes:
git add src/components/NewComponent/
git commit -m "feat: add NewComponent with real-time updates"
```

#### **2. Frontend Testing & Building**

```bash
# Development testing
npm run dev     # Start dev server
npm run lint    # Check code quality
npm run build   # Test production build
npm run preview # Test built application

# Build for production
npm run build
ls -la dist/    # Check built files

# Docker testing (optional)
docker build -t ollama-frontend:dev .
docker run -p 3000:80 ollama-frontend:dev
```

### **Backend Development**

#### **1. API Development**

```bash
# Start backend dev server
cd backend
source venv/bin/activate
python app.py

# Development process:
# 1. Create new endpoints
# 2. Test with curl/Postman
# 3. Update documentation
# 4. Integration testing
# 5. Commit changes

# Testing new endpoints:
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello, how are you?", "session_id": "test-123"}'

# Git workflow for backend changes:
git add backend/app.py backend/ollama_connector.py
git commit -m "feat: add conversation persistence to chat API"
```

#### **2. Backend Testing & Containerization**

```bash
# Install test dependencies
uv pip install pytest pytest-flask

# Run tests (if available)
python -m pytest tests/

# Docker testing
docker build -t ollama-backend:dev .
docker run -p 8000:8000 ollama-backend:dev

# Test containerized backend
curl http://localhost:8000/health
```

### **Integration Testing**

#### **1. Full Stack Testing**

```bash
# Start both services
# Terminal 1:
cd backend && source venv/bin/activate && python app.py

# Terminal 2:
cd frontend && npm run dev

# Test integration:
# 1. Open http://localhost:3000
# 2. Test chat functionality
# 3. Check browser dev tools for API calls
# 4. Verify data flow between frontend/backend
```

#### **2. Container Integration Testing**

```bash
# Build both containers
docker build -t ollama-backend:test backend/
docker build -t ollama-frontend:test frontend/

# Create network
docker network create ollama-net

# Start backend container
docker run -d \
  --name ollama-backend-test \
  --network ollama-net \
  -p 8000:8000 \
  ollama-backend:test

# Start frontend container (update nginx.conf to use 'ollama-backend-test:8000')
docker run -d \
  --name ollama-frontend-test \
  --network ollama-net \
  -p 3000:80 \
  ollama-frontend:test

# Test integration
curl http://localhost:3000
```

---

## AWS Production Deployment

### **Manual AWS Setup**

#### **1. AWS Prerequisites**

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1
# Default output format: json

# Verify access
aws sts get-caller-identity
```

#### **2. ECR Repository Setup**

```bash
# Create ECR repositories
aws ecr create-repository --repository-name ollama-chat-backend
aws ecr create-repository --repository-name ollama-chat-frontend

# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### **AMD64 Deployment (Intel/AMD instances)**

#### **1. Build and Push AMD64 Images**

```bash
# Build multi-platform backend
cd backend
docker buildx build --platform linux/amd64 \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:amd64-latest .

# Push backend
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:amd64-latest

# Build multi-platform frontend
cd ../frontend
docker buildx build --platform linux/amd64 \
  --build-arg VITE_API_URL="https://your-backend-domain.com" \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:amd64-latest .

# Push frontend
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:amd64-latest
```

#### **2. EC2 Deployment (AMD64)**

```bash
# Launch EC2 instance (t3.medium recommended)
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --count 1 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-groups ollama-chat-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ollama-chat-amd64}]'

# SSH into instance
ssh -i ~/.ssh/your-key.pem ec2-user@<public-ip>

# Install Docker on EC2
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Configure AWS CLI on EC2
aws configure

# Pull and run containers
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Run backend
docker run -d \
  --name ollama-backend \
  -p 8000:8000 \
  -e OLLAMA_HOST=localhost \
  -e OLLAMA_PORT=11434 \
  --restart unless-stopped \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:amd64-latest

# Run frontend
docker run -d \
  --name ollama-frontend \
  -p 80:80 \
  --restart unless-stopped \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:amd64-latest
```

### **ARM64 Deployment (Graviton instances)**

#### **1. Build and Push ARM64 Images**

```bash
# Build ARM64 backend
cd backend
docker buildx build --platform linux/arm64 \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:arm64-latest .

# Push backend
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:arm64-latest

# Build ARM64 frontend
cd ../frontend
docker buildx build --platform linux/arm64 \
  --build-arg VITE_API_URL="https://your-backend-domain.com" \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:arm64-latest .

# Push frontend
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:arm64-latest
```

#### **2. EC2 Graviton Deployment**

```bash
# Launch Graviton EC2 instance (t4g.medium recommended - ARM64)
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --count 1 \
  --instance-type t4g.medium \
  --key-name your-key-pair \
  --security-groups ollama-chat-sg \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ollama-chat-arm64}]'

# SSH into Graviton instance
ssh -i ~/.ssh/your-key.pem ec2-user@<public-ip>

# Same Docker installation process as AMD64
# But pull ARM64 images:
docker run -d \
  --name ollama-backend \
  -p 8000:8000 \
  -e OLLAMA_HOST=localhost \
  -e OLLAMA_PORT=11434 \
  --restart unless-stopped \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:arm64-latest

docker run -d \
  --name ollama-frontend \
  -p 80:80 \
  --restart unless-stopped \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:arm64-latest
```

### **Multi-Architecture Deployment**

#### **1. Build Universal Images**

```bash
# Create multi-arch backend image
cd backend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:latest \
  --push .

# Create multi-arch frontend image
cd ../frontend
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg VITE_API_URL="https://your-backend-domain.com" \
  -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:latest \
  --push .

# Verify multi-arch images
docker buildx imagetools inspect <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:latest
```

#### **2. Deploy to Mixed Architecture Fleet**

```bash
# The same docker run commands work on both AMD64 and ARM64 instances
# Docker automatically pulls the correct architecture

# On any EC2 instance (AMD64 or ARM64):
docker run -d \
  --name ollama-backend \
  -p 8000:8000 \
  -e OLLAMA_HOST=localhost \
  -e OLLAMA_PORT=11434 \
  --restart unless-stopped \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:latest
```

### **ECS Deployment (Recommended for Production)**

#### **1. ECS Cluster Setup**

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name ollama-chat-cluster

# Create task definition (save as task-definition.json)
cat > task-definition.json << 'EOF'
{
    "family": "ollama-chat-app",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "backend",
            "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend:latest",
            "portMappings": [
                {
                    "containerPort": 8000,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/ollama-chat-backend",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        },
        {
            "name": "frontend",
            "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend:latest",
            "portMappings": [
                {
                    "containerPort": 80,
                    "protocol": "tcp"
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/ollama-chat-frontend",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF

# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

#### **2. ECS Service Deployment**

```bash
# Create ECS service
aws ecs create-service \
    --cluster ollama-chat-cluster \
    --service-name ollama-chat-service \
    --task-definition ollama-chat-app:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678,subnet-87654321],securityGroups=[sg-abcdef12],assignPublicIp=ENABLED}" \
    --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/ollama-chat-tg/1234567890123456,containerName=frontend,containerPort=80
```

---

## CI/CD with GitHub Actions

### **GitHub Actions Workflow Setup**

#### **1. Repository Secrets**

Configure these secrets in GitHub repository settings:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# ECR Repository URLs
ECR_BACKEND_REPOSITORY=123456789012.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-backend
ECR_FRONTEND_REPOSITORY=123456789012.dkr.ecr.us-east-1.amazonaws.com/ollama-chat-frontend

# ECS Configuration
ECS_CLUSTER=ollama-chat-cluster
ECS_SERVICE=ollama-chat-service
ECS_TASK_DEFINITION=ollama-chat-app
```

#### **2. Main CI/CD Workflow**

```yaml
# .github/workflows/deploy.yml
name: Deploy Ollama Chat App

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"
          cache: "npm"
          cache-dependency-path: frontend/package-lock.json

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install frontend dependencies
        run: |
          cd frontend
          npm ci

      - name: Install backend dependencies
        run: |
          cd backend
          pip install -r requirements.txt

      - name: Run frontend tests
        run: |
          cd frontend
          npm run lint
          npm run build

      - name: Run backend tests
        run: |
          cd backend
          python -m pytest tests/ || echo "No tests found"

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push backend image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ secrets.ECR_BACKEND_REPOSITORY }}:latest
            ${{ secrets.ECR_BACKEND_REPOSITORY }}:${{ github.sha }}

      - name: Build and push frontend image
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          platforms: linux/amd64,linux/arm64
          push: true
          build-args: |
            VITE_API_URL=https://api.ollama-chat.example.com
          tags: |
            ${{ secrets.ECR_FRONTEND_REPOSITORY }}:latest
            ${{ secrets.ECR_FRONTEND_REPOSITORY }}:${{ github.sha }}

      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster ${{ secrets.ECS_CLUSTER }} \
            --service ${{ secrets.ECS_SERVICE }} \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ${{ secrets.ECS_CLUSTER }} \
            --services ${{ secrets.ECS_SERVICE }}
```

#### **3. Feature Branch Testing**

```yaml
# .github/workflows/test-pr.yml
name: Test Pull Request

on:
  pull_request:
    branches: [main, develop]

jobs:
  test-changes:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"
          cache: "npm"
          cache-dependency-path: frontend/package-lock.json

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.11"

      - name: Install and test frontend
        run: |
          cd frontend
          npm ci
          npm run lint
          npm run build
          npm run test || echo "No frontend tests configured"

      - name: Install and test backend
        run: |
          cd backend
          pip install -r requirements.txt
          python -c "import app; print('Backend imports successfully')"
          python -m pytest tests/ || echo "No backend tests configured"

      - name: Test Docker builds
        run: |
          docker build -t test-backend backend/
          docker build -t test-frontend frontend/
```

### **Environment-Specific Deployments**

#### **1. Staging Environment**

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [develop]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      # Similar to main deployment but:
      # - Use staging ECR repositories
      # - Use staging ECS cluster
      # - Use staging environment variables
      - name: Build and push to staging
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          platforms: linux/amd64,linux/arm64
          push: true
          build-args: |
            VITE_API_URL=https://api-staging.ollama-chat.example.com
          tags: |
            ${{ secrets.ECR_FRONTEND_REPOSITORY_STAGING }}:latest
```

#### **2. Production Release**

```yaml
# .github/workflows/release.yml
name: Production Release

on:
  release:
    types: [published]

jobs:
  production-deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_PROD }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_PROD }}
          aws-region: ${{ env.AWS_REGION }}

      # Build with release tag
      - name: Build and push production images
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ secrets.ECR_BACKEND_REPOSITORY_PROD }}:latest
            ${{ secrets.ECR_BACKEND_REPOSITORY_PROD }}:${{ github.event.release.tag_name }}
```

---

## Troubleshooting

### **Common Local Development Issues**

#### **1. Backend Issues**

```bash
# Python environment problems
which python3
python3 --version
source venv/bin/activate
which python  # Should point to venv

# Port already in use
sudo lsof -ti:8000 | xargs kill -9

# Dependencies issues
pip list
pip install --upgrade pip
uv pip sync requirements.txt

# Flask not starting
export FLASK_ENV=development
export FLASK_DEBUG=True
python app.py
```

#### **2. Frontend Issues**

```bash
# Node/npm issues
node --version
npm --version
rm -rf node_modules package-lock.json
npm install

# Port already in use
sudo lsof -ti:3000 | xargs kill -9

# Build failures
npm run build
ls -la dist/

# Vite proxy issues
curl -v http://localhost:3000/api/health
# Check vite.config.js proxy settings
```

#### **3. Docker Issues**

```bash
# Docker not running
sudo systemctl status docker
sudo systemctl start docker

# Permission denied
sudo usermod -aG docker $USER
# Log out and log back in

# Build failures
docker system prune -a  # Clean up
docker buildx ls        # Check builders
docker buildx inspect   # Check builder status
```

### **AWS Deployment Issues**

#### **1. Authentication Problems**

```bash
# Check AWS credentials
aws sts get-caller-identity
aws configure list

# ECR login issues
aws ecr get-login-password --region us-east-1
docker login <ecr-uri>

# Permission issues
aws iam get-user
aws iam list-attached-user-policies --user-name <username>
```

#### **2. Container Registry Issues**

```bash
# Repository doesn't exist
aws ecr describe-repositories --repository-names ollama-chat-backend

# Create if missing
aws ecr create-repository --repository-name ollama-chat-backend

# Push failures
docker tag local-image:latest <ecr-uri>:latest
docker push <ecr-uri>:latest
```

#### **3. ECS Deployment Issues**

```bash
# Service not starting
aws ecs describe-services --cluster <cluster> --services <service>
aws ecs describe-tasks --cluster <cluster> --tasks <task-arn>

# Task definition issues
aws ecs describe-task-definition --task-definition <family>:<revision>

# Network connectivity
aws ec2 describe-security-groups --group-ids <sg-id>
aws ec2 describe-subnets --subnet-ids <subnet-id>
```

### **CI/CD Pipeline Issues**

#### **1. GitHub Actions Failures**

```bash
# Check workflow logs in GitHub Actions tab
# Common issues:
# - Missing secrets
# - Incorrect IAM permissions
# - Docker build failures
# - Network connectivity issues

# Debug locally
act  # Run GitHub Actions locally (if act is installed)
```

#### **2. Multi-Architecture Build Issues**

```bash
# Buildx not enabled
docker buildx version
docker buildx create --use

# Platform-specific failures
docker buildx build --platform linux/amd64 .  # Test single platform
docker buildx build --platform linux/arm64 .  # Test single platform

# ARM64 emulation issues
docker run --privileged --rm tonistiigi/binfmt --install all
```

### **Performance Optimization**

#### **1. Local Development**

```bash
# Frontend optimization
npm run build -- --watch  # Watch mode for builds
npm run dev -- --host     # Expose to network

# Backend optimization
gunicorn -w 4 -b 0.0.0.0:8000 app:app  # Multiple workers
python -m cProfile app.py              # Profile performance
```

#### **2. Production Optimization**

```bash
# Docker image optimization
docker images  # Check image sizes
# Use multi-stage builds
# Minimize layers
# Use .dockerignore

# ECS optimization
# Right-size CPU/memory
# Use Application Load Balancer
# Enable auto-scaling
# Monitor CloudWatch metrics
```

### **Monitoring and Logging**

#### **1. Local Monitoring**

```bash
# Container logs
docker logs -f container-name

# System resources
docker stats
htop

# Network debugging
netstat -tlnp
tcpdump -i any port 8000
```

#### **2. AWS Monitoring**

```bash
# CloudWatch logs
aws logs describe-log-groups
aws logs get-log-events --log-group-name /ecs/ollama-chat-backend

# ECS monitoring
aws ecs list-tasks --cluster <cluster>
aws cloudwatch get-metric-statistics --namespace AWS/ECS
```

---

## 📚 Additional Resources

### **Documentation Links**

- [Flask Documentation](https://flask.palletsprojects.com/)
- [React Documentation](https://reactjs.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### **Useful Commands Reference**

```bash
# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline -10'

# Docker shortcuts
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm -f'
alias drmi='docker rmi'

# Development shortcuts
alias backend='cd backend && source venv/bin/activate && python app.py'
alias frontend='cd frontend && npm run dev'
alias build-all='docker build -t backend backend/ && docker build -t frontend frontend/'
```

### **Project Structure Reference**

```
ollama-chat-app/
├── backend/                 # Flask API server
│   ├── app.py              # Main application
│   ├── ollama_connector.py # Ollama integration
│   ├── requirements.txt    # Python dependencies
│   ├── Dockerfile         # Backend container
│   └── venv/              # Virtual environment
├── frontend/               # React application
│   ├── src/               # Source code
│   ├── public/            # Static assets
│   ├── package.json       # Node.js dependencies
│   ├── vite.config.js     # Build configuration
│   └── Dockerfile         # Frontend container
├── infra/                  # Infrastructure as Code
├── .github/workflows/      # CI/CD pipelines
├── docs/                   # Documentation
└── startup_and_dev.md     # This guide
```

- [ ] **Configure VS Code Workspace**
  - **Terminal Setup**: Open integrated terminal (`Ctrl+``)
  - **Split Terminal**: Create multiple terminals for parallel work
    - Terminal 1: Backend development
    - Terminal 2: Frontend development
    - Terminal 3: Git commands & testing
  - **Recommended Extensions** (if not installed):
    - ES7+ React/Redux/React-Native snippets
    - Python
    - ESLint
    - Prettier
    - GitLens
    - Docker

This guide provides a comprehensive workflow for developing, testing, and deploying the Ollama Chat application. Follow the sections sequentially for first-time setup, or use as a reference for specific tasks during ongoing development.
