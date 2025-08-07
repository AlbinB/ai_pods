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

# Create virtual environment if it doesn't exist
if [ ! -d "venvs/$SERVICE" ]; then
    echo "📦 Creating virtual environment for $SERVICE..."
    $PYTHON_CMD -m venv venvs/$SERVICE
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venvs/$SERVICE/bin/activate

# Install dependencies if requirements.txt exists
if [ -f "src/$SERVICE/requirements.txt" ]; then
    echo "📥 Installing dependencies..."
    pip install -r src/$SERVICE/requirements.txt
fi

# Set environment variables
export SERVICE_NAME=$SERVICE
export PYTHONPATH="$(pwd)/src:$(pwd)/shared:$PYTHONPATH"

echo "✅ Environment ready for $SERVICE development!"

# Open Cursor/VS Code if requested
if [ "$OPEN_CURSOR" = "true" ]; then
    echo "🚀 Opening development environment..."
    if command -v cursor &> /dev/null; then
        cursor src/$SERVICE/
    elif command -v code &> /dev/null; then
        code src/$SERVICE/
    else
        echo "⚠️  Cursor/VS Code not found. Open manually: src/$SERVICE/"
    fi
fi

echo ""
echo "🎯 Ready to work on $SERVICE!"
echo "   - Source code: src/$SERVICE/"
echo "   - Notebooks: shared/notebooks/$SERVICE/"
echo "   - Outputs: shared/outputs/$SERVICE/"
echo "   - Virtual env: venvs/$SERVICE/"
echo ""
echo "Commands:"
echo "  make work-on SERVICE=$SERVICE    # Start development container"
echo "  make shell SERVICE=$SERVICE      # Open shell in container"
echo "  make jupyter SERVICE=$SERVICE    # Start Jupyter in container" 