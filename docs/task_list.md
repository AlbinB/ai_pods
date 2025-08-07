# AI-Pods Environment Setup Task List

## Platform Detection
Before starting, determine your platform and follow the appropriate path:
- **Windows**: Use WSL2 terminal for all commands
- **macOS**: Use Terminal.app, iTerm2, or VS Code integrated terminal

## Prerequisites Checklist

### Windows Prerequisites:
- [ ] Windows 10/11 with WSL2 installed (Ubuntu-22.04)
- [ ] Docker Desktop installed with WSL2 backend enabled
- [ ] Cursor (or VS Code) installed
- [ ] Git configured in WSL
- [ ] Project directory exists at `F:\projects\ai_pods`

### macOS Prerequisites:
- [ ] macOS 11+ (Big Sur or later)
- [ ] Docker Desktop for Mac installed
- [ ] Cursor (or VS Code) installed
- [ ] Git installed (via Xcode tools or Homebrew)
- [ ] Project directory exists at `~/projects/ai_pods`

## Phase 1: Project Structure Creation

### Task 1.1: Create Core Directory Structure
```bash
# Windows (in WSL terminal):
cd /mnt/f/projects/ai_pods

# macOS (in Terminal):
cd ~/projects/ai_pods

# Both platforms - create CORE directories only:
mkdir -p src                    # Will hold future services
mkdir -p shared/{data,models,notebooks,outputs,configs}
mkdir -p docker/{base,compose}   # Base infrastructure only
mkdir -p docker/services         # Will hold future service definitions
mkdir -p scripts
mkdir -p venvs
mkdir -p .vscode
mkdir -p docs/{conventions,services}

# Create .gitkeep files for empty directories
touch src/.gitkeep
touch docker/services/.gitkeep
touch shared/data/.gitkeep
touch shared/models/.gitkeep
touch shared/notebooks/.gitkeep
touch shared/outputs/.gitkeep
touch shared/configs/.gitkeep
touch venvs/.gitkeep
touch docs/services/.gitkeep
```

### Task 1.2: Create .gitignore
Create `.gitignore` file:
```gitignore
# Environment
.env
*.env.local
!.env.example

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venvs/
*.egg-info/
.pytest_cache/
.coverage
htmlcov/

# Jupyter
.ipynb_checkpoints/
*.ipynb_checkpoints

# IDE
.vscode/*
!.vscode/settings.json
!.vscode/launch.json
.idea/
*.swp
*.swo

# Docker
*.log
docker/compose/override.yml

# Data (but keep structure)
shared/data/*
!shared/data/.gitkeep
shared/models/*
!shared/models/.gitkeep
shared/outputs/*/*
!shared/outputs/*/.gitkeep

# OS
.DS_Store
Thumbs.db
desktop.ini
```

## Phase 2: Docker Base Configuration

### Task 2.1: Create Base Dockerfile with GPU Support
Create `docker/base/python-3.11/Dockerfile`:
```dockerfile
# ===========================================
# Base Python Image for AI-Pods
# Mode: Development (with prod notes)
# Python: 3.11-slim
# GPU: Auto-detect with CPU fallback
# ===========================================

FROM python:3.11-slim

# --- SYSTEM DEPENDENCIES ---
RUN apt-get update && apt-get install -y \
    curl \
    vim \
    nano \
    htop \
    git \
    build-essential \
    # PROD: Comment out above tools except build-essential
    && rm -rf /var/lib/apt/lists/*

# --- GPU SUPPORT PREPARATION ---
# Note: Full GPU setup will be added when first GPU-enabled service is created
# This base image remains CPU-only but GPU-ready

# --- PYTHON BASE PACKAGES ---
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# --- DEVELOPMENT TOOLS ---
# PROD: Remove this entire section
RUN pip install --no-cache-dir \
    debugpy \
    ipython \
    jupyter \
    jupyterlab \
    notebook \
    black \
    flake8 \
    pytest \
    pytest-cov

# --- ENVIRONMENT CONFIGURATION ---
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    JUPYTER_ENABLE_LAB=yes \
    # PROD: Add PYTHONOPTIMIZE=2
    WORKSPACE_ROOT=/workspace

# --- WORKING DIRECTORY ---
WORKDIR /workspace

# --- DEFAULT COMMAND ---
# Development: Interactive shell
CMD ["/bin/bash"]
# PROD: Replace with specific service command
```

### Task 2.2: Create Minimal Docker Compose (No Services Yet)
Create `docker-compose.yml`:
```yaml
version: '3.8'

# Base configuration to be extended by services
x-base-service: &base-service
  build:
    context: .
    dockerfile: docker/base/python-3.11/Dockerfile
  image: ai-pods/python-base:latest
  env_file:
    - .env
  environment:
    - WORKSPACE_ROOT=/workspace
    - SHARED_DIR=/workspace/shared
    - PROJECT_NAME=${PROJECT_NAME:-ai-pods}
    - PYTHONPATH=/workspace/src:/workspace/shared:$PYTHONPATH
  networks:
    - ai-pods-network
  restart: unless-stopped
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"

services:
  # Base image builder only - no services yet
  python-base:
    <<: *base-service
    command: echo "Base image built successfully"
    profiles: ["build"]

  # Services will be added here as they are created
  # Each service will follow the established conventions

networks:
  ai-pods-network:
    driver: bridge
    name: ai-pods-network

volumes:
  pip-cache:
    name: ai-pods-pip-cache
```

## Phase 3: Script Creation

### Task 3.1: Create Entrypoint Script
Create `scripts/entrypoint.sh`:
```bash
#!/bin/bash
# Universal entrypoint for all services

set -e

# Service identification
echo "Starting ${SERVICE_NAME:-unknown} service..."
echo "Mode: ${MODE:-jupyter}"
echo "Workspace: ${WORKSPACE_ROOT:-/workspace}"

# Handle different modes
MODE=${MODE:-jupyter}

case $MODE in
    jupyter)
        echo "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}"
        exec jupyter lab \
            --ip=0.0.0.0 \
            --port=${JUPYTER_PORT:-8888} \
            --no-browser \
            --allow-root \
            --NotebookApp.token=${JUPYTER_TOKEN:-ai-pods} \
            --NotebookApp.notebook_dir=/workspace
        ;;
    
    api)
        echo "Starting API server on port ${SERVICE_PORT:-8000}"
        if [ -f "/workspace/src/main.py" ]; then
            cd /workspace/src
            exec python main.py
        else
            echo "No main.py found, starting interactive shell"
            exec /bin/bash
        fi
        ;;
    
    debug)
        echo "Starting debug server on port ${DEBUG_PORT:-5678}"
        cd /workspace/src
        exec python -m debugpy --listen 0.0.0.0:${DEBUG_PORT:-5678} --wait-for-client main.py
        ;;
    
    shell)
        echo "Starting interactive shell"
        exec /bin/bash
        ;;
    
    *)
        echo "Executing custom command: $@"
        exec "$@"
        ;;
esac
```

### Task 3.2: Create Service Management Script (Template)
Create `scripts/activate-service.sh`:
```bash
#!/bin/bash
# Service activation script - works with future services

SERVICE=$1
OPEN_CURSOR=${2:-true}

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    PYTHON_CMD="python3"
    VENV_ACTIVATE="venvs/$SERVICE/bin/activate"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="wsl"
    PYTHON_CMD="python3"
    VENV_ACTIVATE="venvs/$SERVICE/bin/activate"
else
    PLATFORM="linux"
    PYTHON_CMD="python3"
    VENV_ACTIVATE="venvs/$SERVICE/bin/activate"
fi

echo "Platform detected: $PLATFORM"

# Validation
if [ -z "$SERVICE" ]; then
    echo "Usage: source scripts/activate-service.sh <service-name> [open-cursor]"
    echo "Available services:"
    ls -d src/*/ 2>/dev/null | xargs -n 1 basename 2>/dev/null || echo "  No services created yet"
    return 1 2>/dev/null || exit 1
fi

if [ ! -d "src/$SERVICE" ]; then
    echo "Error: Service $SERVICE not found in src/"
    echo "Create it first with: make new-service NAME=$SERVICE"
    return 1 2>/dev/null || exit 1
fi

echo "🔄 Switching to $SERVICE development environment..."

# Rest of script remains the same...
```

### Task 3.3: Create Service Template Generator
Create `scripts/new-service.sh`:
```bash
#!/bin/bash
# Generate a new service with proper conventions

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: ./scripts/new-service.sh <service-name>"
    echo "Example: ./scripts/new-service.sh rag-test"
    exit 1
fi

echo "📦 Creating new service: $SERVICE_NAME"

# Determine port block (count existing services * 10 + 8000)
EXISTING_SERVICES=$(ls -d src/*/ 2>/dev/null | wc -l)
PORT_BASE=$((8000 + EXISTING_SERVICES * 10))

echo "  Port allocation: $PORT_BASE-$((PORT_BASE + 9))"
echo "    API: $PORT_BASE"
echo "    Jupyter: $((PORT_BASE + 1))"
echo "    Debug: $((PORT_BASE + 2))"

# Create directory structure
mkdir -p src/$SERVICE_NAME
mkdir -p docker/services/$SERVICE_NAME
mkdir -p shared/notebooks/$SERVICE_NAME
mkdir -p shared/outputs/$SERVICE_NAME

# Create initial requirements.txt
cat > src/$SERVICE_NAME/requirements.txt << EOF
# $SERVICE_NAME dependencies
# Add your service-specific packages here
EOF

# Create README for service
cat > src/$SERVICE_NAME/README.md << EOF
# $SERVICE_NAME

## Purpose
[Describe what this service is testing/implementing]

## Setup
\`\`\`bash
make work-on SERVICE=$SERVICE_NAME
\`\`\`

## Ports
- API: $PORT_BASE
- Jupyter: $((PORT_BASE + 1))
- Debug: $((PORT_BASE + 2))

## Dependencies
See requirements.txt

## Usage
[Add usage instructions here]
EOF

# Create Dockerfile
cat > docker/services/$SERVICE_NAME/Dockerfile << EOF
# ===========================================
# Service: $SERVICE_NAME
# Purpose: [Add description]
# Base: ai-pods/python-base:latest
# Port Range: $PORT_BASE-$((PORT_BASE + 9))
# ===========================================

ARG BASE_IMAGE=ai-pods/python-base:latest
FROM \${BASE_IMAGE}

# --- SERVICE INFORMATION ---
LABEL service="$SERVICE_NAME" \\
      description="$SERVICE_NAME service" \\
      port.api="$PORT_BASE" \\
      port.jupyter="$((PORT_BASE + 1))" \\
      port.debug="$((PORT_BASE + 2))"

# --- SERVICE DEPENDENCIES ---
COPY src/$SERVICE_NAME/requirements.txt /tmp/requirements.txt
RUN if [ -f /tmp/requirements.txt ] && [ -s /tmp/requirements.txt ]; then \\
        pip install --no-cache-dir -r /tmp/requirements.txt; \\
    fi

# --- SERVICE CONFIGURATION ---
ENV SERVICE_NAME=$SERVICE_NAME \\
    SERVICE_PORT=$PORT_BASE \\
    JUPYTER_PORT=8888 \\
    DEBUG_PORT=5678

# --- PORTS ---
EXPOSE \${SERVICE_PORT} \${JUPYTER_PORT} \${DEBUG_PORT}

# --- ENTRYPOINT ---
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["jupyter"]
EOF

echo "✅ Service $SERVICE_NAME created!"
echo ""
echo "Next steps:"
echo "1. Add service to docker-compose.yml"
echo "2. Add dependencies to src/$SERVICE_NAME/requirements.txt"
echo "3. Run: make work-on SERVICE=$SERVICE_NAME"
```