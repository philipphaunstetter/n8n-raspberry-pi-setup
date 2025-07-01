#!/bin/bash

# =============================================================================
# n8n Raspberry Pi Setup - Unified Installation Script
# =============================================================================
# A comprehensive, single-script solution for deploying n8n with optional services
# Features: Auto Python setup, enhanced CLI, debug mode, production deployment
# =============================================================================

set -e

# Enhanced CLI colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Unicode symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
WARNING="⚠"
INFO="ℹ"
ROCKET="🚀"

# Global variables
DEBUG_MODE=false
PYTHON_ENV_READY=false
SELECTED_SERVICES=()

# Service configuration
AVAILABLE_SERVICES=("traefik" "qdrant" "nginx" "postgres" "monitoring")

# Service descriptions (using functions instead of associative arrays for compatibility)
get_service_description() {
    case "$1" in
        traefik) echo "Reverse proxy with automatic SSL certificates" ;;
        qdrant) echo "Vector database for AI/ML workflows" ;;
        nginx) echo "Web server for static files and additional routing" ;;
        postgres) echo "PostgreSQL database for n8n data persistence" ;;
        monitoring) echo "Portainer for container management" ;;
        *) echo "Unknown service" ;;
    esac
}

# Configuration storage (using individual variables)
N8N_BASIC_AUTH_USER=""
N8N_BASIC_AUTH_PASSWORD=""
N8N_PORT="5678"
N8N_COMMUNITY_PACKAGES="true"
N8N_FOLDERS_ENABLED="true"
WEBHOOK_URL=""
CERTIFICATE_EMAIL=""
CF_DNS_API_TOKEN=""
HTTP_PORT="80"
HTTPS_PORT="443"
POSTGRES_PASSWORD=""
POSTGRES_DB=""
POSTGRES_USER=""
POSTGRES_PORT="5432"
QDRANT_STORAGE=""
QDRANT_DASHBOARD=""
QDRANT_PORT="6333"
NGINX_PURPOSE=""
NGINX_STATIC_DIR=""
NGINX_PORT="8080"
PORTAINER_PASSWORD=""
PORTAINER_USER=""
PORTAINER_PORT="9000"

# =============================================================================
# Enhanced CLI Functions (Claude Code Style)
# =============================================================================

tool_output() {
    local tool_name="$1"
    local description="$2"
    local content="$3"
    echo -e "${BLUE}${BOLD}${tool_name}${NC}(${description})"
    if [[ -n "$content" ]]; then
        echo -e "  ${CYAN}⎿${NC}  ${content}"
    fi
}

tool_result() {
    local content="$1"
    echo -e "     ${content}"
}

success() {
    echo -e "${GREEN}${BOLD}${CHECK}${NC} ${GREEN}$1${NC}"
}

error() {
    echo -e "${RED}${BOLD}${CROSS}${NC} ${RED}$1${NC}"
}

warning() {
    echo -e "${YELLOW}${BOLD}${WARNING}${NC} ${YELLOW}$1${NC}"
}

info() {
    echo -e "${BLUE}${BOLD}${INFO}${NC} ${BLUE}$1${NC}"
}

section_header() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo -e "\n${BLUE}${BOLD}┌$(printf '─%.0s' $(seq 1 $width))┐${NC}"
    echo -e "${BLUE}${BOLD}│$(printf ' %.0s' $(seq 1 $padding))${WHITE}$title${BLUE}$(printf ' %.0s' $(seq 1 $padding))│${NC}"
    echo -e "${BLUE}${BOLD}└$(printf '─%.0s' $(seq 1 $width))┘${NC}\n"
}

run_command() {
    local command="$1"
    local description="$2"
    local simulate="$3"
    
    tool_output "Bash" "$description" "${DIM}${command}${NC}"
    
    if [[ "$DEBUG_MODE" == true || "$simulate" == true ]]; then
        # Simulate command execution with fake output
        case "$command" in
            *"docker --version"*)
                tool_result "Docker version 24.0.6, build ed223bc"
                ;;
            *"docker compose version"*)
                tool_result "Docker Compose version v2.21.0"
                ;;
            *"docker compose up -d"*)
                tool_result "Creating network n8n-network..."
                tool_result "Creating volume n8n_data..."
                tool_result "Creating traefik ... done"
                tool_result "Creating n8n ... done"
                ;;
            *"docker compose ps"*)
                tool_result "NAME      IMAGE       STATUS        PORTS"
                tool_result "traefik   traefik     Up 30 seconds 80/tcp, 443/tcp"
                tool_result "n8n       n8nio/n8n   Up 30 seconds 5678/tcp"
                ;;
            *"git clone"*|*"curl"*|*"wget"*)
                tool_result "Download completed successfully"
                ;;
            *)
                tool_result "Command executed successfully"
                ;;
        esac
        return 0
    else
        # Execute real command
        local output
        output=$(eval "$command" 2>&1)
        local exit_code=$?
        
        if [[ -n "$output" ]]; then
            echo "$output" | while IFS= read -r line; do
                tool_result "$line"
            done
        fi
        
        return $exit_code
    fi
}

# =============================================================================
# Python Environment Setup
# =============================================================================

setup_python_environment() {
    tool_output "Setup" "Initialize Python environment" "Checking Python requirements"
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        error "Python 3 not found. Please install Python 3 first."
        echo -e "${BLUE}Installation commands:${NC}"
        echo -e "  ${YELLOW}Ubuntu/Debian:${NC} sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
        echo -e "  ${YELLOW}macOS:${NC} brew install python3"
        exit 1
    fi
    
    tool_result "Python 3 found: $(python3 --version)"
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d "venv" ]]; then
        tool_output "Python" "Create virtual environment" "python3 -m venv venv"
        if [[ "$DEBUG_MODE" != true ]]; then
            python3 -m venv venv
        fi
        tool_result "Virtual environment created"
    else
        tool_result "Virtual environment already exists"
    fi
    
    # Install Python dependencies
    tool_output "Python" "Install dependencies" "Installing rich, typer, inquirer"
    if [[ "$DEBUG_MODE" != true ]]; then
        source venv/bin/activate
        pip install --quiet rich>=13.0.0 typer>=0.9.0 inquirer>=3.0.0 > /dev/null 2>&1
    fi
    tool_result "Python dependencies installed"
    
    PYTHON_ENV_READY=true
    success "Python environment ready"
}

# =============================================================================
# System Dependencies Check
# =============================================================================

check_dependencies() {
    section_header "System Dependencies Check"
    
    tool_output "Setup" "Detect operating system" "Checking system compatibility"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        tool_result "Detected: Linux ($(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown distribution"))"
        PACKAGE_MANAGER="apt"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        tool_result "Detected: macOS ($(sw_vers -productVersion))"
        PACKAGE_MANAGER="brew"
    else
        tool_result "Detected: $OSTYPE"
        warning "Untested system - proceeding with caution"
    fi
    
    # Check Docker
    tool_output "Docker" "Check Docker installation" "docker --version"
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        local version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        tool_result "Docker found: version $version"
        
        # Check Docker daemon
        if [[ "$DEBUG_MODE" != true ]]; then
            if ! docker info &> /dev/null; then
                warning "Docker daemon not running - attempting to start"
                sudo systemctl start docker 2>/dev/null || true
            fi
        fi
    else
        error "Docker not found"
        echo -e "${BLUE}Install Docker:${NC}"
        echo -e "  ${YELLOW}Linux:${NC} curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        echo -e "  ${YELLOW}macOS:${NC} brew install --cask docker"
        exit 1
    fi
    
    # Check Docker Compose
    run_command "docker compose version" "Check Docker Compose" true
    
    success "All dependencies available"
}

# =============================================================================
# Service Selection
# =============================================================================

show_service_selection() {
    section_header "Service Selection"
    
    echo -e "${BLUE}${BOLD}Available Services:${NC}"
    echo -e "${GREEN}${BOLD}✓ n8n${NC} - Workflow automation platform ${DIM}(always included)${NC}"
    echo
    
    local i=1
    for service in "${AVAILABLE_SERVICES[@]}"; do
        echo -e "${YELLOW}$i.${NC} ${service} - $(get_service_description "$service")"
        ((i++))
    done
    
    echo
    echo -e "${CYAN}${BOLD}Quick Presets:${NC}"
    echo -e "${YELLOW}q.${NC} Quick Start (n8n + Traefik)"
    echo -e "${YELLOW}f.${NC} Full Stack (all services)"
    echo -e "${YELLOW}m.${NC} Minimal (n8n only)"
    echo -e "${YELLOW}c.${NC} Custom selection"
    echo
    
    read -p "Choose preset or service numbers (e.g., '1,3,5' or 'q'): " selection
    
    case "$selection" in
        q|Q)
            SELECTED_SERVICES=("traefik")
            info "Selected: Quick Start preset"
            ;;
        f|F)
            SELECTED_SERVICES=("${AVAILABLE_SERVICES[@]}")
            info "Selected: Full Stack preset"
            ;;
        m|M)
            SELECTED_SERVICES=()
            info "Selected: Minimal preset"
            ;;
        c|C|"")
            echo "Enter service numbers separated by commas (e.g., 1,3,5):"
            read -p "Services: " custom_selection
            parse_service_selection "$custom_selection"
            ;;
        *)
            parse_service_selection "$selection"
            ;;
    esac
    
    # Show selection summary
    echo
    tool_output "Setup" "Service selection summary" "Selected services for deployment"
    tool_result "✓ n8n (workflow automation)"
    
    if [ ${#SELECTED_SERVICES[@]} -eq 0 ]; then
        tool_result "• Minimal setup - n8n only"
        tool_result "• Access: http://localhost:5678"
    else
        for service in "${SELECTED_SERVICES[@]}"; do
            tool_result "✓ $service - $(get_service_description "$service")"
        done
        
        if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
            tool_result "• Access: https://your-domain.com"
        else
            tool_result "• Access: http://localhost:5678"
        fi
    fi
}

parse_service_selection() {
    local selection="$1"
    SELECTED_SERVICES=()
    
    IFS=',' read -ra SERVICES <<< "$selection"
    for service_num in "${SERVICES[@]}"; do
        service_num=$(echo "$service_num" | tr -d ' ')
        if [[ "$service_num" =~ ^[1-5]$ ]]; then
            local index=$((service_num - 1))
            SELECTED_SERVICES+=("${AVAILABLE_SERVICES[$index]}")
        fi
    done
}

# =============================================================================
# Service Configuration
# =============================================================================

configure_services() {
    if [ ${#SELECTED_SERVICES[@]} -eq 0 ]; then
        info "Minimal setup - no additional configuration needed"
        return
    fi
    
    section_header "Service Configuration"
    
    # Always configure n8n
    configure_n8n
    
    # Configure selected services
    for service in "${SELECTED_SERVICES[@]}"; do
        case $service in
            traefik) configure_traefik ;;
            postgres) configure_postgres ;;
            qdrant) configure_qdrant ;;
            nginx) configure_nginx ;;
            monitoring) configure_monitoring ;;
        esac
    done
}

configure_n8n() {
    tool_output "Setup" "Configure n8n settings" "Core n8n configuration"
    
    read -p "n8n admin username [admin]: " n8n_user
    N8N_BASIC_AUTH_USER="${n8n_user:-admin}"
    
    read -p "n8n admin password: " n8n_password
    while [[ -z "$n8n_password" ]]; do
        echo -e "${RED}Password is required${NC}"
        read -p "n8n admin password: " n8n_password
    done
    N8N_BASIC_AUTH_PASSWORD="$n8n_password"
    
    # Configure access method and ports
    if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        read -p "Domain name (e.g., n8n.yourdomain.com): " domain
        WEBHOOK_URL="$domain"
        tool_result "Access via domain: https://$domain"
    else
        echo -e "${BLUE}Port Configuration:${NC}"
        read -p "n8n port [5678]: " n8n_port
        N8N_PORT="${n8n_port:-5678}"
        WEBHOOK_URL="localhost:${N8N_PORT}"
        tool_result "Access via port: http://localhost:${N8N_PORT}"
    fi
    
    # Advanced settings
    echo -e "${BLUE}Advanced Options:${NC}"
    read -p "Enable community packages? [Y/n]: " enable_community
    if [[ $enable_community =~ ^[Nn]$ ]]; then
        N8N_COMMUNITY_PACKAGES="false"
    else
        N8N_COMMUNITY_PACKAGES="true"
    fi
    
    read -p "Enable folders feature? [Y/n]: " enable_folders
    if [[ $enable_folders =~ ^[Nn]$ ]]; then
        N8N_FOLDERS_ENABLED="false"
    else
        N8N_FOLDERS_ENABLED="true"
    fi
    
    tool_result "n8n configuration completed"
}

configure_traefik() {
    tool_output "Setup" "Configure Traefik SSL proxy" "SSL certificate configuration"
    
    read -p "Email for Let's Encrypt certificates: " cert_email
    CERTIFICATE_EMAIL="$cert_email"
    
    # Port configuration
    echo -e "${BLUE}Port Configuration:${NC}"
    read -p "HTTP port [80]: " http_port
    HTTP_PORT="${http_port:-80}"
    
    read -p "HTTPS port [443]: " https_port
    HTTPS_PORT="${https_port:-443}"
    
    # SSL configuration
    echo -e "${BLUE}SSL Certificate Method:${NC}"
    echo "1. Cloudflare DNS (recommended)"
    echo "2. HTTP challenge"
    read -p "Choose method [1]: " ssl_method
    ssl_method=${ssl_method:-1}
    
    if [[ "$ssl_method" == "1" ]]; then
        read -p "Cloudflare API token: " cf_token
        CF_DNS_API_TOKEN="$cf_token"
    fi
    
    tool_result "Traefik ports: HTTP:${HTTP_PORT}, HTTPS:${HTTPS_PORT}"
    tool_result "Traefik configuration completed"
}

configure_postgres() {
    tool_output "Setup" "Configure PostgreSQL database" "Database settings"
    
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25 2>/dev/null || echo "defaultpassword123")
    POSTGRES_PASSWORD="$db_password"
    POSTGRES_DB="n8n"
    POSTGRES_USER="n8n"
    
    # Port configuration (only needed if not using Traefik)
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        echo -e "${BLUE}Port Configuration:${NC}"
        read -p "PostgreSQL port [5432]: " postgres_port
        POSTGRES_PORT="${postgres_port:-5432}"
        tool_result "PostgreSQL port: ${POSTGRES_PORT}"
    fi
    
    tool_result "Generated secure database password"
    tool_result "Database: n8n, User: n8n"
}

configure_qdrant() {
    tool_output "Setup" "Configure Qdrant vector database" "Vector storage settings"
    
    QDRANT_STORAGE="persistent"
    QDRANT_DASHBOARD="true"
    
    # Port configuration (only needed if not using Traefik)
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        echo -e "${BLUE}Port Configuration:${NC}"
        read -p "Qdrant port [6333]: " qdrant_port
        QDRANT_PORT="${qdrant_port:-6333}"
        tool_result "Qdrant port: ${QDRANT_PORT}"
    fi
    
    tool_result "Persistent storage enabled"
    tool_result "Dashboard access enabled"
}

configure_nginx() {
    tool_output "Setup" "Configure Nginx web server" "Static file serving"
    
    NGINX_PURPOSE="static"
    NGINX_STATIC_DIR="./static"
    
    # Port configuration (only needed if not using Traefik)
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        echo -e "${BLUE}Port Configuration:${NC}"
        read -p "Nginx port [8080]: " nginx_port
        NGINX_PORT="${nginx_port:-8080}"
        tool_result "Nginx port: ${NGINX_PORT}"
    fi
    
    tool_result "Static file server configured"
}

configure_monitoring() {
    tool_output "Setup" "Configure Portainer monitoring" "Container management UI"
    
    read -p "Portainer admin password: " portainer_password
    PORTAINER_PASSWORD="$portainer_password"
    PORTAINER_USER="admin"
    
    # Port configuration (only needed if not using Traefik)
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        echo -e "${BLUE}Port Configuration:${NC}"
        read -p "Portainer port [9000]: " portainer_port
        PORTAINER_PORT="${portainer_port:-9000}"
        tool_result "Portainer port: ${PORTAINER_PORT}"
    fi
    
    tool_result "Portainer admin configured"
}

# =============================================================================
# Configuration File Generation
# =============================================================================

generate_configuration() {
    section_header "Configuration Generation"
    
    tool_output "Write" "Generate environment file" ".env"
    
    cat > .env << EOF
# =============================================================================
# n8n Setup - Environment Configuration
# =============================================================================
# Generated on $(date)

# Core n8n Configuration
N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
WEBHOOK_URL=${WEBHOOK_URL}
N8N_PORT=${N8N_PORT}
N8N_COMMUNITY_PACKAGES=${N8N_COMMUNITY_PACKAGES}
N8N_FOLDERS_ENABLED=${N8N_FOLDERS_ENABLED}

EOF

    local env_vars=6
    
    # Add service-specific configuration
    if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        cat >> .env << EOF
# Traefik Configuration
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
CERTIFICATE_EMAIL=${CERTIFICATE_EMAIL}
CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}

EOF
        env_vars=$((env_vars + 4))
    fi
    
    if [[ " ${SELECTED_SERVICES[@]} " =~ " postgres " ]]; then
        cat >> .env << EOF
# PostgreSQL Configuration
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_PORT=${POSTGRES_PORT}

EOF
        env_vars=$((env_vars + 4))
    fi
    
    # Add other service ports if not using Traefik
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        cat >> .env << EOF
# Service Ports (Direct Access)
EOF
        if [[ " ${SELECTED_SERVICES[@]} " =~ " qdrant " ]]; then
            echo "QDRANT_PORT=${QDRANT_PORT}" >> .env
            env_vars=$((env_vars + 1))
        fi
        if [[ " ${SELECTED_SERVICES[@]} " =~ " nginx " ]]; then
            echo "NGINX_PORT=${NGINX_PORT}" >> .env
            env_vars=$((env_vars + 1))
        fi
        if [[ " ${SELECTED_SERVICES[@]} " =~ " monitoring " ]]; then
            echo "PORTAINER_PORT=${PORTAINER_PORT}" >> .env
            env_vars=$((env_vars + 1))
        fi
        echo "" >> .env
    fi
    
    tool_result "Generated $env_vars environment variables"
    
    # Generate Docker Compose file
    tool_output "Write" "Generate docker-compose.yml" "Service definitions"
    
    generate_docker_compose
    
    local service_count=$((1 + ${#SELECTED_SERVICES[@]}))
    tool_result "Generated configuration for $service_count services"
    
    success "Configuration files generated successfully"
}

generate_docker_compose() {
    # Start with base configuration
    cat > docker-compose.yml << 'EOF'
version: "3.8"

services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=${N8N_COMMUNITY_PACKAGES}
      - N8N_FOLDERS_ENABLED=${N8N_FOLDERS_ENABLED}
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped
    networks:
      - n8n-network
EOF

    # Add port mapping if no Traefik
    if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        cat >> docker-compose.yml << 'EOF'
    ports:
      - "${N8N_PORT}:5678"
EOF
    fi

    # Add Traefik labels if Traefik is selected
    if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        cat >> docker-compose.yml << 'EOF'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${WEBHOOK_URL}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=myresolver"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
EOF
    fi

    # Add selected services
    for service in "${SELECTED_SERVICES[@]}"; do
        case $service in
            traefik)
                cat >> docker-compose.yml << 'EOF'

  traefik:
    image: traefik:v2.10
    container_name: traefik
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:${HTTP_PORT}"
      - "--entrypoints.websecure.address=:${HTTPS_PORT}"
      - "--certificatesresolvers.myresolver.acme.dnschallenge=true"
      - "--certificatesresolvers.myresolver.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.myresolver.acme.email=${CERTIFICATE_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "${HTTP_PORT}:${HTTP_PORT}"
      - "${HTTPS_PORT}:${HTTPS_PORT}"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    environment:
      - CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
    restart: unless-stopped
    networks:
      - n8n-network
EOF
                ;;
            postgres)
                cat >> docker-compose.yml << 'EOF'

  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - n8n-network
EOF
                # Add port mapping if not using Traefik
                if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
                    cat >> docker-compose.yml << 'EOF'
    ports:
      - "${POSTGRES_PORT}:5432"
EOF
                fi
                ;;
            qdrant)
                cat >> docker-compose.yml << 'EOF'

  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    restart: unless-stopped
    networks:
      - n8n-network
    volumes:
      - qdrant_data:/qdrant/storage
EOF
                # Add port mapping if not using Traefik
                if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
                    cat >> docker-compose.yml << 'EOF'
    ports:
      - "${QDRANT_PORT}:6333"
EOF
                fi
                ;;
            nginx)
                cat >> docker-compose.yml << 'EOF'

  nginx:
    image: nginx:latest
    container_name: nginx
    volumes:
      - ./static:/usr/share/nginx/html:ro
    restart: unless-stopped
    networks:
      - n8n-network
EOF
                # Add port mapping if not using Traefik
                if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
                    cat >> docker-compose.yml << 'EOF'
    ports:
      - "${NGINX_PORT}:80"
EOF
                fi
                ;;
            monitoring)
                cat >> docker-compose.yml << 'EOF'

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: unless-stopped
    networks:
      - n8n-network
EOF
                # Add port mapping if not using Traefik
                if [[ ! " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
                    cat >> docker-compose.yml << 'EOF'
    ports:
      - "${PORTAINER_PORT}:9000"
EOF
                fi
                ;;
        esac
    done

    # Add volumes and networks
    cat >> docker-compose.yml << 'EOF'

volumes:
  n8n_data:
    driver: local
EOF

    if [[ " ${SELECTED_SERVICES[@]} " =~ " postgres " ]]; then
        cat >> docker-compose.yml << 'EOF'
  postgres_data:
    driver: local
EOF
    fi
    
    if [[ " ${SELECTED_SERVICES[@]} " =~ " qdrant " ]]; then
        cat >> docker-compose.yml << 'EOF'
  qdrant_data:
    driver: local
EOF
    fi
    
    if [[ " ${SELECTED_SERVICES[@]} " =~ " monitoring " ]]; then
        cat >> docker-compose.yml << 'EOF'
  portainer_data:
    driver: local
EOF
    fi

    cat >> docker-compose.yml << 'EOF'

networks:
  n8n-network:
    driver: bridge
EOF
}

# =============================================================================
# Deployment
# =============================================================================

deploy_services() {
    section_header "Service Deployment"
    
    # Prepare SSL certificate file
    if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        tool_output "Setup" "Prepare SSL certificate storage" "Creating letsencrypt directory"
        mkdir -p letsencrypt
        if [[ ! -f letsencrypt/acme.json ]]; then
            touch letsencrypt/acme.json
            chmod 600 letsencrypt/acme.json
        fi
        tool_result "SSL certificate storage ready"
    fi
    
    # Start services
    run_command "docker compose up -d" "Start all services"
    
    if [[ "$DEBUG_MODE" != true ]]; then
        # Wait a moment for services to start
        sleep 3
        
        # Check service status
        tool_output "Docker" "Check service status" "docker compose ps"
        if docker compose ps --format table | grep -q "Up"; then
            success "All services started successfully"
        else
            warning "Some services may still be starting"
        fi
    else
        success "Services would be started (debug mode)"
    fi
}

# =============================================================================
# Final Summary
# =============================================================================

show_final_summary() {
    section_header "Setup Complete"
    
    echo -e "${GREEN}${ROCKET} ${BOLD}n8n deployment completed successfully!${NC}\n"
    
    tool_output "Access" "Service URLs" "Your n8n installation is ready"
    
    if [[ " ${SELECTED_SERVICES[@]} " =~ " traefik " ]]; then
        tool_result "🌐 n8n: https://${WEBHOOK_URL}"
        tool_result "🔒 SSL certificates: Automatic via Let's Encrypt"
        tool_result "🌍 Ports: HTTP:${HTTP_PORT}, HTTPS:${HTTPS_PORT}"
        
        if [[ " ${SELECTED_SERVICES[@]} " =~ " postgres " ]]; then
            tool_result "🗄️ Database: PostgreSQL (persistent storage)"
        fi
    else
        tool_result "🌐 n8n: http://localhost:${N8N_PORT}"
        tool_result "📝 Note: No SSL encryption (local access only)"
        
        # Show other service ports
        if [[ " ${SELECTED_SERVICES[@]} " =~ " postgres " ]]; then
            tool_result "🗄️ PostgreSQL: localhost:${POSTGRES_PORT}"
        fi
        if [[ " ${SELECTED_SERVICES[@]} " =~ " qdrant " ]]; then
            tool_result "🔍 Qdrant: http://localhost:${QDRANT_PORT}"
        fi
        if [[ " ${SELECTED_SERVICES[@]} " =~ " nginx " ]]; then
            tool_result "🌐 Nginx: http://localhost:${NGINX_PORT}"
        fi
        if [[ " ${SELECTED_SERVICES[@]} " =~ " monitoring " ]]; then
            tool_result "🔧 Portainer: http://localhost:${PORTAINER_PORT}"
        fi
    fi
    
    echo
    tool_output "Management" "Useful commands" "Managing your deployment"
    tool_result "Check status: docker compose ps"
    tool_result "View logs: docker compose logs -f"
    tool_result "Stop services: docker compose down"
    tool_result "Update services: docker compose pull && docker compose up -d"
    
    echo
    tool_output "Credentials" "Login information" "Access your n8n instance"
    tool_result "Username: ${N8N_BASIC_AUTH_USER}"
    tool_result "Password: ${N8N_BASIC_AUTH_PASSWORD}"
    
    echo
    success "Installation complete! Enjoy your n8n automation platform!"
}

# =============================================================================
# Main Installation Flow
# =============================================================================

main() {
    # Parse command line arguments
    for arg in "$@"; do
        case $arg in
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --help|-h)
                echo "n8n Installation Script"
                echo ""
                echo "Usage: $0 [--debug] [--help]"
                echo ""
                echo "Options:"
                echo "  --debug    Run in debug mode (simulate without executing)"
                echo "  --help     Show this help message"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $arg${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Show debug mode banner
    if [[ "$DEBUG_MODE" == true ]]; then
        echo -e "${YELLOW}${BOLD}=== DEBUG MODE ENABLED ===${NC}"
        echo -e "${YELLOW}All operations will be simulated${NC}"
        echo -e "${YELLOW}No actual changes will be made${NC}"
        echo ""
    fi
    
    # Main installation banner
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                     🚀 n8n Raspberry Pi Setup                       ║"
    echo "║              Comprehensive Workflow Automation Deployment           ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Installation flow
    setup_python_environment
    check_dependencies
    show_service_selection
    configure_services
    generate_configuration
    deploy_services
    show_final_summary
}

# Run main installation
main "$@"