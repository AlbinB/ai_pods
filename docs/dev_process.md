# AI-Pods Project: Architecture Decisions & Development Process

## Executive Summary
AI-Pods is a Docker-based test bench for experimenting with AI models and architectures. The project prioritizes developer experience, cross-platform compatibility, and service isolation while maintaining flexibility for both local and future cloud deployment.

## Core Architecture Decisions

### 1. Service Isolation Pattern
**Decision**: Each service (rag-test, multi-agent, model-server) operates in complete isolation with its own code directory and container.

**Reasoning**:
- Prevents dependency conflicts between different AI frameworks
- Allows testing incompatible package versions simultaneously
- Simplifies debugging by reducing variable scope
- Enables independent scaling and deployment

**Implications**:
- Each service has its own `src/[service-name]/` directory
- Services cannot directly access each other's code
- Shared resources must go through the `/shared/` directory
- Development focuses on one service at a time

### 2. Volume Mapping Strategy
**Decision**: Service-specific bind mounts with shared resource access
```yaml
volumes:
  - ./src/[service]:/workspace/src:rw      # Service code only
  - ./shared:/workspace/shared:rw          # Shared resources
  - ./.env:/workspace/.env:ro              # Read-only config
```

**Reasoning**:
- Previous project had inconsistent root folder mapping issues
- Bind mounts provide instant file synchronization for development
- Service isolation prevents accidental cross-contamination
- Shared folder enables data/model sharing between services

**Implications**:
- Edit in Windows/Cursor → Instant reflection in container
- Each container only sees its own code + shared resources
- No need to rebuild images for code changes
- Performance overhead on Windows (acceptable for dev environment)

### 3. Development Environment (WSL + Docker Desktop)
**Decision**: WSL as primary terminal, Docker Desktop with WSL2 backend, project on Windows filesystem

**Reasoning**:
- WSL provides Linux tooling on Windows (make, bash, etc.)
- Docker Desktop's WSL2 backend offers near-native Linux performance
- Windows filesystem location enables Windows GUI tools (Cursor)
- Best of both worlds: Linux CLI + Windows GUI

**Implications**:
- All terminal commands run in WSL Ubuntu-22.04
- Paths translate: `F:\projects\ai_pods` ↔ `/mnt/f/projects/ai_pods`
- Docker commands work seamlessly from WSL
- Some file permission quirks possible

### 4. Python Version Strategy
**Decision**: Python 3.11 in containers (runtime), Python 3.12 in WSL (development tools)

**Reasoning**:
- Containers use 3.11-slim for smaller images and stability
- WSL has 3.12 pre-installed, avoiding complex pyenv setup
- Minor version difference acceptable for development
- Container is source of truth for runtime behavior

**Implications**:
- Rare edge cases where IntelliSense might not catch 3.11-specific issues
- Must test in containers for production validation
- Development venvs use 3.12, runtime uses 3.11

### 5. Service-Specific Virtual Environments
**Decision**: Separate venv for each service in `venvs/[service-name]/`

**Reasoning**:
- Services often have conflicting dependencies
- IntelliSense needs correct packages for accurate suggestions
- Claude Code needs appropriate context for each service
- Prevents "works on my machine" issues

**Implications**:
- Must activate correct venv when switching services
- Disk space for multiple Python environments
- Need to sync packages from container to venv periodically
- Clean context switching between services

### 6. Port Allocation Convention
**Decision**: Each service gets a block of 10 ports (8000-8009, 8010-8019, etc.)

**Reasoning**:
- Predictable port assignment prevents conflicts
- Easy to remember which service uses which ports
- Room for growth (multiple ports per service)
- Standard offsets: +0 (API), +1 (Jupyter), +2 (Debug)

**Implications**:
- RAG-test: 8000 (API), 8001 (Jupyter), 8002 (Debug)
- Multi-agent: 8010 (API), 8011 (Jupyter), 8012 (Debug)
- Can run all services simultaneously without conflicts

### 7. Development-First, Production-Aware
**Decision**: Optimize for development experience with production notes in comments

**Reasoning**:
- This is a test bench, not production infrastructure
- Developer velocity more important than production optimization
- Keep production path clear for future migration
- Document what would change for production

**Implications**:
- Containers include debugging tools (debugpy, jupyter)
- Dockerfiles have "PROD:" comments for production changes
- No complex orchestration (just docker-compose)
- Security/optimization deferred to production phase

### 8. IDE and Debugging Strategy
**Decision**: Cursor/VS Code on host, remote debugging via debugpy, IntelliSense via venvs

**Reasoning**:
- Full IDE features on native OS (better performance)
- Remote debugging provides container context
- Local venvs enable IntelliSense without container overhead
- Git operations simpler on host

**Implications**:
- Must configure remote debugging per service
- Path mappings needed for breakpoints
- Two-step setup: container + local venv
- Some tools run on host, others in container

## Development Process

### Initial Setup (One-time)
1. **Clone and Initialize**
   ```bash
   # In WSL terminal
   cd /mnt/f/projects
   git clone [repo] ai_pods
   cd ai_pods
   make init
   ```

2. **Configure Environment**
   - Copy `.env.example` to `.env`
   - Adjust service-specific settings
   - Set Jupyter tokens, ports if needed

3. **Build Base Images**
   ```bash
   make build-base
   ```

### Daily Development Workflow

1. **Start Working on a Service**
   ```bash
   # In WSL terminal (Cursor's integrated terminal)
   cd /mnt/f/projects/ai_pods
   make work-on SERVICE=rag-test
   ```
   This single command:
   - Starts the Docker container
   - Creates/activates Python venv
   - Syncs packages if needed
   - Opens Cursor in service directory

2. **Active Development**
   - Edit code in Cursor (Windows GUI)
   - Changes instantly reflect in container
   - Run code via:
     ```bash
     # Execute in container
     docker exec -it ai-pods-rag-test python main.py
     
     # Or use Jupyter
     make jupyter SERVICE=rag-test
     ```

3. **Debugging Session**
   ```bash
   # Start container in debug mode
   make debug SERVICE=rag-test
   
   # In Cursor: F5 to attach debugger
   # Set breakpoints, debug as normal
   ```

4. **Package Management**
   ```bash
   # Install new package in container
   docker exec -it ai-pods-rag-test pip install langchain-experimental
   
   # Update requirements
   docker exec -it ai-pods-rag-test pip freeze > /workspace/src/requirements.txt
   
   # Sync to local venv for IntelliSense
   make sync-env SERVICE=rag-test
   ```

5. **Testing Changes**
   ```bash
   # Unit tests in container
   docker exec -it ai-pods-rag-test pytest
   
   # Integration tests
   make test-integration SERVICE=rag-test
   
   # Check logs
   make logs SERVICE=rag-test
   ```

6. **Switching Services**
   ```bash
   # Clean switch to different service
   make work-on SERVICE=multi-agent
   # Previous service keeps running if needed
   ```

### Collaboration Workflow

1. **Sharing Work**
   - Code: Commit to git (host machine)
   - Data/Models: Place in `shared/` directory
   - Notebooks: Save in `shared/notebooks/[service]/`
   - Results: Output to `shared/outputs/[service]/`

2. **Reproducibility**
   - Dockerfile defines exact environment
   - requirements.txt pins all versions
   - .env.example documents configuration
   - README per service explains usage

### Troubleshooting Workflow

1. **Container Issues**
   ```bash
   make logs SERVICE=rag-test
   make shell SERVICE=rag-test  # Debug inside
   make restart SERVICE=rag-test
   ```

2. **Path/Permission Issues**
   ```bash
   # Fix script permissions
   chmod +x scripts/*.sh
   
   # Check path translations
   pwd  # Should show /mnt/f/projects/ai_pods
   ```

3. **Package Conflicts**
   ```bash
   # Rebuild venv from scratch
   rm -rf venvs/rag-test
   make sync-env SERVICE=rag-test
   ```

## Future Migration Path

### Phase 1: Current (Local Development)
- Docker Compose orchestration
- Local file system volumes
- Manual scaling
- WSL + Docker Desktop

### Phase 2: Hybrid (Local + Cloud)
- Push images to registry (GCP Artifact Registry)
- Cloud Storage for shared data
- Mix of local and cloud services
- Begin CI/CD pipeline

### Phase 3: Cloud Native
- Kubernetes (GKE) for orchestration
- Persistent volumes in cloud
- Auto-scaling based on load
- Full GitOps deployment

## Key Success Factors

1. **Consistency**: Same structure for all services
2. **Isolation**: Services can't interfere with each other
3. **Flexibility**: Easy to add new services
4. **Simplicity**: One command to start working
5. **Clarity**: Clear conventions and documentation

## Common Pitfalls Avoided

1. **Root folder mapping inconsistency**: Solved via explicit service mapping
2. **Package conflicts**: Solved via service-specific venvs
3. **Port conflicts**: Solved via port block convention
4. **Path confusion**: Solved via WSL standardization
5. **Debug difficulty**: Solved via remote debugging setup
6. **Environment drift**: Solved via container as truth source

## Maintenance Guidelines

1. **Adding New Services**
   - Follow existing service structure
   - Assign next port block (8030+)
   - Create Dockerfile with dev/prod notes
   - Add to docker-compose.yml
   - Document in README

2. **Updating Dependencies**
   - Update in container first
   - Test thoroughly
   - Sync to local venv
   - Commit requirements.txt

3. **Performance Optimization**
   - Monitor with `docker stats`
   - Adjust memory limits as needed
   - Use `.dockerignore` aggressively
   - Consider multi-stage builds

## Decision Log

| Decision | Date | Rationale | Revisit When |
|----------|------|-----------|--------------|
| Use `src/` not `app/` | Today | Clearer purpose, common convention | - |
| WSL as primary terminal | Today | Better Docker integration on Windows | If moving to Mac/Linux |
| Python 3.11 in containers | Today | Stability, smaller images | When 3.12+ features needed |
| Service-specific venvs | Today | Dependency isolation | If single service becomes primary |
| Shared notebooks folder | Today | Easy comparison between experiments | If notebooks get too large |
| Docker Desktop vs Docker in WSL | Today | Easier setup, better GUI | If performance issues arise |