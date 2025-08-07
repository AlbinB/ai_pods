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