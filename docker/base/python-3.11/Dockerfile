# ===========================================
# Base Python Image for AI-Pods
# Mode: Development (with production notes)
# Python: 3.11-slim
# Features: Jupyter, Debug support, GPU-ready
# ===========================================

FROM python:3.11-slim

# --- METADATA ---
LABEL maintainer="AI-Pods Team" \
      description="Base Python environment for AI experiments" \
      python.version="3.11" \
      mode="development"

# --- SYSTEM DEPENDENCIES ---
RUN apt-get update && apt-get install -y \
    # Essential tools
    curl \
    wget \
    git \
    build-essential \
    # Development conveniences (PROD: remove these)
    vim \
    nano \
    htop \
    net-tools \
    iputils-ping \
    # Jupyter system dependencies
    nodejs \
    npm \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# --- PYTHON PACKAGE MANAGEMENT ---
RUN pip install --no-cache-dir --upgrade \
    pip \
    setuptools \
    wheel

# --- JUPYTER CONFIGURATION ---
# Install Jupyter and extensions
RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab>=4.0.0 \
    notebook \
    ipywidgets \
    jupyterlab-git \
    jupyterlab-lsp \
    python-lsp-server[all]

# Configure Jupyter
RUN jupyter labextension disable "@jupyterlab/apputils-extension:announcements"

# Create Jupyter config with password
# Password 'dev' hashed using: python -c "from jupyter_server.auth import passwd; print(passwd('dev'))"
RUN mkdir -p /root/.jupyter && \
    echo "c.ServerApp.password = 'argon2:\$argon2id\$v=19\$m=10240,t=10,p=8\$VCzIVc3NawUjJmX0b0v0Zw\$O/tbxglbCvnJqJECI7emEjEiOkMNOPmPfNJ0KfOUZ0'" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.token = ''" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.allow_root = True" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.open_browser = False" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.root_dir = '/workspace'" >> /root/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.password_required = True" >> /root/.jupyter/jupyter_lab_config.py

# --- DEVELOPMENT TOOLS ---
# PROD: Remove this entire section for production
RUN pip install --no-cache-dir \
    # Debugging
    debugpy \
    ipdb \
    # Code quality
    black \
    isort \
    flake8 \
    mypy \
    pylint \
    # Testing
    pytest \
    pytest-cov \
    pytest-asyncio \
    # Utilities
    python-dotenv \
    rich \
    tqdm

# --- GPU SUPPORT PREPARATION ---
# Base detection script (actual GPU packages installed by services)
RUN echo '#!/bin/bash\n\
if command -v nvidia-smi &> /dev/null; then\n\
    echo "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader)"\n\
    export CUDA_AVAILABLE=1\n\
else\n\
    echo "No GPU detected, using CPU"\n\
    export CUDA_AVAILABLE=0\n\
fi' > /usr/local/bin/detect-gpu && \
    chmod +x /usr/local/bin/detect-gpu

# --- ENVIRONMENT CONFIGURATION ---
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace:/workspace/src:/workspace/shared:$PYTHONPATH \
    # Jupyter settings
    JUPYTER_ENABLE_LAB=yes \
    JUPYTER_PORT=8888 \
    JUPYTER_CONFIG_DIR=/root/.jupyter \
    # Development settings (PROD: remove these)
    PYTHONDEVMODE=1 \
    # Workspace
    WORKSPACE_ROOT=/workspace \
    SHARED_DIR=/workspace/shared \
    SRC_DIR=/workspace/src

# --- WORKSPACE SETUP ---
WORKDIR /workspace

# Create standard directories
RUN mkdir -p \
    /workspace/src \
    /workspace/shared/data \
    /workspace/shared/models \
    /workspace/shared/notebooks \
    /workspace/shared/outputs \
    /workspace/shared/configs

# --- ENTRYPOINT SCRIPT ---
# Universal entrypoint that handles multiple modes
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Detect GPU on startup\n\
source /usr/local/bin/detect-gpu\n\
\n\
# Service identification\n\
echo "========================================"\n\
echo "Starting ${SERVICE_NAME:-ai-pods} service"\n\
echo "Mode: ${MODE:-jupyter}"\n\
echo "Platform: ${PLATFORM:-unknown}"\n\
echo "GPU Available: ${CUDA_AVAILABLE}"\n\
echo "========================================"\n\
\n\
# Handle different modes\n\
MODE=${MODE:-jupyter}\n\
\n\
case $MODE in\n\
    jupyter)\n\
        echo "Starting Jupyter Lab on port ${JUPYTER_PORT:-8888}"\n\
        echo "Password: dev (override with JUPYTER_PASSWORD env var)"\n\
        echo "URL: http://localhost:${JUPYTER_PORT:-8888}"\n\
        \n\
        # Set notebook directory based on service\n\
        if [ -n "$SERVICE_NAME" ] && [ -d "/workspace/shared/notebooks/$SERVICE_NAME" ]; then\n\
            NOTEBOOK_DIR="/workspace/shared/notebooks/$SERVICE_NAME"\n\
        else\n\
            NOTEBOOK_DIR="/workspace"\n\
        fi\n\
        \n\
        # Override password if environment variable is set\n\
        if [ -n "$JUPYTER_PASSWORD" ] && [ "$JUPYTER_PASSWORD" != "dev" ]; then\n\
            echo "Setting custom Jupyter password..."\n\
            python -c "from jupyter_server.auth import passwd; import json; print(json.dumps(passwd('\''$JUPYTER_PASSWORD'\'')))" > /tmp/passwd.txt\n\
            HASHED_PASSWORD=$(cat /tmp/passwd.txt | tr -d '\"')\n\
            echo "c.ServerApp.password = '\''$HASHED_PASSWORD'\''" >> /root/.jupyter/jupyter_lab_config.py\n\
            rm /tmp/passwd.txt\n\
        fi\n\
        \n\
        exec jupyter lab \\\n\
            --ip=0.0.0.0 \\\n\
            --port=${JUPYTER_PORT:-8888} \\\n\
            --no-browser \\\n\
            --allow-root \\\n\
            --NotebookApp.notebook_dir="${NOTEBOOK_DIR}" \\\n\
            --NotebookApp.allow_origin="*" \\\n\
            --NotebookApp.disable_check_xsrf=True\n\
        ;;\n\
    \n\
    api)\n\
        echo "Starting API server on port ${SERVICE_PORT:-8000}"\n\
        if [ -f "/workspace/src/main.py" ]; then\n\
            cd /workspace/src\n\
            # Check for FastAPI/Uvicorn\n\
            if python -c "import uvicorn" 2>/dev/null; then\n\
                exec uvicorn main:app --host 0.0.0.0 --port ${SERVICE_PORT:-8000} --reload\n\
            else\n\
                exec python main.py\n\
            fi\n\
        else\n\
            echo "No main.py found, starting interactive shell"\n\
            exec /bin/bash\n\
        fi\n\
        ;;\n\
    \n\
    debug)\n\
        echo "Starting debug server on port ${DEBUG_PORT:-5678}"\n\
        echo "Waiting for debugger to attach..."\n\
        cd /workspace/src\n\
        exec python -m debugpy \\\n\
            --listen 0.0.0.0:${DEBUG_PORT:-5678} \\\n\
            --wait-for-client \\\n\
            ${DEBUG_SCRIPT:-main.py}\n\
        ;;\n\
    \n\
    shell)\n\
        echo "Starting interactive shell"\n\
        echo "Python: $(python --version)"\n\
        echo "Pip packages: $(pip list | wc -l) packages installed"\n\
        exec /bin/bash\n\
        ;;\n\
    \n\
    test)\n\
        echo "Running tests..."\n\
        cd /workspace/src\n\
        exec pytest ${PYTEST_ARGS:--v}\n\
        ;;\n\
    \n\
    custom)\n\
        echo "Executing custom command: ${CUSTOM_CMD}"\n\
        exec ${CUSTOM_CMD}\n\
        ;;\n\
    \n\
    *)\n\
        echo "Unknown mode: $MODE"\n\
        echo "Available modes: jupyter, api, debug, shell, test, custom"\n\
        exit 1\n\
        ;;\n\
esac' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# --- HEALTH CHECK ---
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${JUPYTER_PORT:-8888}/api || exit 1

# --- PORTS ---
# Default ports (can be overridden by services)
EXPOSE 8888 8000 5678

# --- VOLUME MOUNT POINTS ---
# These will be mounted from host
VOLUME ["/workspace/src", "/workspace/shared"]

# --- DEFAULT COMMAND ---
ENTRYPOINT ["/entrypoint.sh"]
CMD ["jupyter"]

# ===========================================
# PRODUCTION NOTES:
# 1. Remove development tools section
# 2. Remove PYTHONDEVMODE environment variable
# 3. Set PYTHONOPTIMIZE=2
# 4. Use specific CMD instead of entrypoint
# 5. Remove vim, nano, htop, net-tools
# 6. Consider multi-stage build to reduce size
# 7. Add non-root user for security
# 8. Pin all package versions
# ==========================================