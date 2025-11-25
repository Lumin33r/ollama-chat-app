# Ollama Chat App - Development & Deployment Guide

A comprehensive guide for local development, git workflow, service testing, and AWS deployment of the Ollama Chat application.

## Table of Contents

- [Quick Start - Daily Development Routine](#quick-start---daily-development-routine)
  - [Service Testing and Verification](#service-testing-and-verification)
- [Quick Start - Daily Development Routine with Containers](#quick-start---daily-development-routine-with-containers)
  - [Container Service Testing and Verification](#container-service-testing-and-verification)
- [How Mounted Volumes Work in Docker with Running Containers](#how-mounted-volumes-work-in-docker-with-running-containers)
- [Initial Project Setup](#initial-project-setup)
  - [Option A: Clone Existing Repository](#option-a-clone-existing-repository)
  - [Option B: Initialize New Repository from Scratch](#option-b-initialize-new-repository-from-scratch)
- [Local Development Environment](#local-development-environment)
- [Development vs Production Docker Containers](#development-vs-production-docker-containers)
- [Frontend Development Guide](#frontend-development-guide)
- [Ollama Service Guide](#ollama-service-guide)
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

## Quick Start - Daily Development Routine with Containers

### **Start of Development Session**

#### **1. System Startup & Prerequisites**

- [ ] **Start Docker Desktop**

  ```bash
  # From Windows Start Menu, start Docker Desktop
  # Linux: Start Docker daemon
  sudo systemctl start docker
  sudo systemctl status docker  # Verify running

  # Verify Docker is working
  docker ps
  docker version
  docker compose version  # Verify compose plugin
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

- [ ] **Check for Configuration or Image Changes**

  ```bash
  # Check if Docker files changed (may need rebuild)
  git diff HEAD@{1} HEAD -- docker-compose*.yml
  git diff HEAD@{1} HEAD -- "*Dockerfile*"

  # Check if dependencies changed
  git diff HEAD@{1} HEAD -- backend/requirements.txt
  git diff HEAD@{1} HEAD -- frontend/package.json
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

#### **4. Start Development Services with Docker Compose**

- [ ] **Clean Up Previous Containers (Optional)**

  ```bash
  # Check running containers
  docker ps

  # Stop and remove previous dev containers if needed
  docker compose -f docker-compose.yml -f docker-compose.dev.yml down

  # Optional: Remove volumes if you need fresh start
  docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v

  # Optional: Prune unused containers/images/networks
  docker system prune -f
  ```

- [ ] **Build or Rebuild Images (if needed)**

  ```bash
  # Rebuild if Dockerfile or dependencies changed
  docker compose -f docker-compose.yml -f docker-compose.dev.yml build

  # Force rebuild without cache (if having issues)
  docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

  # Rebuild specific service
  docker compose -f docker-compose.yml -f docker-compose.dev.yml build backend
  docker compose -f docker-compose.yml -f docker-compose.dev.yml build frontend
  ```

- [ ] **Start All Development Services**

  ```bash
  # Start all services in development mode
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up

  # Or run in detached mode (background)
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

  # Expected services:
  # - ollama-service (port 11434)
  # - backend (port 8000)
  # - frontend (port 3000)
  ```

- [ ] **Verify Services are Running**

  ```bash
  # Check container status
  docker compose -f docker-compose.yml -f docker-compose.dev.yml ps

  # Expected output:
  # NAME                    STATUS              PORTS
  # ollama-service          Up X minutes        0.0.0.0:11434->11434/tcp
  # ollama-backend          Up X minutes        0.0.0.0:8000->8000/tcp
  # ollama-frontend         Up X minutes        0.0.0.0:3000->3000/tcp

  # Check logs for all services
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs

  # Follow logs in real-time
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

  # View logs for specific service
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f frontend
  ```

- [ ] **Test Services are Accessible**

  ```bash
  # Test backend health endpoint
  curl http://localhost:8000/health
  # Expected: {"status": "healthy"}

  # Test frontend
  curl -I http://localhost:3000
  # Expected: HTTP/1.1 200 OK

  # Test Ollama service
  curl http://localhost:11434/api/tags
  # Expected: JSON with model list

  # Open frontend in browser
  xdg-open http://localhost:3000  # Linux
  # or manually navigate to http://localhost:3000
  ```

### **During Development Session**

#### **5. Understanding Container Development Flow**

- [ ] **Volume Mounts Enable Live Reload**

  ```bash
  # Your local code is mounted into containers:
  # ./backend:/app  -> Backend container
  # ./frontend:/app -> Frontend container

  # Changes to local files are immediately reflected in containers
  # No need to rebuild images for code changes

  # View mounted volumes
  docker compose -f docker-compose.yml -f docker-compose.dev.yml config | grep -A 5 volumes
  ```

- [ ] **Choose Files to Work On**

  ```bash
  # Frontend work (files auto-reload in container):
  # - frontend/src/components/
  # - frontend/src/App.jsx
  # - frontend/src/index.css
  # - frontend/vite.config.js

  # Backend work (files auto-reload in container):
  # - backend/app.py
  # - backend/ollama_connector.py
  # - backend/requirements.txt (requires rebuild)

  # Edit files normally in VS Code
  # Container will detect changes and reload automatically
  ```

#### **6. Development Workflow with Containers**

- [ ] **Make Code Changes**

  - Edit files in VS Code as normal
  - Save frequently (`Ctrl+S`)
  - Changes automatically sync to container via volume mount
  - Frontend: Vite hot reload happens automatically
  - Backend: Flask debug mode reloads on file changes

- [ ] **Monitor Container Logs**

  ```bash
  # Watch all logs in real-time
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

  # Watch specific service logs
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f frontend

  # See last 50 lines of logs
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs --tail=50
  ```

- [ ] **Execute Commands Inside Containers**

  ```bash
  # Open bash shell in backend container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash

  # Inside container, you can:
  # - Run Python commands
  # - Install packages: pip install <package>
  # - Run tests: pytest
  # - Check environment: env | grep FLASK

  # Open shell in frontend container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend sh

  # Inside container, you can:
  # - Run npm commands
  # - Install packages: npm install <package>
  # - Check build: npm run build
  ```

- [ ] **Check Changes as You Go**

  ```bash
  # View current code changes (same as non-container workflow)
  git status
  git diff

  # View specific file changes
  git diff frontend/src/App.jsx
  git diff backend/app.py
  ```

### **Container Service Testing and Verification**

#### **7A. Ollama Service Container Testing**

- [ ] **Verify Ollama Container is Running**

  ```bash
  # Check ollama-service container status
  docker compose -f docker-compose.yml -f docker-compose.dev.yml ps ollama-service

  # View ollama-service logs
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs ollama-service

  # Check health status
  docker inspect ollama-service --format='{{.State.Health.Status}}'
  # Expected: healthy
  ```

- [ ] **Test Ollama API from Host**

  ```bash
  # List available models
  curl http://localhost:11434/api/tags

  # Expected output: JSON with model list
  # {"models": [{"name": "llama2:latest", ...}]}

  # Test chat functionality
  curl -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{
      "model": "llama2",
      "prompt": "Hello, how are you?",
      "stream": false
    }'

  # Expected: JSON response with model output
  ```

- [ ] **Interact with Ollama Inside Container**

  ```bash
  # Execute ollama commands inside container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec ollama-service ollama list

  # Pull a new model
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec ollama-service ollama pull llama2

  # Test model directly
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec ollama-service ollama run llama2 "What is 2+2?"
  ```

#### **7B. Backend Container Testing**

- [ ] **Verify Backend Container is Running**

  ```bash
  # Check backend container status
  docker compose -f docker-compose.yml -f docker-compose.dev.yml ps backend

  # View backend logs
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend

  # Expected output:
  # * Running on http://0.0.0.0:8000
  # * Debug mode: on
  ```

- [ ] **Test Backend Health Endpoint**

  ```bash
  # Test from host
  curl http://localhost:8000/health

  # Expected response:
  # {"status":"healthy"}

  # Check response code
  curl -I http://localhost:8000/health
  # Expected: HTTP/1.1 200 OK
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
  ```

- [ ] **Run Commands Inside Backend Container**

  ```bash
  # Open bash shell in backend container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash

  # Inside container:
  # Check Python version
  python --version

  # List installed packages
  pip list

  # Run tests
  pytest tests/ -v

  # Test imports
  python -c "import app; print('Backend OK')"

  # Exit container
  exit
  ```

#### **7C. Frontend Container Testing**

- [ ] **Verify Frontend Container is Running**

  ```bash
  # Check frontend container status
  docker compose -f docker-compose.yml -f docker-compose.dev.yml ps frontend

  # View frontend logs (see Vite output)
  docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f frontend

  # Expected output:
  # VITE v5.4.21  ready in XXX ms
  # ➜  Local:   http://localhost:3000/
  ```

- [ ] **Test Frontend Accessibility**

  ```bash
  # Test frontend loads
  curl -I http://localhost:3000

  # Expected: HTTP/1.1 200 OK with HTML content-type

  # Open in browser
  xdg-open http://localhost:3000  # Linux
  # or manually navigate in browser
  ```

- [ ] **Run Frontend Commands Inside Container**

  ```bash
  # Open shell in frontend container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend sh

  # Inside container:
  # List node modules
  ls node_modules/

  # Run linter
  npm run lint

  # Build for production
  npm run build

  # Check Node version
  node --version

  # Exit container
  exit
  ```

#### **7D. Integration Testing with Containers**

- [ ] **End-to-End Container Testing**

  1. **Verify All Containers Running**

     ```bash
     docker compose -f docker-compose.yml -f docker-compose.dev.yml ps
     # Should show 3 services: ollama-service, backend, frontend
     ```

  2. **Test Container Networking**

     ```bash
     # Backend should reach Ollama via container network
     docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend curl http://ollama-service:11434/api/tags

     # Expected: JSON with model list (proves inter-container networking works)
     ```

  3. **Test Full User Flow**

     - Open frontend: http://localhost:3000
     - Enter chat message
     - Verify message sent to backend (check Network tab)
     - Verify backend calls Ollama (check backend logs)
     - Verify response displayed in frontend

  4. **Monitor All Logs Simultaneously**
     ```bash
     # Watch all service logs together
     docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
     # Send a chat message and watch the request flow through all services
     ```

#### **7E. Pre-Commit Testing with Containers**

- [ ] **Frontend Testing in Container**

  ```bash
  # Run linter inside container
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend npm run lint

  # Fix auto-fixable issues
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend npm run lint -- --fix

  # Build for production
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend npm run build
  ```

- [ ] **Backend Testing in Container**

  ```bash
  # Run unit tests
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend pytest tests/ -v

  # Check imports
  docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend python -c "import app; print('Backend OK')"

  # Test API endpoints
  curl http://localhost:8000/health
  curl -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -d '{"prompt": "test", "session_id": "test"}'
  ```

### **Committing Your Work**

#### **8. Stage and Review Changes**

- [ ] **Review What Changed**

  ```bash
  # See all changes (code files, not containers)
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
  git add backend/app.py

  # If you modified Docker configuration
  git add docker-compose.yml
  git add docker-compose.dev.yml
  git add backend/Dockerfile
  git add frontend/Dockerfile.dev

  # If you added dependencies
  git add backend/requirements.txt
  git add frontend/package.json
  git add frontend/package-lock.json

  # Verify what's staged
  git status
  ```

- [ ] **Review Before Committing**

  ```bash
  # Double-check staged changes
  git diff --staged

  # If you staged something by mistake
  git reset HEAD <filename>  # Unstage specific file
  ```

#### **9. Commit with Good Message**

- [ ] **Write Descriptive Commit Message**

  ```bash
  # Use conventional commit format
  git commit -m "feat: add message persistence to chat interface

  - Implement localStorage integration for chat history
  - Add conversation save/load functionality
  - Update ChatInterface component with auto-save
  - Update Docker dev environment for testing
  - Add error handling for storage quota exceeded

  Closes #42"

  # Commit types:
  # feat:     New feature
  # fix:      Bug fix
  # docs:     Documentation changes
  # style:    Formatting, missing semicolons, etc.
  # refactor: Code restructuring
  # test:     Adding tests
  # chore:    Maintenance tasks (dependencies, Docker config)
  ```

- [ ] **Verify Commit**

  ```bash
  # Check commit was created
  git log --oneline -1

  # View commit details
  git show HEAD
  ```

### **Syncing Your Work**

#### **10. Push to Remote Repository**

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

#### **11. Create Pull Request (if ready)**

- [ ] **Open GitHub PR**
  - Go to repository on GitHub
  - Click "Compare & pull request" button
  - Fill in PR template:
    - **Title**: Clear, descriptive title
    - **Description**: What changed and why
    - **Testing**: Specify tested in Docker dev environment
    - **Screenshots**: If UI changes
  - Link related issues: "Closes #42"
  - Request reviewers
  - Add labels (feature, bug, etc.)

#### **12. Clean Up Containers**

- [ ] **Stop Development Containers**

  ```bash
  # Stop all containers (preserves volumes)
  docker compose -f docker-compose.yml -f docker-compose.dev.yml stop

  # Or stop and remove containers
  docker compose -f docker-compose.yml -f docker-compose.dev.yml down

  # Stop and remove containers AND volumes (fresh start next time)
  docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v

  # View remaining containers
  docker ps -a
  ```

- [ ] **Optional: Clean Up Docker Resources**

  ```bash
  # Remove stopped containers
  docker container prune -f

  # Remove unused images
  docker image prune -f

  # Remove unused volumes
  docker volume prune -f

  # Remove all unused resources (be careful!)
  docker system prune -af
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

#### **13. Resume Development with Containers**

- [ ] **Start Docker** (if not running)
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

- [ ] **Start containers**

  ```bash
  docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
  ```

- [ ] **Continue coding!**

---

### **Quick Reference Commands**

#### **Essential Docker Compose Commands**

```bash
# Start services (development mode)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d  # detached

# Stop services
docker compose -f docker-compose.yml -f docker-compose.dev.yml stop
docker compose -f docker-compose.yml -f docker-compose.dev.yml down     # remove containers
docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v  # remove volumes too

# Rebuild services
docker compose -f docker-compose.yml -f docker-compose.dev.yml build
docker compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

# View logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f           # follow
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend  # specific service

# Check status
docker compose -f docker-compose.yml -f docker-compose.dev.yml ps

# Execute commands in containers
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend sh

# Restart specific service
docker compose -f docker-compose.yml -f docker-compose.dev.yml restart backend
```

---

## How Mounted Volumes Work in Docker with Running Containers

### **The Big Picture**

Mounted volumes create a **live connection** between your host filesystem and the container's filesystem. Think of it like a "portal" or "window" between two worlds.

```
┌─────────────────────────────────────────────────────┐
│              Your Computer (Host)                    │
│                                                      │
│  ~/codeplatoon/projects/ollama-chat-app/            │
│  ├── frontend/                                       │
│  │   ├── src/                                        │
│  │   │   ├── App.jsx         ◄──────────┐           │
│  │   │   └── components/               │           │
│  │   └── package.json                  │           │
│  └── backend/                           │           │
│      ├── app.py               ◄─────────┤           │
│      └── ollama_connector.py            │           │
│                                         │           │
└─────────────────────────────────────────┼───────────┘
                                         │
                    VOLUME MOUNT (bind mount)
                    Real-time synchronization
                                         │
┌─────────────────────────────────────────┼───────────┐
│         Docker Container                │           │
│                                         │           │
│  /src/                                  │           │
│  ├── src/                               │           │
│  │   ├── App.jsx         ◄──────────────┘           │
│  │   └── components/                                │
│  └── package.json                                   │
│                                                      │
│  Changes to files are IMMEDIATELY visible           │
│  in BOTH locations (host and container)             │
└─────────────────────────────────────────────────────┘
```

---

### **Types of Volume Mounts**

Docker supports three types of mounts:

#### **1. Bind Mounts (What We Use in Dev)**

```yaml
# docker-compose.dev.yml
services:
  frontend:
    volumes:
      - ./frontend:/src # Bind mount
      # Maps: ./frontend (host) → /src (container)
```

**How it works:**

- **Host directory** `./frontend` is mounted **into** container at `/src`
- Files exist in **one place** on disk (your host)
- Container sees them as if they were inside `/src`
- Changes in **either location** are instantly visible in **both**

**Analogy:** It's like creating a shortcut/symlink. The files aren't copied; the container just "looks through" to your host filesystem.

#### **2. Named Volumes (For Persistent Data)**

```yaml
# docker-compose.yml
services:
  ollama-service:
    volumes:
      - ollama-models:/root/.ollama # Named volume

volumes:
  ollama-models: # Docker manages this volume
    driver: local
```

**How it works:**

- Docker creates and manages the volume
- Stored in Docker's data directory: `/var/lib/docker/volumes/`
- Data persists even when container is deleted
- Not directly accessible from host (without Docker commands)

**Use cases:**

- Database data
- Application state
- Uploaded files
- Model weights (Ollama models)

#### **3. Anonymous Volumes (Temporary Data)**

```yaml
services:
  frontend:
    volumes:
      - /src/node_modules # Anonymous volume
```

**How it works:**

- Docker creates a temporary volume
- Automatically deleted when container is removed
- Used to prevent host files from overwriting container files

---

### **Live Reload Magic: How It Actually Works**

#### **Development Scenario (Hot Reload)**

```yaml
# docker-compose.dev.yml
services:
  frontend:
    volumes:
      - ./frontend:/src # Mount source code
      - /src/node_modules # Preserve node_modules
    command: npm run dev
```

**Step-by-Step Process:**

```
1. You edit App.jsx in VS Code on your host
   ~/codeplatoon/projects/ollama-chat-app/frontend/src/App.jsx

   ↓

2. File change is IMMEDIATELY written to disk
   (Your host filesystem)

   ↓

3. Because ./frontend is mounted to /src in container,
   the container IMMEDIATELY sees the change at:
   /src/src/App.jsx

   ↓

4. Vite dev server (running inside container) has
   file watchers that detect the change

   ↓

5. Vite triggers Hot Module Replacement (HMR)
   - Recompiles only changed module
   - Pushes update to browser via WebSocket

   ↓

6. Browser updates UI WITHOUT full page reload

   Total time: < 1 second
```

**Why This is Fast:**

- ✅ No image rebuild needed
- ✅ No container restart needed
- ✅ Only changed files are recompiled
- ✅ Browser state is preserved

---

### **Volume Mount Mechanics**

#### **Behind the Scenes (Linux)**

When you mount `./frontend:/src`:

```bash
# Docker creates a bind mount using Linux kernel features

# Check mounts in running container
docker compose exec frontend mount | grep /src

# Output:
# /dev/sda1 on /src type ext4 (rw,relatime)
# This shows /src is actually pointing to your host disk
```

**Kernel-level Operations:**

1. Docker uses **Linux namespaces** to isolate container filesystem
2. Bind mount uses **VFS (Virtual File System)** layer
3. Container's `/src` directory becomes a **mount point**
4. Inode pointers redirect to host filesystem location
5. File operations (read/write) go directly to host disk

#### **File Watching in Containers**

```javascript
// Vite dev server (inside container)
import { watch } from "chokidar";

// Watches /src/src for changes
const watcher = watch("/src/src/**/*.{js,jsx,ts,tsx}", {
  ignoreInitial: true,
  persistent: true,
});

watcher.on("change", (path) => {
  console.log(`File changed: ${path}`);
  // Trigger hot reload
  hmr.send({ type: "update", path });
});
```

**File System Events:**

```
1. You save App.jsx
   ↓
2. Host OS fires inotify event (Linux)
   ↓
3. Event propagates through mount point
   ↓
4. Chokidar (in container) receives event
   ↓
5. Vite triggers recompile
```

---

### **Production vs Development Volumes**

#### **Development (docker-compose.dev.yml)**

```yaml
services:
  backend:
    volumes:
      - ./backend:/app # MOUNTED (live sync)
    environment:
      - FLASK_DEBUG=1
    command: python app.py # Development server with auto-reload
```

**What happens:**

```
Edit app.py on host
    ↓
Change visible in container immediately
    ↓
Flask detects change (werkzeug reloader)
    ↓
Flask restarts server
    ↓
Total time: 1-2 seconds
```

#### **Production (docker-compose.prod.yml)**

```yaml
services:
  backend:
    # NO volumes!
    # Code baked into image during build
    command: gunicorn app:app # Production WSGI server
```

**What happens:**

```
Edit app.py on host
    ↓
NO EFFECT on running container!
    ↓
Must rebuild image:
    docker compose build backend
    ↓
Redeploy container:
    docker compose up -d backend
    ↓
Total time: 2-5 minutes
```

---

### **Volume Mount Patterns in Your Project**

#### **Frontend Volume Strategy**

```yaml
# docker-compose.dev.yml
services:
  frontend:
    volumes:
      - ./frontend:/src # Mount source code
      - /src/node_modules # IMPORTANT: Preserve node_modules
```

**Why `/src/node_modules` exception?**

```
Problem without it:
┌────────────────────────────────────────┐
│ Host: ./frontend/                      │
│  ├── src/                              │
│  ├── package.json                      │
│  └── node_modules/  (empty or wrong)  │ ◄─ This overwrites...
└────────────────────────────────────────┘
                  ↓ Mount
┌────────────────────────────────────────┐
│ Container: /src/                       │
│  ├── src/                              │
│  ├── package.json                      │
│  └── node_modules/  (installed inside)│ ◄─ ...this! (breaks build)
└────────────────────────────────────────┘

Solution with anonymous volume:
┌────────────────────────────────────────┐
│ Host: ./frontend/                      │
│  ├── src/           ─────────┐         │
│  ├── package.json   ─────────┼─────────┼─ Mounted
│  └── node_modules/  (ignored)│         │
└──────────────────────────────┼─────────┘
                              │
                              ↓ Mount
┌──────────────────────────────┼─────────┐
│ Container: /src/            │         │
│  ├── src/           ◄───────┘         │
│  ├── package.json   ◄─────────────────┘
│  └── node_modules/  (preserved in anonymous volume)
└────────────────────────────────────────┘
```

**Effect:**

- ✅ Source code syncs (live reload)
- ✅ node_modules preserved (correct dependencies)
- ✅ No conflicts between host and container packages

#### **Backend Volume Strategy**

```yaml
# docker-compose.dev.yml
services:
  backend:
    volumes:
      - ./backend:/app # Mount Python code
      # No need for __pycache__ exception (Python auto-handles)
```

**Python-specific behavior:**

- `__pycache__/` directories are created on-demand
- `.pyc` files are bytecode (platform-independent)
- Flask reloader detects `.py` file changes
- No dependency conflicts (pip installs in container's venv)

---

### **Practical Examples**

#### **Example 1: Edit Frontend Code**

```bash
# Start dev environment
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# In VS Code, edit: frontend/src/App.jsx
# Change line 42:
<h1>Ollama Chat</h1>
# to:
<h1>My AI Assistant</h1>

# Save file (Ctrl+S)
```

**What happens immediately:**

```
1. File saved to:
   ~/codeplatoon/projects/ollama-chat-app/frontend/src/App.jsx

2. Container sees change at:
   /src/src/App.jsx (same file, via bind mount)

3. Vite output in terminal:
   [vite] hot updated: /src/src/App.jsx

4. Browser refreshes automatically
   (no manual refresh needed)

5. New heading visible in UI
```

#### **Example 2: Edit Backend Code**

```bash
# Backend is running in container
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend

# In VS Code, edit: backend/app.py
# Change line 25:
return {"status": "healthy"}
# to:
return {"status": "healthy", "version": "1.0.0"}

# Save file (Ctrl+S)
```

**What happens immediately:**

```
1. File saved to:
   ~/codeplatoon/projects/ollama-chat-app/backend/app.py

2. Container sees change at:
   /app/app.py (same file, via bind mount)

3. Flask reloader output:
   * Detected change in '/app/app.py', reloading
   * Restarting with stat

4. Flask restarts (1-2 seconds)

5. New endpoint response:
   curl http://localhost:8000/health
   {"status": "healthy", "version": "1.0.0"}
```

#### **Example 3: Install New Dependencies**

```bash
# Install new npm package
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend npm install axios

# What happens:
# 1. npm installs axios into /src/node_modules/ (inside container)
# 2. package.json updated in /src/ (synced to host via mount)
# 3. package-lock.json updated in /src/ (synced to host)
# 4. node_modules/ stays inside container (anonymous volume)

# Result on host:
ls frontend/
# package.json     ✅ Updated
# package-lock.json ✅ Updated
# node_modules/    ❌ Not updated (preserved in container)

# Import in code works immediately:
import axios from 'axios';  // ✅ Works (container has it)
```

---

### **Debugging Volume Mounts**

#### **Check Active Mounts**

```bash
# Inspect running container's mounts
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend mount | grep /src

# Output:
# /dev/sda1 on /src type ext4 (rw,relatime)
# tmpfs on /src/node_modules type tmpfs (rw)

# Detailed volume info
docker inspect ollama-frontend | jq '.[0].Mounts'
```

**Example output:**

```json
[
  {
    "Type": "bind",
    "Source": "/home/lumineer/codeplatoon/projects/ollama-chat-app/frontend",
    "Destination": "/src",
    "Mode": "rw",
    "RW": true,
    "Propagation": "rprivate"
  },
  {
    "Type": "volume",
    "Name": "1234567890abcdef",
    "Source": "/var/lib/docker/volumes/1234567890abcdef/_data",
    "Destination": "/src/node_modules",
    "Driver": "local",
    "Mode": "z",
    "RW": true,
    "Propagation": ""
  }
]
```

#### **Test File Sync**

```bash
# Create test file on host
echo "test" > frontend/test.txt

# Check if visible in container
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend cat /src/test.txt
# Output: test

# Create file in container
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend sh -c "echo 'from container' > /src/container-test.txt"

# Check if visible on host
cat frontend/container-test.txt
# Output: from container
```

#### **Common Volume Issues**

```bash
# Issue 1: Changes not syncing
# Check if volume is actually mounted
docker compose -f docker-compose.yml -f docker-compose.dev.yml config | grep -A 5 volumes

# Issue 2: Permission denied
# Container user doesn't match host user
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend id
# uid=1000(node) gid=1000(node)

ls -la frontend/
# drwxr-xr-x  5 lumineer lumineer  4096 Nov 25 10:00 frontend/

# Fix: Run container as host user
user: "${UID}:${GID}"  # Add to docker-compose.dev.yml

# Issue 3: node_modules disappearing
# Anonymous volume not configured correctly
volumes:
  - ./frontend:/src
  - /src/node_modules  # Must be AFTER the bind mount
```

---

### **Performance Considerations**

#### **File System Performance**

**On Linux (Native Docker):**

- ✅ Native performance
- ✅ inotify events work perfectly
- ✅ No overhead

**On macOS (Docker Desktop):**

- ⚠️ Slower (osxfs or VirtioFS layer)
- ⚠️ File watching can be slower
- 💡 Solution: Use delegated/cached mounts

```yaml
# macOS optimization
volumes:
  - ./frontend:/src:delegated # Prioritize container writes
  - ./backend:/app:cached # Prioritize host reads
```

**On Windows (Docker Desktop with WSL2):**

- ✅ Good performance in WSL2
- ⚠️ Slower if mounting from Windows filesystem
- 💡 Solution: Keep project in WSL2 filesystem

#### **Watch Mode Configuration**

```javascript
// vite.config.js - Force polling for problematic filesystems
export default defineConfig({
  server: {
    watch: {
      usePolling: true, // Force polling
      interval: 100, // Poll every 100ms
    },
  },
});
```

```python
# Flask - Use polling instead of inotify
# app.py
app.run(debug=True, use_reloader=True, reloader_type='stat')
```

---

### **Summary: Volume Mounts Explained**

| Aspect          | How It Works                                                          |
| --------------- | --------------------------------------------------------------------- |
| **What**        | Bind mount creates direct connection between host and container paths |
| **Speed**       | Near-instantaneous (same as local filesystem)                         |
| **Direction**   | Bidirectional (changes sync both ways)                                |
| **Persistence** | Files exist on host, survive container deletion                       |
| **Use Case**    | Development: live reload, hot module replacement                      |
| **Trade-off**   | Not suitable for production (security, coupling)                      |

**Key Takeaways:**

1. ✅ Mounted volumes are **not copies** - they're **live connections**
2. ✅ Changes in host **instantly visible** in container (and vice versa)
3. ✅ Enables **hot reload** without rebuilding images
4. ✅ Anonymous volumes (`/src/node_modules`) **prevent conflicts**
5. ❌ **Never use** in production (security risk)
6. ✅ Production: bake code into image, no mounts

This is why `docker-compose.dev.yml` enables rapid development while `docker-compose.prod.yml` focuses on immutable, reproducible deployments! 🚀

---

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

## Development vs Production Docker Containers

### **Table of Contents**

This comprehensive section explains:

1. [Why Two Sets of Containers?](#why-two-sets-of-containers) - Different priorities (speed vs security/performance)
2. [Key Differences Explained](#key-differences-explained) - File watching, image size, logging, security, database, resources, health checks
3. [Complete Docker Compose Examples](#complete-docker-compose-examples) - Base + dev + prod compose files from our project
4. [Dockerfile Architecture](#dockerfile-architecture) - Separate dev and prod Dockerfiles
5. [Development Workflow](#development-workflow-with-docker) - How to use dev environment
6. [Production Workflow](#production-workflow-with-docker) - How to build and deploy prod
7. [Cost & Performance Impact](#cost--performance-impact) - Real-world comparison
8. [When to Rebuild](#when-to-rebuild-containers) - Dev vs prod rebuild strategies
9. [Summary Comparison Table](#summary-dev-vs-prod-containers) - Quick reference
10. [Best Practices](#container-best-practices) - Dos and don'ts

---

### Why Two Sets of Containers?

Development and production containers serve **fundamentally different purposes** and operate in different environments with different priorities.

```
Development Priority: Fast iteration, debugging, convenience
Production Priority: Security, performance, reliability, cost

┌─────────────────────────────────────────────────────┐
│  Development Containers (docker-compose.dev.yml)    │
│  Goal: Make development fast and easy               │
│  - Hot reload (code changes reflect immediately)    │
│  - Debug tools included                             │
│  - Verbose logging                                  │
│  - Permissive security                              │
│  - Runs on your laptop                              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Production Containers (docker-compose.prod.yml)    │
│  Goal: Optimize for performance, security, cost     │
│  - Compiled/optimized code                          │
│  - Minimal image size                               │
│  - Production logging                               │
│  - Strict security                                  │
│  - Runs on AWS EC2                                  │
└─────────────────────────────────────────────────────┘
```

---

### Key Differences Explained

#### **1. File Watching & Hot Reload**

**Development:**

```yaml
# docker-compose.dev.yml
services:
  frontend:
    volumes:
      - ./frontend:/app # Mount source code
      - /app/node_modules # Preserve node_modules
    command: npm run dev # Vite dev server with HMR
```

**Why:** Code changes appear instantly without rebuilding. Essential for fast iteration.

**Production:**

```yaml
# docker-compose.prod.yml
services:
  frontend:
    # NO volumes mounted
    # Code baked into image during build
```

**Why:** Pre-built static files are faster, more secure, and don't need the dev server overhead.

---

#### **2. Image Size & Build Strategy**

**Development Dockerfile:**

```dockerfile
# frontend/Dockerfile.dev
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies)
RUN npm install

# Copy source code
COPY . .

# Expose Vite dev server port
EXPOSE 3000

# Start dev server
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# Image size: ~350MB (includes all dev dependencies)
```

**Production Dockerfile (Multi-stage):**

```dockerfile
# frontend/Dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build argument for API URL
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=$VITE_API_URL

# Build optimized static files
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:stable-alpine

# Copy ONLY built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

# Image size: ~25MB (85% smaller!)
```

**Why:** Smaller images = faster deploys, lower bandwidth costs, reduced attack surface.

---

#### **3. Logging & Debugging**

**Development:**

```yaml
# docker-compose.dev.yml
services:
  backend:
    environment:
      FLASK_ENV: development
      FLASK_DEBUG: "True" # Enable Flask debugger
    command: python app.py # Development server with auto-reload
```

**Production:**

```yaml
# docker-compose.prod.yml
services:
  backend:
    environment:
      FLASK_ENV: production
      FLASK_DEBUG: "False" # Disable debug mode (security risk)
    command: gunicorn --bind 0.0.0.0:8000 --workers 4 app:app
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Why:** Verbose dev logs help debugging. Production logs are concise, structured, and rotated to prevent disk fill.

---

#### **4. Resource Limits**

**Development:**

```yaml
# docker-compose.dev.yml
services:
  ollama-service:
    # No resource limits - use all available resources
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Production:**

```yaml
# docker-compose.prod.yml
services:
  ollama-service:
    deploy:
      resources:
        limits:
          memory: 8G # Maximum memory usage
        reservations:
          memory: 4G # Minimum guaranteed memory
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Why:** Dev can use all resources. Prod limits prevent resource exhaustion and enable predictable scaling.

---

#### **5. Health Checks & Restart Policies**

**Development:**

```yaml
# docker-compose.yml (base config)
services:
  backend:
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

**Production:**

```yaml
# docker-compose.prod.yml
services:
  backend:
    deploy:
      replicas: 2 # Run 2 instances for high availability
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Why:** Prod needs automatic recovery, health monitoring, and redundancy for zero-downtime deployments.

---

### Complete Docker Compose Examples

Our project uses a **three-file strategy**: base + environment-specific overrides.

#### **Base Configuration (docker-compose.yml)**

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
  ollama-service:
    image: ollama/ollama:latest
    container_name: ollama-service
    ports:
      - "11434:11434"
    volumes:
      - ollama-models:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 60s
    networks:
      - ollama-network

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

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: ollama-frontend
    ports:
      - "3000:3000"
    environment:
      VITE_API_URL: http://localhost:8000
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - ollama-network
```

#### **Development Overrides (docker-compose.dev.yml)**

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

#### **Production Overrides (docker-compose.prod.yml)**

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
      replicas: 2 # High availability
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
      replicas: 2 # High availability
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

### Dockerfile Architecture

#### **Backend Dockerfile (Production)**

```dockerfile
# backend/Dockerfile
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

**Key Features:**

- Single-stage (simpler for backend)
- Includes curl for health checks
- Uses gunicorn for production WSGI server
- Health check built into image

#### **Frontend Development Dockerfile**

```dockerfile
# frontend/Dockerfile.dev
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

**Key Features:**

- Simple single-stage
- Includes all dev dependencies
- Runs Vite dev server
- Source code mounted via volume for hot reload

#### **Frontend Production Dockerfile (Multi-stage)**

```dockerfile
# frontend/Dockerfile
# Multi-stage build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build argument for API URL
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=$VITE_API_URL

# Build React app
RUN npm run build

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

**Key Features:**

- Two-stage build (builder + nginx)
- Discards build tools and dependencies
- Uses nginx for efficient static file serving
- Configurable API URL at build time

---

### Development Workflow with Docker

#### **Start Development Environment**

```bash
cd ~/codeplatoon/projects/ollama-chat-app

# Start dev environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Or detached mode
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Stop services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
```

#### **Development Features**

- **Hot Reload:** Changes to `frontend/src/` reflect instantly
- **Auto-restart:** Backend restarts when code changes
- **Verbose Logs:** See detailed debug information
- **No Rebuilds:** Most code changes don't require image rebuild

#### **When to Rebuild Dev Images**

```bash
# Rebuild when:
# - package.json changes (new npm packages)
# - requirements.txt changes (new Python packages)
# - Dockerfile changes

docker-compose -f docker-compose.yml -f docker-compose.dev.yml build
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

---

### Production Workflow with Docker

#### **Build Production Images**

```bash
cd ~/codeplatoon/projects/ollama-chat-app

# Build production images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Build with specific API URL
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build \
  --build-arg VITE_API_URL=https://api.yourdomain.com

# View built images
docker images | grep ollama
```

#### **Test Production Build Locally**

```bash
# Start production environment locally
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:3000

# Stop when done
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
```

#### **Tag and Push to Registry**

```bash
# Tag images
docker tag ollama-chat-app-frontend:latest your-registry/ollama-frontend:v1.0.0
docker tag ollama-chat-app-backend:latest your-registry/ollama-backend:v1.0.0

# Push to registry
docker push your-registry/ollama-frontend:v1.0.0
docker push your-registry/ollama-backend:v1.0.0
```

#### **Deploy to AWS EC2**

```bash
# SSH to EC2 instance
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# On remote instance:
# Pull images
docker pull your-registry/ollama-frontend:v1.0.0
docker pull your-registry/ollama-backend:v1.0.0

# Update docker-compose.yml with new image tags

# Start production containers
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verify deployment
docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
curl http://localhost:8000/health
```

---

### Cost & Performance Impact

| Aspect                      | Development         | Production                    |
| --------------------------- | ------------------- | ----------------------------- |
| **Frontend Image Size**     | 350MB               | 25MB (93% smaller)            |
| **Backend Image Size**      | 450MB               | 250MB (44% smaller)           |
| **Memory Usage (Frontend)** | 1GB                 | 100MB                         |
| **Memory Usage (Backend)**  | 500MB               | 200MB                         |
| **CPU Usage**               | High (hot reload)   | Low (optimized)               |
| **Startup Time**            | 30 seconds          | 5 seconds                     |
| **Request Latency**         | 200ms (dev server)  | 10ms (nginx)                  |
| **Build Time**              | 3 minutes           | 5 minutes (multi-stage)       |
| **Monthly Cost**            | $0 (local)          | $50-500 (EC2)                 |
| **Deploy Time**             | Instant (no deploy) | 10 minutes (build + transfer) |

---

### When to Rebuild Containers

#### **Development**

```bash
# Rebuild when:
# ✅ package.json changes (new npm packages)
# ✅ requirements.txt changes (new Python packages)
# ✅ Dockerfile changes

docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

# For most code changes: ❌ NO rebuild needed
# Volumes auto-sync changes
```

#### **Production**

```bash
# Rebuild for EVERY code change (no volumes)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Tag with version
docker tag ollama-frontend:latest your-registry/ollama-frontend:v1.0.1

# Push and deploy
docker push your-registry/ollama-frontend:v1.0.1
```

---

### Summary: Dev vs Prod Containers

| Feature             | Development                   | Production                      |
| ------------------- | ----------------------------- | ------------------------------- |
| **Purpose**         | Fast iteration                | Optimized performance           |
| **Source Code**     | Mounted as volume             | Baked into image                |
| **Dependencies**    | All (including dev tools)     | Production only                 |
| **Hot Reload**      | ✅ Yes                        | ❌ No                           |
| **Image Size**      | Large (350MB+)                | Small (25-250MB)                |
| **Build Strategy**  | Single stage                  | Multi-stage                     |
| **Logging**         | Verbose (DEBUG)               | Concise (WARNING)               |
| **Security**        | Permissive                    | Strict                          |
| **Restart Policy**  | unless-stopped                | unless-stopped + replicas       |
| **Health Checks**   | Basic                         | Comprehensive                   |
| **Resource Limits** | None                          | Strict limits                   |
| **Where It Runs**   | Your laptop                   | AWS EC2                         |
| **How to Start**    | `docker-compose.dev.yml up`   | `docker-compose.prod.yml up -d` |
| **When to Rebuild** | Only when dependencies change | Every code change               |
| **Cost**            | $0 (local)                    | $50-500/month                   |

---

### Container Best Practices

#### **✅ DO**

- Use multi-stage Dockerfiles for production
- Mount source code in dev, bake into image in prod
- Use specific version tags in prod (`v1.0.0`, not `latest`)
- Enable health checks in production
- Use resource limits in production
- Test prod images locally before deploying
- Use `.dockerignore` to exclude unnecessary files
- Run containers as non-root in production (when possible)

#### **❌ DON'T**

- Use dev images in production
- Use `latest` tag in production
- Mount source code volumes in production
- Skip health checks in production
- Hardcode secrets in Dockerfiles
- Ignore image size optimization
- Commit `.env` files to git
- Run production without resource limits

#### **Testing Production Images Locally**

```bash
# Build production images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Run locally (simulate production)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:3000

# Check image sizes
docker images | grep ollama

# Check resource usage
docker stats

# Stop when done
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
```

This ensures your production images work correctly BEFORE deploying to AWS, preventing costly mistakes and downtime! 🚀

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

## Ollama Service Guide

### **Ollama Service**

🔍 Explaining curl http://localhost:11434/api/tags
This command queries the Ollama service (not your Flask backend or React frontend). Let me break down exactly what's happening:

📡 What This Command Does

```bash
curl http://localhost:11434/api/tags
```

Returns something like:

```json
{
  "models": [
    {
      "name": "llama2:latest",
      "model": "llama2:latest",
      "modified_at": "2025-11-22T10:00:00.123456789Z",
      "size": 3826793677,
      "digest": "sha256:abc123...",
      "details": {
        "parent_model": "",
        "format": "gguf",
        "family": "llama",
        "families": ["llama"],
        "parameter_size": "7B",
        "quantization_level": "Q4_0"
      }
    }
  ]
}
```

### 🎯 Where This Data Comes From

Not From Your Code!
This endpoint is NOT part of your ollama-chat-app codebase. The JSON response comes from:

```
┌─────────────────────────────────────────────────┐
│         Ollama Service (Port 11434)             │
│                                                 │
│  This is a SEPARATE service running on your     │
│  machine, independent of your Flask backend     │
│  and React frontend.                            │
│                                                 │
│  Started with: ollama serve                     │
│                                                 │
│  Provides REST API for:                         │
│  - /api/tags        (list models)              │
│  - /api/generate    (generate text)            │
│  - /api/chat        (chat completion)          │
│  - /api/pull        (download models)          │
│  - /api/push        (upload models)            │
└─────────────────────────────────────────────────┘
```

### 🏗️ Architecture Flow

```
Your Application:
┌─────────────────┐
│ React Frontend  │  (Port 3000)
│ localhost:3000  │
└────────┬────────┘
         │ HTTP requests to /api/*
         ↓
┌─────────────────┐
│ Flask Backend   │  (Port 8000)
│ localhost:8000  │
└────────┬────────┘
         │ Calls Ollama API
         ↓
┌─────────────────┐
│ Ollama Service  │  (Port 11434)  ← YOU ARE HERE
│ localhost:11434 │
└─────────────────┘
         │ Manages AI models
         ↓
┌─────────────────┐
│ Local Models    │
│ ~/.ollama/      │
│ - llama2        │
│ - mistral       │
│ - etc.          │
└─────────────────┘
```

When you run curl http://localhost:11434/api/tags, you're bypassing your entire application and talking directly to Ollama.

📂 Where Ollama Stores Model Data

The JSON response contains information from:

```bash
# Ollama stores models and metadata here:
~/.ollama/
├── models/
│   ├── manifests/
│   │   └── registry.ollama.ai/
│   │       └── library/
│   │           └── llama2/
│   │               └── latest              # Model metadata
│   └── blobs/
│       ├── sha256-abc123...               # Model weights (binary data)
│       ├── sha256-def456...               # Model config
│       └── sha256-ghi789...               # Tokenizer data
└── history/                                # Chat history (if enabled)

# Check your Ollama models directory:
ls -lh ~/.ollama/models/manifests/registry.ollama.ai/library/

# Check model blob sizes:
du -sh ~/.ollama/models/blobs/*
```

JSON Field Sources:

```json
{
  "models": [
    {
      "name": "Model manifest file name",
      "model": "llama2:latest",
      "modified_at": "File modification timestamp from filesystem",
      "size": "Sum of blob file sizes (model weights + config)",
      "digest": "SHA256 hash of manifest file",
      "details": {
        "parent_model": "",
        "format": "gguf",
        "family": "Parsed from model configuration (GGUF metadata)",
        "families": ["llama"],
        "parameter_size": "Model architecture info (e.g., '7B' = 7 billion parameters)",
        "quantization_level": "Compression level (Q4_0, Q5_0, etc.)"
      }
    }
  ]
}
```

🔗 How Your Code Interacts With This
Your Backend (backend/ollama_connector.py or backend/app.py)
Your Flask backend calls this Ollama API internally:

```python
# In your backend code (simplified example):
import requests

class OllamaConnector:
    def __init__(self, base_url="http://localhost:11434"):
        self.base_url = base_url

    def list_models(self):
        """List available models - calls /api/tags"""
        response = requests.get(f"{self.base_url}/api/tags")
        return response.json()  # Returns the same JSON you saw with curl

    def chat(self, message, model="llama2"):
        """Send chat message - calls /api/chat"""
        response = requests.post(
            f"{self.base_url}/api/chat",
            json={
                "model": model,
                "messages": [{"role": "user", "content": message}],
                "stream": False
            }
        )
        return response.json()
```

Testing the Connection in Your Code:

```python
# From your backend directory:
cd ~/codeplatoon/projects/ollama-chat-app/backend
source venv/bin/activate
python

# In Python shell:
>>> import requests
>>> response = requests.get("http://localhost:11434/api/tags")
>>> response.json()
# You'll see the same JSON as curl command

>>> # Or if you have ollama_connector.py:
>>> from ollama_connector import OllamaConnector
>>> connector = OllamaConnector()
>>> models = connector.list_models()
>>> print(models)
# Same JSON response
```

## Understanding the Request Flow

When You Use Curl Directly:

```
You (Terminal)
    │
    │ curl http://localhost:11434/api/tags
    ↓
Ollama Service (Port 11434)
    │
    │ Reads ~/.ollama/models/
    │ Builds JSON response
    ↓
Returns JSON to your terminal
```

When Your Application Uses It:

```
User (Browser)
    │
    │ Sends message "Hello"
    ↓
React Frontend (Port 3000)
    │
    │ POST /api/chat {"prompt": "Hello"}
    ↓
Flask Backend (Port 8000)
    │
    │ POST http://localhost:11434/api/chat
    │     {"model": "llama2", "messages": [...]}
    ↓
Ollama Service (Port 11434)
    │
    │ Loads model from ~/.ollama/models/
    │ Generates AI response
    ↓
Returns response to Flask
    ↓
Flask returns to React
    ↓
User sees AI response in chat
```

## 📋 Complete Ollama API Reference

The Ollama service provides these endpoints (all returning JSON):

```json
# List all models
curl http://localhost:11434/api/tags

# Get model info
curl http://localhost:11434/api/show -d '{"name": "llama2"}'

# Generate text (non-streaming)
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "prompt": "Why is the sky blue?",
    "stream": false
  }'

# Chat completion
curl -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": false
  }'

# Pull a model
curl -X POST http://localhost:11434/api/pull \
  -d '{"name": "mistral"}'

# Delete a model
curl -X DELETE http://localhost:11434/api/delete \
  -d '{"name": "llama2"}'
```

🔍 Verify Ollama Service

```bash
# Check if Ollama is running
ps aux | grep ollama

# Check what's listening on port 11434
sudo lsof -i :11434

# View Ollama logs (if running as service)
journalctl -u ollama -f

# Or if running in terminal, check the terminal output
```

## 🎯 Summary

To answer your question directly:

The JSON object values from curl http://localhost:11434/api/tags come from:

- Source: Ollama service binary (separate application)
- Port: 11434 (NOT your Flask backend on 8000)
- Data Location: ~/.ollama/models/ directory on your filesystem
- Not in your code: This is Ollama's built-in API, not your ollama-chat-app code

Your ollama-chat-app code:

- Doesn't generate this JSON
- Consumes this JSON (via ollama_connector.py)
- Acts as a client to the Ollama API
- Provides a user-friendly interface on top of Ollama

Think of it like this:

- Ollama = The database/engine
- Your Backend = The API layer
- Your Frontend = The user interface

The curl command is like querying a database directly, bypassing your application! 🚀

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
