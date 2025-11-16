# Git Guide - Ollama Chat App

A comprehensive guide for Git version control tailored specifically for the Ollama Chat App project.

## Table of Contents

- [Initial Repository Setup](#initial-repository-setup)
- [Daily Git Workflow](#daily-git-workflow)
- [Branch Management Strategy](#branch-management-strategy)
- [Commit Best Practices](#commit-best-practices)
- [Collaboration Workflow](#collaboration-workflow)
- [Common Git Scenarios](#common-git-scenarios)
- [Project-Specific Guidelines](#project-specific-guidelines)
- [Troubleshooting](#troubleshooting)

---

## Initial Repository Setup

### First Time Setup - New Repository

If you're starting fresh or cloning for the first time:

#### 1. Clone Existing Repository

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/ollama-chat-app.git
cd ollama-chat-app

# Verify remote is set
git remote -v
# Should show:
# origin  https://github.com/YOUR_USERNAME/ollama-chat-app.git (fetch)
# origin  https://github.com/YOUR_USERNAME/ollama-chat-app.git (push)
```

#### 2. Initialize New Repository (If Starting from Scratch)

```bash
# Navigate to project directory
cd ~/codeplatoon/projects/ollama-chat-app

# Initialize git repository
git init

# Check status
git status
```

#### 3. Create .gitignore

Before your first commit, ensure you have a proper `.gitignore`:

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
pnpm-debug.log*

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
```

#### 4. Configure Git (If First Time)

```bash
# Set your identity
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

#### 5. Make Your First Commit

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
- Add comprehensive documentation
- Add infrastructure setup files"

# Verify commit
git log --oneline -1
```

#### 6. Connect to GitHub Remote

```bash
# Add GitHub remote (HTTPS)
git remote add origin https://github.com/YOUR_USERNAME/ollama-chat-app.git

# OR add GitHub remote (SSH - recommended)
git remote add origin git@github.com:YOUR_USERNAME/ollama-chat-app.git

# Verify remote was added
git remote -v

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

### SSH Key Setup (Recommended)

Setting up SSH keys eliminates password prompts:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Start ssh-agent
eval "$(ssh-agent -s)"

# Add SSH key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
cat ~/.ssh/id_ed25519.pub
# Copy the output

# Add to GitHub:
# 1. Go to GitHub.com → Settings → SSH and GPG keys
# 2. Click "New SSH key"
# 3. Paste your public key
# 4. Click "Add SSH key"

# Test SSH connection
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

### Personal Access Token (For HTTPS)

If using HTTPS instead of SSH:

```bash
# Generate Personal Access Token:
# 1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
# 2. Click "Generate new token (classic)"
# 3. Select scopes: repo (full control)
# 4. Generate and copy token

# Use token as password when pushing
git push -u origin main
# Username: your-username
# Password: [paste your token]

# Cache credentials to avoid repeated entry
git config --global credential.helper cache

# Or cache for specific duration (1 hour = 3600 seconds)
git config --global credential.helper 'cache --timeout=3600'
```

---

## Daily Git Workflow

### Starting Your Development Session

```bash
# 1. Check current status
git status
git branch

# 2. Update local repository from remote
git fetch origin

# 3. Switch to main branch
git checkout main

# 4. Pull latest changes
git pull origin main

# 5. View recent commits to see what's new
git log --oneline -10

# 6. Check for any local changes that weren't committed
git status
```

### Creating a Feature Branch

```bash
# Create and switch to new feature branch
git checkout -b feature/your-feature-name

# Branch naming conventions for this project:
# - feature/feature-name      (new features)
# - bugfix/bug-description    (bug fixes)
# - hotfix/urgent-fix         (urgent production fixes)
# - refactor/refactor-name    (code refactoring)
# - docs/documentation-topic  (documentation updates)
# - test/test-description     (adding tests)
# - chore/maintenance-task    (maintenance tasks)

# Examples:
git checkout -b feature/chat-history-persistence
git checkout -b bugfix/cors-header-issue
git checkout -b docs/api-documentation
```

### Working on Your Changes

```bash
# Check what you're working on
git branch
git status

# Make your changes...
# Edit files in VS Code or your editor

# View changes as you work
git status                    # See which files changed
git diff                      # See unstaged changes
git diff <filename>           # See changes in specific file

# Stage specific files (RECOMMENDED)
git add backend/app.py
git add frontend/src/components/ChatInterface.jsx
git add docs/api-documentation.md

# OR stage all changes (use with caution)
git add .

# Review staged changes
git status
git diff --staged
```

### Committing Your Changes

```bash
# Commit with descriptive message
git commit -m "feat: add message persistence to chat interface

- Implement localStorage integration for chat history
- Add conversation save/load functionality in ChatInterface
- Update App component to manage conversation state
- Add error handling for storage quota exceeded
- Add tests for localStorage integration

Closes #42"

# Verify commit was created
git log --oneline -1
git show HEAD
```

### Pushing to Remote

```bash
# First time pushing a new branch
git push -u origin feature/your-feature-name

# Subsequent pushes on same branch
git push

# Verify push succeeded
git status
# Should say: "Your branch is up to date with 'origin/feature/your-feature-name'"
```

---

## Branch Management Strategy

### Branch Types

#### Main Branches

- **`main`**: Production-ready code, always stable
- **`develop`**: Integration branch for features (optional)
- **`staging`**: Pre-production testing (optional)

#### Supporting Branches

- **`feature/*`**: New features or enhancements
- **`bugfix/*`**: Bug fixes for development
- **`hotfix/*`**: Urgent fixes for production
- **`release/*`**: Release preparation
- **`docs/*`**: Documentation updates
- **`test/*`**: Test additions
- **`refactor/*`**: Code refactoring

### Branch Workflow

#### Creating Feature Branches

```bash
# Always branch from main (or develop)
git checkout main
git pull origin main
git checkout -b feature/new-feature

# Work on your feature
# Make commits
# Push to remote
git push -u origin feature/new-feature
```

#### Keeping Branch Up to Date

```bash
# Update your feature branch with latest main
git checkout main
git pull origin main
git checkout feature/your-feature
git rebase main

# If conflicts occur, resolve them:
# 1. Fix conflicts in files
# 2. Stage resolved files: git add <filename>
# 3. Continue rebase: git rebase --continue

# Force push after rebase (careful!)
git push --force-with-lease origin feature/your-feature
```

#### Merging via Pull Request

```bash
# Push your feature branch
git push origin feature/your-feature

# Create Pull Request on GitHub:
# 1. Go to repository on GitHub
# 2. Click "Compare & pull request"
# 3. Fill in PR template:
#    - Title: Clear, descriptive
#    - Description: What changed and why
#    - Testing: How you tested
#    - Screenshots: For UI changes
# 4. Link issues: "Closes #123"
# 5. Request reviewers
# 6. Add labels

# After PR is approved and merged:
git checkout main
git pull origin main
git branch -d feature/your-feature  # Delete local branch
```

### Cleaning Up Branches

```bash
# List all branches
git branch -a

# Delete local branch (merged)
git branch -d branch-name

# Force delete local branch (unmerged)
git branch -D branch-name

# Delete remote branch
git push origin --delete branch-name

# Clean up stale remote tracking branches
git fetch --prune
git remote prune origin
```

---

## Commit Best Practices

### Commit Message Format

Use the **Conventional Commits** format:

```
<type>: <subject>

<body>

<footer>
```

#### Types:

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code formatting (no functional changes)
- **refactor**: Code restructuring (no functional changes)
- **test**: Adding or updating tests
- **chore**: Maintenance tasks
- **perf**: Performance improvements
- **ci**: CI/CD changes

#### Examples:

```bash
# Simple commit
git commit -m "feat: add user authentication system"

# Detailed commit
git commit -m "fix: resolve CORS issue in production deployment

- Update Flask-CORS configuration to allow production domain
- Add proper headers for preflight requests
- Update nginx configuration to pass CORS headers
- Test with production API endpoint

Fixes #45"

# Breaking change
git commit -m "feat!: restructure API endpoints

BREAKING CHANGE: API endpoints have been restructured.
Old endpoint /api/chat is now /api/v1/conversations/chat

Migration guide:
- Update all API calls to use /api/v1/ prefix
- Update frontend axios configuration
- Update API documentation

Closes #67"

# Multiple changes
git commit -m "chore: update dependencies and improve error handling

- Bump Flask to 3.0.1 for security fixes
- Update React to 18.2.0
- Add better error messages in API responses
- Improve logging in backend

Related to #89"
```

### Atomic Commits

Make commits small and focused:

```bash
# BAD: Too many unrelated changes
git add .
git commit -m "fix: various fixes and improvements"

# GOOD: Separate commits for different changes
git add backend/app.py backend/ollama_connector.py
git commit -m "fix: improve error handling in Ollama API calls"

git add frontend/src/components/ChatInterface.jsx
git commit -m "feat: add loading indicator for chat messages"

git add docs/api-documentation.md
git commit -m "docs: update API documentation with new endpoints"
```

### When to Commit

Commit when you:

- Complete a logical unit of work
- Fix a bug
- Add a feature (even if small)
- Make working code (tests pass)
- Before switching branches
- At end of day (if work is stable)

Don't commit:

- Broken code
- Code with syntax errors
- Unrelated changes together
- Temporary/debug code
- Sensitive information (passwords, keys)

---

## Collaboration Workflow

### Working with Others

#### Fetching Latest Changes

```bash
# Fetch changes without merging
git fetch origin

# See what's new
git log origin/main..HEAD     # Your commits not on remote
git log HEAD..origin/main     # Remote commits you don't have

# Update your main branch
git checkout main
git pull origin main
```

#### Resolving Conflicts

```bash
# When pulling/rebasing causes conflicts
git pull origin main
# Or
git rebase main

# Git will show conflicted files
git status

# Open conflicted files and look for:
<<<<<<< HEAD
Your changes
=======
Their changes
>>>>>>> branch-name

# Resolve conflicts by:
# 1. Editing files to keep correct code
# 2. Remove conflict markers
# 3. Stage resolved files
git add <resolved-file>

# Continue the merge/rebase
git rebase --continue
# Or if merging:
git commit

# Abort if needed
git rebase --abort
git merge --abort
```

#### Code Review Process

##### Submitting Code for Review

```bash
# Ensure your branch is up to date
git checkout feature/your-feature
git fetch origin
git rebase origin/main

# Push your branch
git push origin feature/your-feature

# Create Pull Request on GitHub with:
# - Clear title
# - Detailed description
# - Testing steps
# - Screenshots (if UI)
# - Link to issue
```

##### Addressing Review Comments

```bash
# Make requested changes
# Edit files...

# Commit changes
git add <changed-files>
git commit -m "fix: address PR review comments

- Refactor error handling as suggested
- Add input validation
- Update tests"

# Push updates
git push origin feature/your-feature

# PR automatically updates
```

### Syncing Forks (If Contributing to Original Repo)

```bash
# Add upstream remote (one time)
git remote add upstream https://github.com/CodePlatoon/ollama-chat-app.git

# Verify remotes
git remote -v
# origin: your fork
# upstream: original repo

# Fetch upstream changes
git fetch upstream

# Update your main branch
git checkout main
git merge upstream/main

# Push to your fork
git push origin main
```

---

## Common Git Scenarios

### Scenario 1: Accidentally Committed to Main

```bash
# If you haven't pushed yet:
git checkout main
git reset --soft HEAD~1  # Undo commit, keep changes
git stash               # Save changes
git checkout -b feature/correct-branch
git stash pop          # Restore changes
git add .
git commit -m "feat: proper commit on feature branch"
```

### Scenario 2: Need to Undo Last Commit

```bash
# Undo commit but keep changes (staged)
git reset --soft HEAD~1

# Undo commit and keep changes (unstaged)
git reset HEAD~1

# Undo commit and discard changes (DANGEROUS!)
git reset --hard HEAD~1

# Undo multiple commits
git reset --soft HEAD~3  # Undo last 3 commits
```

### Scenario 3: Committed Sensitive Information

```bash
# Remove file from last commit
git rm --cached .env
git commit --amend -m "fix: remove sensitive file"

# If already pushed (DANGEROUS - rewrites history)
git push --force-with-lease origin branch-name

# Better solution: Use git-filter-repo or BFG Repo Cleaner
# See: https://github.com/newren/git-filter-repo
```

### Scenario 4: Need to Change Last Commit Message

```bash
# Amend last commit message
git commit --amend -m "fix: correct commit message"

# If already pushed
git push --force-with-lease origin branch-name
```

### Scenario 5: Want to Save Work but Not Commit

```bash
# Stash changes
git stash save "work in progress on chat feature"

# List stashes
git stash list

# Apply most recent stash
git stash pop

# Apply specific stash
git stash apply stash@{1}

# Delete stash
git stash drop stash@{0}

# Clear all stashes
git stash clear
```

### Scenario 6: Made Changes on Wrong Branch

```bash
# Save changes
git stash

# Switch to correct branch
git checkout correct-branch

# Apply changes
git stash pop

# Stage and commit
git add .
git commit -m "feat: changes on correct branch"
```

### Scenario 7: Need to Cherry-Pick Specific Commit

```bash
# Get commit hash from source branch
git log feature/source-branch --oneline

# Switch to target branch
git checkout feature/target-branch

# Cherry-pick specific commit
git cherry-pick abc1234

# If conflicts, resolve and continue
git cherry-pick --continue
```

### Scenario 8: Recover Deleted Branch

```bash
# Find commit hash of deleted branch
git reflog

# Recreate branch at that commit
git checkout -b recovered-branch abc1234
```

---

## Project-Specific Guidelines

### Frontend Changes (React/Vite)

```bash
# When working on frontend:
cd frontend

# Create feature branch
git checkout -b feature/ui-enhancement

# Make changes to components
# Stage frontend files
git add src/components/ChatInterface.jsx
git add src/components/ChatInterface.css

# Commit with frontend context
git commit -m "feat(frontend): enhance chat interface with typing indicator

- Add animated typing dots when waiting for response
- Update ChatInterface component with loading state
- Add CSS animations for smooth transitions
- Update App component to manage loading state

Closes #34"

# Test before pushing
npm run lint
npm run build
```

### Backend Changes (Flask/Python)

```bash
# When working on backend:
cd backend

# Create feature branch
git checkout -b feature/api-endpoint

# Activate venv
source venv/bin/activate

# Make changes
# Stage backend files
git add app.py
git add ollama_connector.py

# Commit with backend context
git commit -m "feat(backend): add conversation history endpoint

- Create new /api/conversations endpoint
- Add conversation retrieval logic
- Implement pagination for conversation list
- Add error handling and validation
- Update API documentation

Closes #56"

# Test before pushing
python -m pytest tests/
```

### Docker/Infrastructure Changes

```bash
# When modifying Docker or deployment:
git checkout -b chore/docker-optimization

# Stage infrastructure files
git add frontend/Dockerfile
git add backend/Dockerfile
git add docker-compose.yml

git commit -m "chore: optimize Docker builds for faster deployment

- Use multi-stage builds to reduce image size
- Add build caching for npm dependencies
- Update base images to alpine for smaller footprint
- Add docker-compose for local development
- Update deployment documentation

Related to #78"
```

### Documentation Updates

```bash
# Documentation changes
git checkout -b docs/api-documentation

git add docs/api-documentation.md
git add README.md

git commit -m "docs: update API documentation with authentication flow

- Add authentication endpoints documentation
- Include request/response examples
- Add error code reference
- Update README with API usage guide

Closes #91"
```

### Working on Multiple Areas

```bash
# If changes span frontend and backend:
git checkout -b feature/end-to-end-feature

# Make changes in both areas
# Commit together if tightly coupled
git add frontend/src/App.jsx
git add backend/app.py

git commit -m "feat: implement real-time message updates

- Add WebSocket support in backend
- Update frontend to handle WebSocket connections
- Implement message broadcasting
- Add reconnection logic
- Update both frontend and backend tests

Closes #103"
```

---

## Troubleshooting

### Common Git Problems

#### Problem: Permission Denied (SSH)

```bash
# Test SSH connection
ssh -T git@github.com

# If fails, check SSH key
ls -la ~/.ssh/id_*.pub

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Ensure key is added to GitHub
cat ~/.ssh/id_ed25519.pub
```

#### Problem: Authentication Failed (HTTPS)

```bash
# Generate Personal Access Token on GitHub
# Settings → Developer settings → Personal access tokens

# Update remote URL if needed
git remote set-url origin https://github.com/USERNAME/ollama-chat-app.git

# Cache credentials
git config --global credential.helper cache
```

#### Problem: Merge Conflicts

```bash
# Identify conflicted files
git status

# Open files and resolve conflicts
# Look for conflict markers:
# <<<<<<< HEAD
# =======
# >>>>>>>

# After resolving:
git add <resolved-files>
git commit  # Or git rebase --continue
```

#### Problem: Detached HEAD State

```bash
# Check current state
git status

# Create branch from detached HEAD
git checkout -b recovery-branch

# Or return to main
git checkout main
```

#### Problem: Large File Committed

```bash
# Remove from last commit
git rm --cached large-file.zip
git commit --amend -m "fix: remove large file"

# Add to .gitignore
echo "large-file.zip" >> .gitignore
git add .gitignore
git commit -m "chore: update .gitignore"
```

#### Problem: Pushed Wrong Changes

```bash
# If no one pulled yet, force push (CAREFUL!)
git reset --hard HEAD~1
git push --force-with-lease origin branch-name

# If others pulled, revert instead
git revert HEAD
git push origin branch-name
```

### Git Commands Quick Reference

```bash
# Status & Info
git status                      # Working directory status
git log --oneline -10          # Recent commits
git log --graph --all          # Visual commit history
git diff                       # Unstaged changes
git diff --staged              # Staged changes
git show HEAD                  # Last commit details

# Branching
git branch                     # List local branches
git branch -a                  # List all branches
git branch -d branch-name      # Delete branch
git checkout -b new-branch     # Create and switch
git merge branch-name          # Merge branch

# Remote Operations
git remote -v                  # List remotes
git fetch origin              # Fetch changes
git pull origin main          # Pull and merge
git push origin branch        # Push branch
git push -u origin branch     # Push and set upstream

# Undoing Changes
git reset HEAD file           # Unstage file
git checkout -- file          # Discard changes
git revert HEAD               # Revert last commit
git reset --soft HEAD~1       # Undo commit, keep changes

# Stashing
git stash                     # Stash changes
git stash list                # List stashes
git stash pop                 # Apply and remove stash
git stash apply               # Apply stash, keep it

# Advanced
git rebase main               # Rebase on main
git cherry-pick abc123        # Cherry-pick commit
git reflog                    # Reference log
git clean -fd                 # Remove untracked files
```

---

## Best Practices Summary

### Do's ✅

- **Commit frequently** with logical units of work
- **Write clear commit messages** using conventional format
- **Create feature branches** for all changes
- **Pull before you push** to avoid conflicts
- **Review changes** before committing (git diff)
- **Test your code** before committing
- **Use .gitignore** to exclude unnecessary files
- **Keep commits atomic** - one logical change per commit
- **Rebase feature branches** to keep history clean
- **Delete merged branches** to keep repository tidy

### Don'ts ❌

- **Don't commit** to main directly
- **Don't commit** sensitive information (passwords, keys)
- **Don't commit** large binary files
- **Don't force push** to main or shared branches
- **Don't commit** broken code
- **Don't use generic messages** like "fix stuff"
- **Don't mix** unrelated changes in one commit
- **Don't forget** to pull before starting work
- **Don't rewrite history** on public branches
- **Don't commit** node_modules or venv directories

---

## Additional Resources

### Learn More

- **Pro Git Book**: https://git-scm.com/book/en/v2
- **Conventional Commits**: https://www.conventionalcommits.org/
- **GitHub Flow**: https://guides.github.com/introduction/flow/
- **Git Cheat Sheet**: https://education.github.com/git-cheat-sheet-education.pdf
- **Oh Shit, Git!**: https://ohshitgit.com/ (fixing mistakes)

### GitHub-Specific

- **Pull Request Best Practices**: https://github.com/blog/1943-how-to-write-the-perfect-pull-request
- **GitHub CLI**: https://cli.github.com/
- **SSH Key Setup**: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

This guide is tailored specifically for the Ollama Chat App project. Keep it updated as your team's workflow evolves!
