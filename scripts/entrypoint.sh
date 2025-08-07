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