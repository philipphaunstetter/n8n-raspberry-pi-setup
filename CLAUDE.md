# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n deployment automation project for Raspberry Pi and Linux systems. It provides a comprehensive, modular setup script that allows users to deploy n8n (workflow automation) with optional services like Traefik (SSL/reverse proxy), Qdrant (vector database), PostgreSQL, Nginx, and Portainer (monitoring).

## Key Commands

### Main Setup
- `./setup.sh` - Run the interactive setup with infrastructure requirements guide
- `./setup.sh --debug` - Generate configuration files without starting services (for testing)
- `./setup.sh --help` - Show help and usage information
- `chmod +x setup.sh` - Make setup script executable (first-time setup)

### Docker Operations
- `docker compose up -d` - Start all configured services
- `docker compose down` - Stop all services
- `docker compose logs` - View logs for all services
- `docker compose logs -f [service-name]` - Follow logs for specific service
- `docker compose ps` - Show running containers status

### Configuration Management
- Generated files: `.env` (environment variables), `docker-compose.yml` (service definitions)
- Template files: `templates/` directory contains modular YAML configurations
- SSL certificates: `letsencrypt/acme.json` (auto-generated, 600 permissions required)

## Architecture Overview

### Core Components

**setup.sh** - The main orchestration script with several key sections:
1. **Dependency Management** (lines 57-382): OS detection, package installation, Docker setup
2. **Infrastructure Requirements** (lines 384-520): Pre-setup checklist and domain/SSL guidance  
3. **Service Selection** (lines 573-764): Interactive menu for choosing which services to deploy
4. **Service Configuration** (lines 769-1104): Individual configuration functions for each service
5. **File Generation** (lines 1106-1496): Creates .env and docker-compose.yml from templates

**Modular Template System**:
- `templates/base.yml` - Core n8n service configuration
- `templates/traefik.yml` - Reverse proxy with SSL certificate management
- `templates/postgres.yml` - PostgreSQL database for n8n persistence
- `templates/qdrant.yml` - Vector database for AI/ML workflows
- `templates/nginx.yml` - Web server for static files
- `templates/monitoring.yml` - Portainer container management UI

### Service Architecture

**Service Dependencies**: The script automatically resolves dependencies (e.g., PostgreSQL requires Traefik for admin access).

**Configuration Flow**:
1. User selects services via interactive menu or presets
2. Each selected service runs its configuration function
3. Environment variables are collected in SERVICE_CONFIG associative array
4. Templates are merged and service-specific modifications applied
5. Final .env and docker-compose.yml files generated

**Access Patterns**:
- With Traefik: Subdomain-based access (https://service.domain.com)
- Without Traefik: Port-based access (http://localhost:port)

### Key Functions

- `configure_[service]()` functions (lines 770-1003): Service-specific configuration
- `generate_env_file()` (lines 1107-1193): Creates environment file
- `merge_yaml_files()` (lines 1196-1221): Combines template YAML files
- `apply_service_configurations()` (lines 1224-1326): Post-processes Docker Compose file

## Development Guidelines

### Making Changes to Services
1. Service templates are in `templates/` directory - modify these rather than the legacy `docker-compose.template.yml`
2. Test changes with `./setup.sh --debug` before deploying
3. Service configuration functions follow the pattern `configure_[service_name]()`
4. New services need entries in `AVAILABLE_SERVICES` array and `SERVICE_DESCRIPTIONS` associative array

### Template System
- Base template (`templates/base.yml`) always included
- Additional templates merged based on service selection
- Templates use environment variable substitution with `${VARIABLE}` syntax
- Post-processing applies service-specific configurations via sed commands

### Environment Variables  
All configuration stored in SERVICE_CONFIG associative array, then written to .env file. Key patterns:
- `N8N_*` - n8n specific settings
- `POSTGRES_*` - PostgreSQL configuration  
- `QDRANT_*` - Qdrant vector database settings
- `CF_DNS_API_TOKEN` - Cloudflare API token for SSL certificates
- `WEBHOOK_URL` - Primary domain for the deployment

### SSL Certificate Management
- Automatic Let's Encrypt certificates via Traefik
- Supports Cloudflare DNS challenge (recommended) and HTTP challenge
- `letsencrypt/acme.json` must have 600 permissions
- Domain DNS must be configured before SSL generation

## Common Development Tasks

### Adding a New Service
1. Create `templates/[service].yml` with service definition
2. Add service to `AVAILABLE_SERVICES` array in setup.sh:12
3. Add description to `SERVICE_DESCRIPTIONS` array in setup.sh:14
4. Create `configure_[service]()` function
5. Add service case in main configuration loop (setup.sh:1067)
6. Update environment file generation if needed (setup.sh:1127+)

### Testing Configuration Changes
- Use `./setup.sh --debug` to generate files without starting services
- Validate Docker Compose syntax: `docker compose config`
- Test individual service templates by examining generated `docker-compose.yml`

### Debugging SSL Issues
- Check DNS records point to correct IP
- Verify ports 80/443 are accessible from internet
- Monitor Traefik logs: `docker compose logs -f traefik`
- Validate Cloudflare API token permissions

### Modifying Service Access
- Traefik routing: Add labels to service template
- Port-based access: Add ports section to service template  
- Subdomain configuration: Update service's configure function

## Security Considerations

- Strong password generation using `openssl rand`
- Basic authentication for admin interfaces
- SSL-only access when Traefik is enabled
- Docker socket access limited where possible
- Environment file contains sensitive data - exclude from version control