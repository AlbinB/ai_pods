# ===========================================
# AI-Pods Cross-Platform Makefile
# Supports: Windows (WSL), macOS, Linux
# ===========================================

# Shell configuration
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:

# ===========================================
# Platform Detection
# ===========================================

# Detect operating system
UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
UNAME_M := $(shell uname -m 2>/dev/null || echo unknown)

# Platform-specific settings
ifeq ($(UNAME_S),Darwin)
    # macOS
    PLATFORM := macos
    PLATFORM_ARCH := $(UNAME_M)
    PYTHON_CMD := python3
    PIP_CMD := pip3
    VENV_BIN := bin
    VENV_ACTIVATE := source venvs/$${SERVICE}/bin/activate
    PATH_PREFIX := $(shell pwd)
    OPEN_CMD := open
    SED_INPLACE := sed -i ''
    DOCKER_DESKTOP := true
else ifeq ($(UNAME_S),Linux)
    # Check if running in WSL
    IS_WSL := $(shell grep -qi microsoft /proc/version 2>/dev/null && echo true || echo false)
    ifeq ($(IS_WSL),true)
        # Windows Subsystem for Linux
        PLATFORM := wsl
        PLATFORM_ARCH := $(UNAME_M)
        PYTHON_CMD := python3
        PIP_CMD := pip3
        VENV_BIN := bin
        VENV_ACTIVATE := source venvs/$${SERVICE}/bin/activate
        PATH_PREFIX := $(shell pwd)
        OPEN_CMD := explorer.exe
        SED_INPLACE := sed -i
        DOCKER_DESKTOP := true
    else
        # Native Linux
        PLATFORM := linux
        PLATFORM_ARCH := $(UNAME_M)
        PYTHON_CMD := python3
        PIP_CMD := pip3
        VENV_BIN := bin
        VENV_ACTIVATE := source venvs/$${SERVICE}/bin/activate
        PATH_PREFIX := $(shell pwd)
        OPEN_CMD := xdg-open
        SED_INPLACE := sed -i
        DOCKER_DESKTOP := false
    endif
else
    # Windows (Git Bash, MSYS2, etc.)
    PLATFORM := windows
    PLATFORM_ARCH := amd64
    PYTHON_CMD := python
    PIP_CMD := pip
    VENV_BIN := Scripts
    VENV_ACTIVATE := source venvs/$${SERVICE}/Scripts/activate
    PATH_PREFIX := $(shell pwd)
    OPEN_CMD := start
    SED_INPLACE := sed -i
    DOCKER_DESKTOP := true
endif

# ===========================================
# Project Configuration
# ===========================================

PROJECT_NAME := ai-pods
COMPOSE_PROJECT_NAME := $(PROJECT_NAME)
COMPOSE_FILE := docker-compose.yml
DOCKER_REGISTRY := local

# Export for docker-compose
export COMPOSE_PROJECT_NAME
export DOCKER_BUILDKIT := 1
export PLATFORM
export PATH_PREFIX

# ===========================================
# Colors for Terminal Output
# ===========================================

ifneq ($(TERM),)
    RED := \033[0;31m
    GREEN := \033[0;32m
    YELLOW := \033[1;33m
    BLUE := \033[0;34m
    MAGENTA := \033[0;35m
    CYAN := \033[0;36m
    WHITE := \033[1;37m
    NC := \033[0m # No Color
else
    RED :=
    GREEN :=
    YELLOW :=
    BLUE :=
    MAGENTA :=
    CYAN :=
    WHITE :=
    NC :=
endif

# ===========================================
# Help and Info Commands
# ===========================================

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)=============================================$(NC)"
	@echo "$(CYAN)       AI-Pods Docker Management$(NC)"
	@echo "$(CYAN)=============================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Platform:$(NC) $(GREEN)$(PLATFORM) ($(PLATFORM_ARCH))$(NC)"
	@echo "$(YELLOW)Directory:$(NC) $(GREEN)$(PATH_PREFIX)$(NC)"
	@echo "$(YELLOW)Python:$(NC) $(GREEN)$(PYTHON_CMD)$(NC)"
	@echo ""
	@echo "$(CYAN)Available Commands:$(NC)"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Quick Start:$(NC)"
	@echo "  1. $(WHITE)make init$(NC)           - Initialize project structure"
	@echo "  2. $(WHITE)make build-base$(NC)     - Build base Docker image"
	@echo "  3. $(WHITE)make new-service NAME=my-service$(NC) - Create a service"
	@echo "  4. $(WHITE)make work-on SERVICE=my-service$(NC) - Start developing"

.PHONY: info
info: ## Show system information
	@echo "$(CYAN)System Information:$(NC)"
	@echo "  Platform:        $(GREEN)$(PLATFORM)$(NC)"
	@echo "  Architecture:    $(GREEN)$(PLATFORM_ARCH)$(NC)"
	@echo "  Working Dir:     $(GREEN)$(PATH_PREFIX)$(NC)"
	@echo "  Python Command:  $(GREEN)$(PYTHON_CMD)$(NC)"
	@echo "  Pip Command:     $(GREEN)$(PIP_CMD)$(NC)"
	@echo "  Docker Desktop:  $(GREEN)$(DOCKER_DESKTOP)$(NC)"
	@echo ""
	@echo "$(CYAN)Docker Status:$(NC)"
	@docker version --format '  Client: {{.Client.Version}}\n  Server: {{.Server.Version}}' 2>/dev/null || echo "  $(RED)Docker not running$(NC)"
	@echo ""
	@echo "$(CYAN)Python Status:$(NC)"
	@$(PYTHON_CMD) --version 2>/dev/null | sed 's/^/  /' || echo "  $(RED)Python not found$(NC)"

# ===========================================
# Project Initialization
# ===========================================

.PHONY: init
init: ## Initialize project structure
	@echo "$(CYAN)Initializing AI-Pods project...$(NC)"
	@echo "  Platform: $(GREEN)$(PLATFORM)$(NC)"
	
	@# Create directory structure
	@echo "$(YELLOW)Creating directories...$(NC)"
	@mkdir -p src
	@mkdir -p shared/{data,models,notebooks,outputs,configs}
	@mkdir -p docker/{base,services,compose}
	@mkdir -p scripts
	@mkdir -p venvs
	@mkdir -p docs/{conventions,services}
	@mkdir -p .vscode
	
	@# Create .gitkeep files
	@touch src/.gitkeep
	@touch docker/services/.gitkeep
	@touch shared/{data,models,notebooks,outputs,configs}/.gitkeep
	@touch venvs/.gitkeep
	@touch docs/services/.gitkeep
	
	@# Create .env if doesn't exist
	@if [ ! -f .env ]; then \
		if [ -f .env.example ]; then \
			cp .env.example .env; \
			echo "$(GREEN)✓ Created .env from template$(NC)"; \
		else \
			echo "# AI-Pods Environment" > .env; \
			echo "PROJECT_NAME=ai-pods" >> .env; \
			echo "COMPOSE_PROJECT_NAME=ai-pods" >> .env; \
			echo "DOCKER_BUILDKIT=1" >> .env; \
			echo "$(GREEN)✓ Created basic .env file$(NC)"; \
		fi \
	fi
	
	@# Make scripts executable
	@chmod +x scripts/*.sh 2>/dev/null || true
	
	@echo "$(GREEN)✓ Project structure initialized!$(NC)"
	@echo ""
	@echo "$(CYAN)Next steps:$(NC)"
	@echo "  1. Run: $(WHITE)make build-base$(NC)"
	@echo "  2. Create a service: $(WHITE)make new-service NAME=<n>$(NC)"

# ===========================================
# Docker Commands
# ===========================================

.PHONY: build-base
build-base: ## Build base Python image
	@echo "$(CYAN)Building base Python image...$(NC)"
	@if [ ! -f docker-compose.yml ]; then \
		echo "$(RED)Error: docker-compose.yml not found$(NC)"; \
		exit 1; \
	fi
	@docker-compose build python-base
	@echo "$(GREEN)✓ Base image built successfully!$(NC)"

.PHONY: build
build: ## Build all services
	@echo "$(CYAN)Building all services...$(NC)"
	@docker-compose build
	@echo "$(GREEN)✓ All services built!$(NC)"

.PHONY: up
up: ## Start all services
	@echo "$(CYAN)Starting services...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)✓ Services started!$(NC)"
	@make ps

.PHONY: down
down: ## Stop and remove all containers
	@echo "$(YELLOW)Stopping services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✓ Services stopped!$(NC)"

.PHONY: stop
stop: ## Stop all services (keep containers)
	@docker-compose stop
	@echo "$(GREEN)✓ Services stopped (containers preserved)$(NC)"

.PHONY: start
start: ## Start stopped services
	@docker-compose start
	@echo "$(GREEN)✓ Services started$(NC)"

.PHONY: restart
restart: ## Restart all services
	@echo "$(YELLOW)Restarting services...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

.PHONY: ps
ps: ## Show running containers
	@docker-compose ps

.PHONY: logs
logs: ## View logs (SERVICE=name for specific service)
	@if [ -z "$(SERVICE)" ]; then \
		docker-compose logs -f --tail=100; \
	else \
		docker-compose logs -f --tail=100 $(SERVICE); \
	fi

# ===========================================
# Service Management
# ===========================================

.PHONY: new-service
new-service: ## Create a new service (NAME=service-name)
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Error: Please specify NAME=<service-name>$(NC)"; \
		echo "Example: make new-service NAME=rag-test"; \
		exit 1; \
	fi
	@echo "$(CYAN)Creating new service: $(NAME)$(NC)"
	
	@# Calculate port allocation
	@EXISTING=$$(ls -d src/*/ 2>/dev/null | wc -l | tr -d ' '); \
	PORT_BASE=$$((8000 + EXISTING * 10)); \
	echo "  Port allocation: $$PORT_BASE-$$((PORT_BASE + 9))"; \
	\
	# Create directories \
	mkdir -p src/$(NAME); \
	mkdir -p docker/services/$(NAME); \
	mkdir -p shared/notebooks/$(NAME); \
	mkdir -p shared/outputs/$(NAME); \
	\
	# Create requirements.txt \
	echo "# $(NAME) dependencies" > src/$(NAME)/requirements.txt; \
	echo "# Add your service-specific packages here" >> src/$(NAME)/requirements.txt; \
	\
	# Create README \
	echo "# $(NAME)" > src/$(NAME)/README.md; \
	echo "" >> src/$(NAME)/README.md; \
	echo "## Ports" >> src/$(NAME)/README.md; \
	echo "- API: $$PORT_BASE" >> src/$(NAME)/README.md; \
	echo "- Jupyter: $$((PORT_BASE + 1))" >> src/$(NAME)/README.md; \
	echo "- Debug: $$((PORT_BASE + 2))" >> src/$(NAME)/README.md; \
	\
	echo "$(GREEN)✓ Service $(NAME) created!$(NC)"; \
	echo ""; \
	echo "$(CYAN)Next steps:$(NC)"; \
	echo "  1. Add dependencies to src/$(NAME)/requirements.txt"; \
	echo "  2. Create docker/services/$(NAME)/Dockerfile"; \
	echo "  3. Add service to docker-compose.yml"; \
	echo "  4. Run: make work-on SERVICE=$(NAME)"

.PHONY: list-services
list-services: ## List available services
	@echo "$(CYAN)Available services:$(NC)"
	@if [ -d src ] && [ "$$(ls -A src 2>/dev/null)" ]; then \
		for service in src/*/; do \
			basename $$service | sed 's/^/  • /'; \
		done \
	else \
		echo "  $(YELLOW)No services created yet$(NC)"; \
		echo "  Create one with: $(WHITE)make new-service NAME=<n>$(NC)"; \
	fi

.PHONY: work-on
work-on: ## Start working on a service (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		make list-services; \
		exit 1; \
	fi
	@if [ ! -d "src/$(SERVICE)" ]; then \
		echo "$(RED)Error: Service $(SERVICE) not found$(NC)"; \
		make list-services; \
		exit 1; \
	fi
	@echo "$(CYAN)Activating $(SERVICE) environment...$(NC)"
	@bash -c "source scripts/activate-service.sh $(SERVICE)"

.PHONY: shell
shell: ## Enter service container (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Entering $(SERVICE) container...$(NC)"
	@docker exec -it ai-pods-$(SERVICE) /bin/bash

.PHONY: exec
exec: ## Execute command in service (SERVICE=name CMD=command)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify CMD=<command>$(NC)"; \
		exit 1; \
	fi
	@docker exec ai-pods-$(SERVICE) $(CMD)

# ===========================================
# Jupyter Commands
# ===========================================

.PHONY: jupyter
jupyter: ## Start Jupyter for a service (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Starting Jupyter for $(SERVICE)...$(NC)"
	@docker-compose up -d $(SERVICE)
	@sleep 3
	@echo "$(GREEN)✓ Jupyter Lab is running!$(NC)"
	@echo ""
	@echo "  URL: $(CYAN)http://localhost:8888$(NC)"
	@echo "  Password: $(YELLOW)dev$(NC)"
	@echo ""
	@echo "  $(YELLOW)Note: You can change the password by setting JUPYTER_PASSWORD env variable$(NC)"

.PHONY: notebook
notebook: jupyter ## Alias for jupyter command

# ===========================================
# Python Environment Management
# ===========================================

.PHONY: venv
venv: ## Create virtual environment for service (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Creating virtual environment for $(SERVICE)...$(NC)"
	@$(PYTHON_CMD) -m venv venvs/$(SERVICE)
	@echo "$(GREEN)✓ Virtual environment created$(NC)"

.PHONY: sync-env
sync-env: ## Sync packages from container to host venv (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Syncing packages for $(SERVICE)...$(NC)"
	@docker exec ai-pods-$(SERVICE) pip freeze > /tmp/reqs-$(SERVICE).txt
	@docker cp ai-pods-$(SERVICE):/tmp/reqs-$(SERVICE).txt venvs/$(SERVICE)/requirements.txt
	@venvs/$(SERVICE)/$(VENV_BIN)/pip install -r venvs/$(SERVICE)/requirements.txt
	@echo "$(GREEN)✓ Packages synced!$(NC)"

.PHONY: pip-install
pip-install: ## Install package in container (SERVICE=name PKG=package)
	@if [ -z "$(SERVICE)" ] || [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n> PKG=<package>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Installing $(PKG) in $(SERVICE)...$(NC)"
	@docker exec ai-pods-$(SERVICE) pip install $(PKG)
	@docker exec ai-pods-$(SERVICE) pip freeze > src/$(SERVICE)/requirements.txt
	@echo "$(GREEN)✓ Package installed!$(NC)"

# ===========================================
# Testing and Validation
# ===========================================

.PHONY: test
test: ## Run tests for service (SERVICE=name)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)Error: Please specify SERVICE=<n>$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Running tests for $(SERVICE)...$(NC)"
	@docker-compose run --rm -e MODE=test $(SERVICE)

.PHONY: validate
validate: ## Validate project setup
	@echo "$(CYAN)Validating AI-Pods setup...$(NC)"
	@echo ""
	
	@# Check Docker
	@if command -v docker &> /dev/null; then \
		echo "$(GREEN)✓ Docker:$(NC) $$(docker --version)"; \
	else \
		echo "$(RED)✗ Docker not found$(NC)"; \
	fi
	
	@# Check Docker Compose
	@if command -v docker-compose &> /dev/null; then \
		echo "$(GREEN)✓ Docker Compose:$(NC) $$(docker-compose --version)"; \
	else \
		echo "$(RED)✗ Docker Compose not found$(NC)"; \
	fi
	
	@# Check Python
	@if command -v $(PYTHON_CMD) &> /dev/null; then \
		echo "$(GREEN)✓ Python:$(NC) $$($(PYTHON_CMD) --version)"; \
	else \
		echo "$(RED)✗ Python not found$(NC)"; \
	fi
	
	@# Check directories
	@echo ""
	@echo "$(CYAN)Directory Structure:$(NC)"
	@for dir in src shared docker scripts venvs; do \
		if [ -d "$$dir" ]; then \
			echo "$(GREEN)✓ $$dir/$(NC)"; \
		else \
			echo "$(RED)✗ $$dir/ (missing)$(NC)"; \
		fi \
	done
	
	@# Check files
	@echo ""
	@echo "$(CYAN)Configuration Files:$(NC)"
	@for file in Makefile docker-compose.yml .env; do \
		if [ -f "$$file" ]; then \
			echo "$(GREEN)✓ $$file$(NC)"; \
		else \
			echo "$(YELLOW)⚠ $$file (missing)$(NC)"; \
		fi \
	done
	
	@# Check base image
	@echo ""
	@if docker images | grep -q "ai-pods/python-base"; then \
		echo "$(GREEN)✓ Base image built$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Base image not built (run: make build-base)$(NC)"; \
	fi
	
	@echo ""
	@echo "$(GREEN)Validation complete!$(NC)"

# ===========================================
# Cleanup Commands
# ===========================================

.PHONY: clean
clean: ## Remove stopped containers and dangling images
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker-compose rm -f
	@docker image prune -f
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

.PHONY: clean-all
clean-all: ## Remove all containers, images, and volumes (WARNING: destructive)
	@echo "$(RED)⚠️  WARNING: This will remove ALL Docker resources for this project!$(NC)"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v --rmi all; \
		echo "$(GREEN)✓ All resources removed$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

.PHONY: prune
prune: ## Deep clean entire Docker system (WARNING: affects all projects)
	@echo "$(RED)⚠️  WARNING: This will remove ALL unused Docker resources system-wide!$(NC)"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -af --volumes; \
		echo "$(GREEN)✓ Docker system cleaned$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled$(NC)"; \
	fi

# ===========================================
# Utility Commands
# ===========================================

.PHONY: stats
stats: ## Show resource usage for running containers
	@docker stats --no-stream $$(docker-compose ps -q 2>/dev/null) 2>/dev/null || echo "$(YELLOW)No containers running$(NC)"

.PHONY: ports
ports: ## Show port mappings for all services
	@echo "$(CYAN)Port Mappings:$(NC)"
	@docker-compose ps --format "table {{.Name}}\t{{.Ports}}" 2>/dev/null || echo "$(YELLOW)No services running$(NC)"

.PHONY: images
images: ## List project Docker images
	@echo "$(CYAN)AI-Pods Docker Images:$(NC)"
	@docker images --filter "reference=ai-pods/*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

# ===========================================
# Platform-Specific Commands
# ===========================================

ifeq ($(PLATFORM),wsl)
.PHONY: wsl-fix
wsl-fix: ## Fix common WSL issues
	@echo "$(CYAN)Fixing WSL permissions and line endings...$(NC)"
	@find scripts -type f -name "*.sh" -exec chmod +x {} \;
	@find scripts -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true
	@chmod -R 755 venvs/ 2>/dev/null || true
	@echo "$(GREEN)✓ WSL fixes applied$(NC)"
endif

ifeq ($(PLATFORM),macos)
.PHONY: mac-resources
mac-resources: ## Open Docker Desktop resource settings (macOS)
	@echo "$(CYAN)Opening Docker Desktop settings...$(NC)"
	@open -a Docker
	@echo "Navigate to: Preferences > Resources"
endif

# ===========================================
# Documentation Commands
# ===========================================

.PHONY: conventions
conventions: ## Show project conventions
	@echo "$(CYAN)=============================================$(NC)"
	@echo "$(CYAN)         AI-Pods Conventions$(NC)"
	@echo "$(CYAN)=============================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Port Allocation:$(NC)"
	@echo "  • Each service gets 10 ports (8000, 8010, 8020...)"
	@echo "  • +0: API/Main service"
	@echo "  • +1: Jupyter Lab"
	@echo "  • +2: Debug port"
	@echo ""
	@echo "$(YELLOW)Directory Structure:$(NC)"
	@echo "  • src/<service>/        Service code"
	@echo "  • shared/               Shared resources"
	@echo "  • docker/services/      Dockerfiles"
	@echo "  • venvs/<service>/      Python environments"
	@echo ""
	@echo "$(YELLOW)Naming Conventions:$(NC)"
	@echo "  • Services:     lowercase-with-hyphens"
	@echo "  • Containers:   ai-pods-<service>"
	@echo "  • Images:       ai-pods/<service>:latest"
	@echo ""
	@echo "$(YELLOW)Workflow:$(NC)"
	@echo "  1. make new-service NAME=<n>"
	@echo "  2. Edit src/<n>/requirements.txt"
	@echo "  3. make work-on SERVICE=<n>"
	@echo "  4. Develop with live reload"

# ===========================================
# Debug Commands (hidden from help)
# ===========================================

.PHONY: debug-vars
debug-vars: ## Show Makefile variables (hidden)
	@echo "PLATFORM: $(PLATFORM)"
	@echo "PLATFORM_ARCH: $(PLATFORM_ARCH)"
	@echo "PATH_PREFIX: $(PATH_PREFIX)"
	@echo "PYTHON_CMD: $(PYTHON_CMD)"
	@echo "PIP_CMD: $(PIP_CMD)"
	@echo "VENV_BIN: $(VENV_BIN)"
	@echo "DOCKER_DESKTOP: $(DOCKER_DESKTOP)"

# End of Makefile