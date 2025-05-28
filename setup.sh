#!/bin/bash

# Setup colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

# Service configuration
AVAILABLE_SERVICES=("traefik" "qdrant" "nginx" "postgres" "monitoring")
SELECTED_SERVICES=()
declare -A SERVICE_DESCRIPTIONS
SERVICE_DESCRIPTIONS[traefik]="Reverse proxy with automatic SSL certificates"
SERVICE_DESCRIPTIONS[qdrant]="Vector database for AI/ML workflows"
SERVICE_DESCRIPTIONS[nginx]="Web server for static files and additional routing"
SERVICE_DESCRIPTIONS[postgres]="PostgreSQL database for n8n data persistence"
SERVICE_DESCRIPTIONS[monitoring]="Portainer for container management"

# Service dependencies
declare -A SERVICE_DEPENDENCIES
SERVICE_DEPENDENCIES[postgres]="traefik"  # PostgreSQL works better with Traefik for admin access

# Parse command line arguments
DEBUG_MODE=false
for arg in "$@"; do
    case $arg in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--debug] [--help]"
            echo ""
            echo "Options:"
            echo "  --debug    Run in debug mode (skip Docker Compose execution)"
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

if [ "$DEBUG_MODE" = true ]; then
    echo -e "${YELLOW}${BOLD}=== DEBUG MODE ENABLED ===${NC}"
    echo -e "${YELLOW}Docker Compose will NOT be executed${NC}"
    echo ""
fi

echo -e "${BLUE}${BOLD}=== n8n + Services Setup for Raspberry Pi ===${NC}"

# Function to detect OS and package manager
detect_system() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="sudo apt-get update && sudo apt-get install -y"
            OS_TYPE="ubuntu"
        elif command -v apt &> /dev/null; then
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="sudo apt update && sudo apt install -y"
            OS_TYPE="ubuntu"
        else
            echo -e "${RED}This setup script is designed for Ubuntu/Debian systems.${NC}"
            echo -e "${RED}Please install the required dependencies manually:${NC}"
            echo -e "${BLUE}  - Docker and Docker Compose${NC}"
            echo -e "${BLUE}  - gettext-base (for envsubst)${NC}"
            echo -e "${BLUE}  - openssl and curl${NC}"
            exit 1
        fi
    else
        echo -e "${RED}This setup script is designed for Linux systems only.${NC}"
        echo -e "${RED}Detected OS: $OSTYPE${NC}"
        echo -e "${YELLOW}Please use a Ubuntu/Debian-based Linux distribution.${NC}"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get package name for Ubuntu/Debian
get_package_name() {
    local tool="$1"
    case "$tool" in
        "docker") echo "docker.io" ;;
        "docker-compose") echo "docker-compose-plugin" ;;
        "envsubst") echo "gettext-base" ;;
        "openssl") echo "openssl" ;;
        "curl") echo "curl" ;;
        "git") echo "git" ;;
        *) echo "$tool" ;;
    esac
}

# Function to install a dependency
install_dependency() {
    local tool="$1"
    local package_name=$(get_package_name "$tool")
    
    echo -e "${YELLOW}Installing $tool...${NC}"
    
    if [[ "$tool" == "docker" ]]; then
        # Docker installation for Ubuntu/Debian using official script
        echo -e "${BLUE}Installing Docker using official repository...${NC}"
        
        # Remove old Docker packages
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Update package index
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up the repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index again
        sudo apt-get update
        
        # Install Docker Engine, containerd, and Docker Compose
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        # Start and enable Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        echo -e "${GREEN}✔ Docker installed successfully${NC}"
        echo -e "${YELLOW}Note: You may need to log out and back in for Docker group membership to take effect${NC}"
        echo -e "${YELLOW}Or run: newgrp docker${NC}"
    else
        # Install other packages using apt
        eval "$INSTALL_CMD $package_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✔ $tool installed successfully${NC}"
        else
            echo -e "${RED}✖ Failed to install $tool${NC}"
            return 1
        fi
    fi
}

# Function to check Docker Compose version and method
check_docker_compose() {
    # Check for Docker Compose v2 (preferred)
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        local version=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✔ Docker Compose v2 found (version: $version)${NC}"
        return 0
    # Check for Docker Compose v1 (legacy)
    elif command_exists docker-compose; then
        DOCKER_COMPOSE_CMD="docker-compose"
        local version=$(docker-compose version --short 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}⚠ Docker Compose v1 found (version: $version)${NC}"
        echo -e "${YELLOW}  Consider upgrading to Docker Compose v2${NC}"
        return 0
    else
        return 1
    fi
}

# Function to check individual dependency
check_dependency() {
    local tool="$1"
    local description="$2"
    local required="$3"
    local install_option="$4"
    
    echo -n "Checking for $description... "
    
    case "$tool" in
        "docker")
            if command_exists docker && docker --version &> /dev/null; then
                local version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
                echo -e "${GREEN}✔ found (version: $version)${NC}"
                
                # Check if Docker daemon is running
                if ! docker info &> /dev/null; then
                    echo -e "${YELLOW}⚠ Docker daemon is not running${NC}"
                    echo -e "${BLUE}Starting Docker service...${NC}"
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    
                    # Wait a moment and check again
                    sleep 2
                    if ! docker info &> /dev/null; then
                        echo -e "${RED}✖ Failed to start Docker daemon${NC}"
                        return 1
                    fi
                fi
                return 0
            fi
            ;;
        "docker-compose")
            if check_docker_compose; then
                return 0
            fi
            ;;
        *)
            if command_exists "$tool"; then
                local version=""
                case "$tool" in
                    "openssl") version=$(openssl version 2>/dev/null | cut -d' ' -f2) ;;
                    "curl") version=$(curl --version 2>/dev/null | head -n1 | cut -d' ' -f2) ;;
                    "git") version=$(git --version 2>/dev/null | cut -d' ' -f3) ;;
                    "envsubst") version="available" ;;
                esac
                echo -e "${GREEN}✔ found${NC}${version:+ (version: $version)}"
                return 0
            fi
            ;;
    esac
    
    # Tool not found
    if [[ "$required" == "required" ]]; then
        echo -e "${RED}✖ not found (required)${NC}"
    else
        echo -e "${YELLOW}⚠ not found (optional)${NC}"
    fi
    
    # Offer installation if possible
    if [[ "$install_option" == "auto" ]]; then
        if [[ "$required" == "required" ]]; then
            read -p "Would you like to install $description automatically? (Y/n): " install_choice
            if [[ ! $install_choice =~ ^[Nn]$ ]]; then
                if install_dependency "$tool"; then
                    echo -e "${GREEN}✔ $description installed successfully${NC}"
                    return 0
                else
                    echo -e "${RED}✖ Failed to install $description${NC}"
                    return 1
                fi
            fi
        else
            echo -e "${BLUE}To install manually: $INSTALL_CMD $(get_package_name "$tool")${NC}"
        fi
    fi
    
    return 1
}

# Function to show manual installation instructions
show_manual_instructions() {
    echo -e "${BLUE}${BOLD}=== Manual Installation Instructions ===${NC}"
    echo ""
    echo -e "${BLUE}For Ubuntu/Debian systems:${NC}"
    echo ""
    echo -e "${YELLOW}Install Docker:${NC}"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    echo ""
    echo -e "${YELLOW}Install other dependencies:${NC}"
    echo "  sudo apt update"
    echo "  sudo apt install -y gettext-base openssl curl git"
    echo ""
    echo -e "${YELLOW}After installation:${NC}"
    echo "  # Log out and back in, or run:"
    echo "  newgrp docker"
    echo ""
}

# Main dependency checking function
check_dependencies() {
    if [[ "$DEBUG_MODE" == true ]]; then
        echo -e "${YELLOW}Debug mode: Skipping dependency checks${NC}"
        echo ""
        return 0
    fi
    
    echo -e "${BLUE}${BOLD}=== Checking System Dependencies ===${NC}"
    
    # Detect system first
    detect_system
    echo -e "${BLUE}Detected OS: $OS_TYPE (Linux)${NC}"
    echo -e "${BLUE}Package manager: $PACKAGE_MANAGER${NC}"
    echo ""
    
    local missing_required=()
    local missing_optional=()
    
    # Check required dependencies
    echo -e "${BLUE}Required dependencies:${NC}"
    
    if ! check_dependency "docker" "Docker" "required" "auto"; then
        missing_required+=("docker")
    fi
    
    if ! check_dependency "docker-compose" "Docker Compose" "required" "auto"; then
        missing_required+=("docker-compose")
    fi
    
    if ! check_dependency "envsubst" "envsubst (gettext)" "required" "auto"; then
        missing_required+=("envsubst")
    fi
    
    echo ""
    echo -e "${BLUE}Optional dependencies:${NC}"
    
    if ! check_dependency "openssl" "OpenSSL" "optional" "auto"; then
        missing_optional+=("openssl")
    fi
    
    if ! check_dependency "curl" "curl" "optional" "auto"; then
        missing_optional+=("curl")
    fi
    
    if ! check_dependency "git" "Git" "optional" "auto"; then
        missing_optional+=("git")
    fi
    
    echo ""
    
    # Handle missing dependencies
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}Missing required dependencies: ${missing_required[*]}${NC}"
        echo ""
        show_manual_instructions
        echo -e "${RED}Please install the missing dependencies and run the setup again.${NC}"
        exit 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing optional dependencies: ${missing_optional[*]}${NC}"
        echo -e "${BLUE}The setup will continue, but some features may be limited.${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}${BOLD}✔ All required dependencies are available!${NC}"
    echo ""
    
    # Additional Docker checks
    if command_exists docker; then
        echo -e "${BLUE}Performing additional Docker checks...${NC}"
        
        # Check Docker daemon
        if ! docker info &> /dev/null; then
            echo -e "${RED}✖ Docker daemon is not running${NC}"
            echo -e "${YELLOW}Attempting to start Docker...${NC}"
            sudo systemctl start docker
            sleep 2
            if ! docker info &> /dev/null; then
                echo -e "${RED}✖ Failed to start Docker daemon${NC}"
                echo -e "${YELLOW}Please start Docker manually and run the setup again${NC}"
                exit 1
            fi
        fi
        
        # Check Docker permissions
        if ! docker ps &> /dev/null; then
            echo -e "${YELLOW}⚠ Current user may not have Docker permissions${NC}"
            echo -e "${BLUE}Adding user to docker group...${NC}"
            sudo usermod -aG docker $USER
            echo -e "${YELLOW}Please log out and back in, or run: newgrp docker${NC}"
            echo -e "${YELLOW}Then run this setup script again.${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✔ Docker is running and accessible${NC}"
    fi
    
    echo ""
}

# Run dependency checks
check_dependencies

# Function to show infrastructure requirements
show_infrastructure_requirements() {
    echo -e "${BLUE}${BOLD}=== Infrastructure Requirements & Pre-Setup Guide ===${NC}"
    echo -e "${BLUE}Before configuring your n8n setup, please ensure you have completed the following preparations:${NC}"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🌐 Domain & DNS Requirements${NC}"
    echo -e "${BLUE}If you plan to use Traefik with SSL certificates:${NC}"
    echo -e "  ${GREEN}✓${NC} Own a domain name (e.g., yourdomain.com)"
    echo -e "  ${GREEN}✓${NC} Domain managed by Cloudflare (recommended) or accessible via HTTP"
    echo -e "  ${GREEN}✓${NC} DNS A record pointing to your server's public IP"
    echo -e "    Example: n8n.yourdomain.com → 203.0.113.10"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🔑 Cloudflare API Setup (for SSL certificates)${NC}"
    echo -e "${BLUE}Required for automatic SSL certificate generation:${NC}"
    echo -e "  ${GREEN}1.${NC} Log in to Cloudflare Dashboard (https://dash.cloudflare.com)"
    echo -e "  ${GREEN}2.${NC} Go to 'My Profile' → 'API Tokens'"
    echo -e "  ${GREEN}3.${NC} Click 'Create Token' → 'Custom token'"
    echo -e "  ${GREEN}4.${NC} Configure token with these permissions:"
    echo -e "     • Zone:Zone:Read (for all zones)"
    echo -e "     • Zone:DNS:Edit (for specific zone or all zones)"
    echo -e "  ${GREEN}5.${NC} Copy the generated token (you'll need this during setup)"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🔌 Network & Port Configuration${NC}"
    echo -e "${BLUE}Ensure your server/router is configured for external access:${NC}"
    echo ""
    echo -e "${BLUE}For Traefik setup (recommended):${NC}"
    echo -e "  ${GREEN}✓${NC} Port 80 (HTTP) - open and forwarded to your server"
    echo -e "  ${GREEN}✓${NC} Port 443 (HTTPS) - open and forwarded to your server"
    echo -e "  ${YELLOW}⚠${NC} These ports are required for SSL certificate generation"
    echo ""
    echo -e "${BLUE}For localhost/development setup:${NC}"
    echo -e "  ${GREEN}✓${NC} Port 5678 (n8n) - accessible locally"
    echo -e "  ${GREEN}✓${NC} Additional ports for selected services (6333, 8080, 9000)"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🏠 Infrastructure Considerations${NC}"
    echo ""
    echo -e "${BLUE}Server Requirements:${NC}"
    echo -e "  ${GREEN}•${NC} Ubuntu 20.04+ or Debian 11+ (recommended)"
    echo -e "  ${GREEN}•${NC} Minimum 2GB RAM (4GB+ recommended for full stack)"
    echo -e "  ${GREEN}•${NC} 10GB+ free disk space"
    echo -e "  ${GREEN}•${NC} Stable internet connection"
    echo -e "  ${GREEN}•${NC} Root/sudo access for installation"
    echo ""
    echo -e "${BLUE}Raspberry Pi Specific:${NC}"
    echo -e "  ${GREEN}•${NC} Raspberry Pi 4 with 4GB+ RAM recommended"
    echo -e "  ${GREEN}•${NC} Use SSD instead of SD card for better performance"
    echo -e "  ${GREEN}•${NC} Ensure adequate cooling for continuous operation"
    echo -e "  ${GREEN}•${NC} Use Raspberry Pi OS (64-bit) or Ubuntu Server"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🔒 Security Preparations${NC}"
    echo -e "${BLUE}Before starting, consider these security aspects:${NC}"
    echo -e "  ${GREEN}•${NC} Choose strong passwords for all services"
    echo -e "  ${GREEN}•${NC} Consider using a VPN for additional security"
    echo -e "  ${GREEN}•${NC} Keep your server OS updated"
    echo -e "  ${GREEN}•${NC} Configure firewall rules appropriately"
    echo -e "  ${GREEN}•${NC} Regular backup strategy for your data"
    echo ""
    
    echo -e "${YELLOW}${BOLD}📊 Service-Specific Requirements${NC}"
    echo ""
    echo -e "${BLUE}PostgreSQL Database:${NC}"
    echo -e "  ${GREEN}•${NC} Additional 1GB+ RAM recommended"
    echo -e "  ${GREEN}•${NC} Consider backup strategy for database"
    echo ""
    echo -e "${BLUE}Qdrant Vector Database:${NC}"
    echo -e "  ${GREEN}•${NC} Additional storage for vector data"
    echo -e "  ${GREEN}•${NC} Consider persistent storage for production"
    echo ""
    echo -e "${BLUE}Monitoring (Portainer):${NC}"
    echo -e "  ${GREEN}•${NC} Additional 512MB RAM"
    echo -e "  ${GREEN}•${NC} Web browser access for management"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🌍 External Access Scenarios${NC}"
    echo ""
    echo -e "${BLUE}Home Server Setup (Raspberry Pi/Linux):${NC}"
    echo -e "  ${GREEN}1.${NC} Configure router port forwarding (80, 443 → server IP)"
    echo -e "  ${GREEN}2.${NC} Set up dynamic DNS if you don't have static IP"
    echo -e "  ${GREEN}3.${NC} Consider using Cloudflare proxy for additional security"
    echo -e "  ${GREEN}4.${NC} Ensure firewall allows required ports: sudo ufw allow 80,443/tcp"
    echo ""
    echo -e "${BLUE}VPS/Cloud Server (Ubuntu/Debian):${NC}"
    echo -e "  ${GREEN}1.${NC} Ensure firewall allows ports 80 and 443"
    echo -e "  ${GREEN}2.${NC} Configure security groups (AWS/GCP/Azure)"
    echo -e "  ${GREEN}3.${NC} Point domain DNS to server's public IP"
    echo -e "  ${GREEN}4.${NC} Update system: sudo apt update && sudo apt upgrade"
    echo ""
    echo -e "${BLUE}Local Development (Linux):${NC}"
    echo -e "  ${GREEN}1.${NC} No external access needed"
    echo -e "  ${GREEN}2.${NC} Access via localhost URLs"
    echo -e "  ${GREEN}3.${NC} Consider using ngrok for temporary external access"
    echo -e "  ${GREEN}4.${NC} Test with: curl http://localhost:5678"
    echo ""
    
    echo -e "${YELLOW}${BOLD}📋 Pre-Setup Checklist${NC}"
    echo -e "${BLUE}Before proceeding, ensure you have:${NC}"
    echo -e "  ${GREEN}☐${NC} Domain name (if using Traefik)"
    echo -e "  ${GREEN}☐${NC} Cloudflare API token (if using Cloudflare SSL)"
    echo -e "  ${GREEN}☐${NC} DNS records configured"
    echo -e "  ${GREEN}☐${NC} Ports 80/443 accessible (if using Traefik)"
    echo -e "  ${GREEN}☐${NC} Server meets minimum requirements"
    echo -e "  ${GREEN}☐${NC} Strong passwords prepared"
    echo -e "  ${GREEN}☐${NC} Backup strategy planned"
    echo ""
    
    echo -e "${YELLOW}${BOLD}🚨 Common Issues to Avoid${NC}"
    echo -e "  ${RED}✗${NC} Using weak passwords"
    echo -e "  ${RED}✗${NC} Forgetting to open firewall ports"
    echo -e "  ${RED}✗${NC} Not setting up DNS records before SSL generation"
    echo -e "  ${RED}✗${NC} Running on insufficient hardware"
    echo -e "  ${RED}✗${NC} Not planning for data persistence"
    echo ""
    
    echo -e "${BLUE}${BOLD}📚 Helpful Resources${NC}"
    echo -e "  ${BLUE}•${NC} Cloudflare API Tokens: https://developers.cloudflare.com/api/tokens/"
    echo -e "  ${BLUE}•${NC} n8n Documentation: https://docs.n8n.io/"
    echo -e "  ${BLUE}•${NC} Traefik Documentation: https://doc.traefik.io/traefik/"
    echo -e "  ${BLUE}•${NC} Docker Documentation: https://docs.docker.com/"
    echo ""
    
    read -p "Have you completed the necessary preparations? (Y/n): " preparations_ready
    if [[ $preparations_ready =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${YELLOW}Please complete the necessary preparations and run the setup again.${NC}"
        echo -e "${BLUE}You can run this script with --debug to test configuration without starting services.${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${GREEN}✔ Great! Let's proceed with the setup configuration.${NC}"
    echo ""
}

# Function to show quick setup options
show_quick_setup_options() {
    echo -e "${BLUE}${BOLD}=== Quick Setup Options ===${NC}"
    echo -e "${BLUE}Choose your setup approach:${NC}"
    echo ""
    echo -e "${GREEN}1. Full Guided Setup${NC}"
    echo -e "   → Complete infrastructure requirements review"
    echo -e "   → Service selection and configuration"
    echo -e "   → Best for first-time users"
    echo ""
    echo -e "${YELLOW}2. Quick Start (Skip Requirements)${NC}"
    echo -e "   → Skip infrastructure requirements review"
    echo -e "   → Go directly to service selection"
    echo -e "   → For experienced users who have prepared"
    echo ""
    echo -e "${BLUE}3. Debug Mode${NC}"
    echo -e "   → Generate configuration without starting services"
    echo -e "   → For testing and development"
    echo ""
    
    if [[ "$DEBUG_MODE" == true ]]; then
        echo -e "${YELLOW}Debug mode is already enabled.${NC}"
        return
    fi
    
    read -p "Choose option (1-3) [1]: " setup_option
    setup_option=${setup_option:-1}
    
    case $setup_option in
        1)
            show_infrastructure_requirements
            ;;
        2)
            echo -e "${YELLOW}Skipping infrastructure requirements review...${NC}"
            echo ""
            ;;
        3)
            echo -e "${BLUE}Switching to debug mode...${NC}"
            DEBUG_MODE=true
            echo ""
            ;;
        *)
            echo -e "${RED}Invalid option. Using full guided setup.${NC}"
            show_infrastructure_requirements
            ;;
    esac
}

# Show setup options
show_quick_setup_options

# Function to check if service is selected
is_service_selected() {
    local service=$1
    [[ " ${SELECTED_SERVICES[@]} " =~ " ${service} " ]]
}

# Function to add service to selection
add_service() {
    local service=$1
    if ! is_service_selected "$service"; then
        SELECTED_SERVICES+=("$service")
        echo -e "${GREEN}✔ Added $service${NC}"
        
        # Add dependencies
        if [[ -n "${SERVICE_DEPENDENCIES[$service]}" ]]; then
            local dep="${SERVICE_DEPENDENCIES[$service]}"
            if ! is_service_selected "$dep"; then
                echo -e "${YELLOW}  → Adding required dependency: $dep${NC}"
                add_service "$dep"
            fi
        fi
    fi
}

# Function to remove service from selection
remove_service() {
    local service=$1
    SELECTED_SERVICES=($(printf '%s\n' "${SELECTED_SERVICES[@]}" | grep -v "^$service$"))
    echo -e "${RED}✖ Removed $service${NC}"
    
    # Check if any selected services depend on this one
    for selected in "${SELECTED_SERVICES[@]}"; do
        if [[ "${SERVICE_DEPENDENCIES[$selected]}" == "$service" ]]; then
            echo -e "${YELLOW}  → Also removing $selected (depends on $service)${NC}"
            remove_service "$selected"
        fi
    done
}

# Function to display service selection menu
show_service_menu() {
    echo -e "${BLUE}${BOLD}=== Service Selection ===${NC}"
    echo -e "${BLUE}n8n (workflow automation) - ${GREEN}REQUIRED${NC}"
    echo ""
    echo -e "${BLUE}Optional Services:${NC}"
    
    local i=1
    for service in "${AVAILABLE_SERVICES[@]}"; do
        local status="☐"
        local color="${NC}"
        if is_service_selected "$service"; then
            status="☑"
            color="${GREEN}"
        fi
        echo -e "${color}$i. $status $service - ${SERVICE_DESCRIPTIONS[$service]}${NC}"
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${BOLD}1-${#AVAILABLE_SERVICES[@]}${NC} : Toggle service"
    echo -e "  ${BOLD}p${NC}     : Show preset configurations"
    echo -e "  ${BOLD}s${NC}     : Show current selection"
    echo -e "  ${BOLD}c${NC}     : Continue with current selection"
    echo -e "  ${BOLD}q${NC}     : Quit"
    echo ""
}

# Function to show preset configurations
show_presets() {
    echo -e "${BLUE}${BOLD}=== Preset Configurations ===${NC}"
    echo -e "${GREEN}1. Quick Start${NC} (Recommended)"
    echo -e "   → n8n + Traefik (SSL enabled, production ready)"
    echo ""
    echo -e "${BLUE}2. Minimal${NC}"
    echo -e "   → n8n only (localhost access, development)"
    echo ""
    echo -e "${YELLOW}3. AI/ML Stack${NC}"
    echo -e "   → n8n + Traefik + Qdrant (vector database for AI workflows)"
    echo ""
    echo -e "${BOLD}4. Full Stack${NC}"
    echo -e "   → All services (complete setup with monitoring)"
    echo ""
    echo -e "${BLUE}5. Database Enhanced${NC}"
    echo -e "   → n8n + Traefik + PostgreSQL (persistent data storage)"
    echo ""
    read -p "Select preset (1-5) or press Enter to return: " preset_choice
    
    case $preset_choice in
        1)
            SELECTED_SERVICES=("traefik")
            echo -e "${GREEN}✔ Applied Quick Start preset${NC}"
            ;;
        2)
            SELECTED_SERVICES=()
            echo -e "${GREEN}✔ Applied Minimal preset${NC}"
            ;;
        3)
            SELECTED_SERVICES=("traefik" "qdrant")
            echo -e "${GREEN}✔ Applied AI/ML Stack preset${NC}"
            ;;
        4)
            SELECTED_SERVICES=("${AVAILABLE_SERVICES[@]}")
            echo -e "${GREEN}✔ Applied Full Stack preset${NC}"
            ;;
        5)
            SELECTED_SERVICES=("traefik" "postgres")
            echo -e "${GREEN}✔ Applied Database Enhanced preset${NC}"
            ;;
        "")
            return
            ;;
        *)
            echo -e "${RED}Invalid preset selection${NC}"
            ;;
    esac
    echo ""
}

# Function to show current selection summary
show_selection_summary() {
    echo -e "${BLUE}${BOLD}=== Current Selection Summary ===${NC}"
    echo -e "${GREEN}✔ n8n (required)${NC}"
    
    if [ ${#SELECTED_SERVICES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No optional services selected${NC}"
        echo -e "${BLUE}Access: http://localhost:5678${NC}"
    else
        echo -e "${BLUE}Optional services:${NC}"
        for service in "${SELECTED_SERVICES[@]}"; do
            echo -e "${GREEN}✔ $service - ${SERVICE_DESCRIPTIONS[$service]}${NC}"
        done
        
        if is_service_selected "traefik"; then
            echo -e "${BLUE}Access: https://your-domain.com (SSL enabled)${NC}"
        else
            echo -e "${BLUE}Access: http://localhost:5678${NC}"
        fi
    fi
    echo ""
}

# Main service selection loop
service_selection_menu() {
    echo -e "${YELLOW}${BOLD}Choose which services you want to install with n8n:${NC}"
    echo ""
    
    while true; do
        show_service_menu
        read -p "Enter your choice: " choice
        
        case $choice in
            [1-9])
                if [ "$choice" -le "${#AVAILABLE_SERVICES[@]}" ]; then
                    local service="${AVAILABLE_SERVICES[$((choice-1))]}"
                    if is_service_selected "$service"; then
                        remove_service "$service"
                    else
                        add_service "$service"
                    fi
                else
                    echo -e "${RED}Invalid service number${NC}"
                fi
                echo ""
                ;;
            p|P)
                show_presets
                ;;
            s|S)
                show_selection_summary
                ;;
            c|C)
                show_selection_summary
                read -p "Continue with this selection? (Y/n): " confirm
                if [[ ! $confirm =~ ^[Nn]$ ]]; then
                    break
                fi
                ;;
            q|Q)
                echo -e "${YELLOW}Setup cancelled${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                echo ""
                ;;
        esac
    done
}

# Always run service selection (regardless of debug mode or setup option)
service_selection_menu

# Service-specific configuration variables
declare -A SERVICE_CONFIG

# Function to configure Traefik
configure_traefik() {
    echo -e "${BLUE}${BOLD}=== Traefik Configuration ===${NC}"
    echo -e "${BLUE}Traefik will provide reverse proxy and SSL certificates${NC}"
    echo ""
    
    # Domain configuration
    read -p "Enter your domain name (e.g., n8n.yourdomain.com): " domain
    while [[ -z "$domain" || "$domain" == "localhost" ]]; do
        echo -e "${RED}Please enter a valid domain name (not localhost)${NC}"
        read -p "Enter your domain name: " domain
    done
    SERVICE_CONFIG[WEBHOOK_URL]="$domain"
    
    # SSL Configuration
    echo -e "${BLUE}SSL Certificate Options:${NC}"
    echo "1. Cloudflare DNS Challenge (Recommended)"
    echo "2. HTTP Challenge (Port 80 must be accessible)"
    echo "3. Manual certificates (Advanced)"
    read -p "Choose SSL method (1-3) [1]: " ssl_method
    ssl_method=${ssl_method:-1}
    
    case $ssl_method in
        1)
            SERVICE_CONFIG[SSL_METHOD]="cloudflare"
            read -p "Enter your Cloudflare DNS API Token: " cf_token
            while [[ -z "$cf_token" ]]; do
                echo -e "${RED}Cloudflare API token is required for DNS challenge${NC}"
                read -p "Enter your Cloudflare DNS API Token: " cf_token
            done
            SERVICE_CONFIG[CF_DNS_API_TOKEN]="$cf_token"
            ;;
        2)
            SERVICE_CONFIG[SSL_METHOD]="http"
            echo -e "${YELLOW}Note: Port 80 must be accessible from the internet${NC}"
            ;;
        3)
            SERVICE_CONFIG[SSL_METHOD]="manual"
            echo -e "${YELLOW}You'll need to provide certificates manually${NC}"
            ;;
    esac
    
    # Certificate email
    read -p "Enter email for Let's Encrypt notifications: " cert_email
    while [[ -z "$cert_email" || ! "$cert_email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; do
        echo -e "${RED}Please enter a valid email address${NC}"
        read -p "Enter email for Let's Encrypt notifications: " cert_email
    done
    SERVICE_CONFIG[CERTIFICATE_EMAIL]="$cert_email"
    
    # Ports
    read -p "HTTP Port [80]: " http_port
    SERVICE_CONFIG[HTTP_PORT]="${http_port:-80}"
    
    read -p "HTTPS Port [443]: " https_port
    SERVICE_CONFIG[HTTPS_PORT]="${https_port:-443}"
    
    echo -e "${GREEN}✔ Traefik configuration completed${NC}"
    echo ""
}

# Function to configure Qdrant
configure_qdrant() {
    echo -e "${BLUE}${BOLD}=== Qdrant Configuration ===${NC}"
    echo -e "${BLUE}Qdrant is a vector database for AI/ML workflows${NC}"
    echo ""
    
    # Storage configuration
    echo -e "${BLUE}Storage Options:${NC}"
    echo "1. Persistent storage (Recommended for production)"
    echo "2. In-memory storage (Faster, data lost on restart)"
    read -p "Choose storage type (1-2) [1]: " storage_type
    storage_type=${storage_type:-1}
    
    if [ "$storage_type" = "1" ]; then
        SERVICE_CONFIG[QDRANT_STORAGE]="persistent"
        read -p "Storage path [./qdrant_data]: " storage_path
        SERVICE_CONFIG[QDRANT_STORAGE_PATH]="${storage_path:-./qdrant_data}"
    else
        SERVICE_CONFIG[QDRANT_STORAGE]="memory"
    fi
    
    # Dashboard exposure
    read -p "Expose Qdrant dashboard? (Y/n): " expose_dashboard
    if [[ ! $expose_dashboard =~ ^[Nn]$ ]]; then
        SERVICE_CONFIG[QDRANT_DASHBOARD]="true"
        if is_service_selected "traefik"; then
            read -p "Dashboard subdomain [qdrant]: " dashboard_subdomain
            dashboard_subdomain=${dashboard_subdomain:-qdrant}
            SERVICE_CONFIG[QDRANT_SUBDOMAIN]="$dashboard_subdomain"
        else
            read -p "Dashboard port [6333]: " dashboard_port
            SERVICE_CONFIG[QDRANT_PORT]="${dashboard_port:-6333}"
        fi
    else
        SERVICE_CONFIG[QDRANT_DASHBOARD]="false"
    fi
    
    # API configuration
    read -p "Enable Qdrant API key protection? (y/N): " enable_api_key
    if [[ $enable_api_key =~ ^[Yy]$ ]]; then
        read -p "Enter API key (or press Enter to generate): " api_key
        if [[ -z "$api_key" ]]; then
            api_key=$(openssl rand -hex 32)
            echo -e "${GREEN}Generated API key: $api_key${NC}"
        fi
        SERVICE_CONFIG[QDRANT_API_KEY]="$api_key"
    fi
    
    echo -e "${GREEN}✔ Qdrant configuration completed${NC}"
    echo ""
}

# Function to configure Nginx
configure_nginx() {
    echo -e "${BLUE}${BOLD}=== Nginx Configuration ===${NC}"
    echo -e "${BLUE}Nginx can serve static files and provide additional routing${NC}"
    echo ""
    
    # Purpose configuration
    echo -e "${BLUE}Nginx Usage:${NC}"
    echo "1. Static file server (Default)"
    echo "2. Additional reverse proxy"
    echo "3. Custom configuration"
    read -p "Choose Nginx purpose (1-3) [1]: " nginx_purpose
    nginx_purpose=${nginx_purpose:-1}
    
    case $nginx_purpose in
        1)
            SERVICE_CONFIG[NGINX_PURPOSE]="static"
            read -p "Static files directory [./static]: " static_dir
            SERVICE_CONFIG[NGINX_STATIC_DIR]="${static_dir:-./static}"
            ;;
        2)
            SERVICE_CONFIG[NGINX_PURPOSE]="proxy"
            read -p "Upstream server (e.g., http://app:3000): " upstream
            SERVICE_CONFIG[NGINX_UPSTREAM]="$upstream"
            ;;
        3)
            SERVICE_CONFIG[NGINX_PURPOSE]="custom"
            read -p "Custom nginx.conf path [./nginx.conf]: " nginx_conf
            SERVICE_CONFIG[NGINX_CONF_PATH]="${nginx_conf:-./nginx.conf}"
            ;;
    esac
    
    # Port configuration
    if ! is_service_selected "traefik"; then
        read -p "Nginx port [8080]: " nginx_port
        SERVICE_CONFIG[NGINX_PORT]="${nginx_port:-8080}"
    else
        read -p "Nginx subdomain [files]: " nginx_subdomain
        SERVICE_CONFIG[NGINX_SUBDOMAIN]="${nginx_subdomain:-files}"
    fi
    
    echo -e "${GREEN}✔ Nginx configuration completed${NC}"
    echo ""
}

# Function to configure PostgreSQL
configure_postgres() {
    echo -e "${BLUE}${BOLD}=== PostgreSQL Configuration ===${NC}"
    echo -e "${BLUE}PostgreSQL will provide persistent data storage for n8n${NC}"
    echo ""
    
    # Database credentials
    read -p "Database name [n8n]: " db_name
    SERVICE_CONFIG[POSTGRES_DB]="${db_name:-n8n}"
    
    read -p "Database user [n8n]: " db_user
    SERVICE_CONFIG[POSTGRES_USER]="${db_user:-n8n}"
    
    read -p "Database password (or press Enter to generate): " db_password
    if [[ -z "$db_password" ]]; then
        db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        echo -e "${GREEN}Generated password: $db_password${NC}"
    fi
    SERVICE_CONFIG[POSTGRES_PASSWORD]="$db_password"
    
    # Storage configuration
    read -p "Database storage path [./postgres_data]: " db_storage
    SERVICE_CONFIG[POSTGRES_STORAGE_PATH]="${db_storage:-./postgres_data}"
    
    # Admin access
    if is_service_selected "traefik"; then
        read -p "Enable pgAdmin web interface? (y/N): " enable_pgadmin
        if [[ $enable_pgadmin =~ ^[Yy]$ ]]; then
            SERVICE_CONFIG[PGADMIN_ENABLED]="true"
            read -p "pgAdmin email: " pgadmin_email
            SERVICE_CONFIG[PGADMIN_EMAIL]="$pgadmin_email"
            read -p "pgAdmin password: " pgadmin_password
            SERVICE_CONFIG[PGADMIN_PASSWORD]="$pgadmin_password"
            read -p "pgAdmin subdomain [pgadmin]: " pgadmin_subdomain
            SERVICE_CONFIG[PGADMIN_SUBDOMAIN]="${pgadmin_subdomain:-pgadmin}"
        fi
    fi
    
    echo -e "${GREEN}✔ PostgreSQL configuration completed${NC}"
    echo ""
}

# Function to configure Monitoring
configure_monitoring() {
    echo -e "${BLUE}${BOLD}=== Monitoring Configuration ===${NC}"
    echo -e "${BLUE}Portainer provides a web UI for Docker container management${NC}"
    echo ""
    
    # Admin credentials
    read -p "Portainer admin username [admin]: " portainer_user
    SERVICE_CONFIG[PORTAINER_USER]="${portainer_user:-admin}"
    
    read -p "Portainer admin password: " portainer_password
    while [[ -z "$portainer_password" ]]; do
        echo -e "${RED}Password is required for Portainer${NC}"
        read -p "Portainer admin password: " portainer_password
    done
    SERVICE_CONFIG[PORTAINER_PASSWORD]="$portainer_password"
    
    # Access configuration
    if is_service_selected "traefik"; then
        read -p "Portainer subdomain [portainer]: " portainer_subdomain
        SERVICE_CONFIG[PORTAINER_SUBDOMAIN]="${portainer_subdomain:-portainer}"
    else
        read -p "Portainer port [9000]: " portainer_port
        SERVICE_CONFIG[PORTAINER_PORT]="${portainer_port:-9000}"
    fi
    
    # Additional monitoring
    read -p "Enable Docker socket proxy for security? (Y/n): " enable_socket_proxy
    if [[ ! $enable_socket_proxy =~ ^[Nn]$ ]]; then
        SERVICE_CONFIG[SOCKET_PROXY_ENABLED]="true"
    fi
    
    echo -e "${GREEN}✔ Monitoring configuration completed${NC}"
    echo ""
}

# Function to configure n8n (always required)
configure_n8n() {
    echo -e "${BLUE}${BOLD}=== n8n Configuration ===${NC}"
    echo -e "${BLUE}Core n8n workflow automation settings${NC}"
    echo ""
    
    # Authentication
    read -p "n8n admin username [admin]: " n8n_user
    SERVICE_CONFIG[N8N_BASIC_AUTH_USER]="${n8n_user:-admin}"
    
    read -p "n8n admin password: " n8n_password
    while [[ -z "$n8n_password" ]]; do
        echo -e "${RED}Password is required for n8n${NC}"
        read -p "n8n admin password: " n8n_password
    done
    SERVICE_CONFIG[N8N_BASIC_AUTH_PASSWORD]="$n8n_password"
    
    # Webhook URL (if not set by Traefik)
    if [[ -z "${SERVICE_CONFIG[WEBHOOK_URL]}" ]]; then
        SERVICE_CONFIG[WEBHOOK_URL]="localhost:5678"
        echo -e "${BLUE}n8n will be accessible at: http://localhost:5678${NC}"
    fi
    
    # Advanced settings
    read -p "Enable n8n community packages? (Y/n): " enable_community
    if [[ ! $enable_community =~ ^[Nn]$ ]]; then
        SERVICE_CONFIG[N8N_COMMUNITY_PACKAGES]="true"
    fi
    
    read -p "Enable n8n folders feature? (Y/n): " enable_folders
    if [[ ! $enable_folders =~ ^[Nn]$ ]]; then
        SERVICE_CONFIG[N8N_FOLDERS_ENABLED]="true"
    fi
    
    # Database connection (if PostgreSQL is selected)
    if is_service_selected "postgres"; then
        SERVICE_CONFIG[N8N_DATABASE_TYPE]="postgresdb"
        SERVICE_CONFIG[N8N_DATABASE_HOST]="postgres"
        SERVICE_CONFIG[N8N_DATABASE_PORT]="5432"
        SERVICE_CONFIG[N8N_DATABASE_NAME]="${SERVICE_CONFIG[POSTGRES_DB]}"
        SERVICE_CONFIG[N8N_DATABASE_USER]="${SERVICE_CONFIG[POSTGRES_USER]}"
        SERVICE_CONFIG[N8N_DATABASE_PASSWORD]="${SERVICE_CONFIG[POSTGRES_PASSWORD]}"
        echo -e "${GREEN}✔ n8n will use PostgreSQL database${NC}"
    else
        SERVICE_CONFIG[N8N_DATABASE_TYPE]="sqlite"
        echo -e "${BLUE}n8n will use SQLite database (file-based)${NC}"
    fi
    
    echo -e "${GREEN}✔ n8n configuration completed${NC}"
    echo ""
}

# Main configuration function
configure_services() {
    echo -e "${BLUE}${BOLD}=== Service Configuration ===${NC}"
    echo -e "${BLUE}Now let's configure each selected service...${NC}"
    echo ""
    
    # Always configure n8n first
    configure_n8n
    
    # Configure selected services
    for service in "${SELECTED_SERVICES[@]}"; do
        case $service in
            traefik)
                configure_traefik
                ;;
            qdrant)
                configure_qdrant
                ;;
            nginx)
                configure_nginx
                ;;
            postgres)
                configure_postgres
                ;;
            monitoring)
                configure_monitoring
                ;;
        esac
    done
    
    # Show configuration summary
    echo -e "${BLUE}${BOLD}=== Configuration Summary ===${NC}"
    echo -e "${GREEN}✔ n8n: ${SERVICE_CONFIG[WEBHOOK_URL]}${NC}"
    for service in "${SELECTED_SERVICES[@]}"; do
        echo -e "${GREEN}✔ $service: configured${NC}"
    done
    echo ""
    
    read -p "Proceed with this configuration? (Y/n): " confirm_config
    if [[ $confirm_config =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Configuration cancelled. Returning to service selection...${NC}"
        service_selection_menu
        configure_services
    fi
}

# Run service configuration
configure_services

# Function to generate environment file
generate_env_file() {
    echo -e "${BLUE}Generating .env file...${NC}"
    
    cat > .env << EOF
# =============================================================================
# N8N + Services Setup - Environment Variables
# =============================================================================
# Generated by setup.sh on $(date)
# =============================================================================

# Core n8n Configuration
N8N_BASIC_AUTH_USER=${SERVICE_CONFIG[N8N_BASIC_AUTH_USER]}
N8N_BASIC_AUTH_PASSWORD=${SERVICE_CONFIG[N8N_BASIC_AUTH_PASSWORD]}
WEBHOOK_URL=${SERVICE_CONFIG[WEBHOOK_URL]}
N8N_COMMUNITY_PACKAGES=${SERVICE_CONFIG[N8N_COMMUNITY_PACKAGES]:-true}
N8N_FOLDERS_ENABLED=${SERVICE_CONFIG[N8N_FOLDERS_ENABLED]:-true}
N8N_DATABASE_TYPE=${SERVICE_CONFIG[N8N_DATABASE_TYPE]:-sqlite}

EOF

    # Add Traefik configuration if selected
    if is_service_selected "traefik"; then
        cat >> .env << EOF
# Traefik Configuration
HTTP_PORT=${SERVICE_CONFIG[HTTP_PORT]:-80}
HTTPS_PORT=${SERVICE_CONFIG[HTTPS_PORT]:-443}
CERTIFICATE_EMAIL=${SERVICE_CONFIG[CERTIFICATE_EMAIL]}
CF_DNS_API_TOKEN=${SERVICE_CONFIG[CF_DNS_API_TOKEN]}
SSL_METHOD=${SERVICE_CONFIG[SSL_METHOD]:-cloudflare}
TRAEFIK_DASHBOARD_AUTH=${SERVICE_CONFIG[TRAEFIK_DASHBOARD_AUTH]}

EOF
    fi

    # Add PostgreSQL configuration if selected
    if is_service_selected "postgres"; then
        cat >> .env << EOF
# PostgreSQL Configuration
POSTGRES_DB=${SERVICE_CONFIG[POSTGRES_DB]:-n8n}
POSTGRES_USER=${SERVICE_CONFIG[POSTGRES_USER]:-n8n}
POSTGRES_PASSWORD=${SERVICE_CONFIG[POSTGRES_PASSWORD]}

EOF
    fi

    # Add Qdrant configuration if selected
    if is_service_selected "qdrant"; then
        cat >> .env << EOF
# Qdrant Configuration
QDRANT_STORAGE=${SERVICE_CONFIG[QDRANT_STORAGE]:-persistent}
QDRANT_STORAGE_PATH=${SERVICE_CONFIG[QDRANT_STORAGE_PATH]:-./qdrant_data}
QDRANT_DASHBOARD=${SERVICE_CONFIG[QDRANT_DASHBOARD]:-true}
QDRANT_PORT=${SERVICE_CONFIG[QDRANT_PORT]:-6333}
QDRANT_SUBDOMAIN=${SERVICE_CONFIG[QDRANT_SUBDOMAIN]:-qdrant}
QDRANT_API_KEY=${SERVICE_CONFIG[QDRANT_API_KEY]}

EOF
    fi

    # Add Nginx configuration if selected
    if is_service_selected "nginx"; then
        cat >> .env << EOF
# Nginx Configuration
NGINX_PURPOSE=${SERVICE_CONFIG[NGINX_PURPOSE]:-static}
NGINX_STATIC_DIR=${SERVICE_CONFIG[NGINX_STATIC_DIR]:-./static}
NGINX_PORT=${SERVICE_CONFIG[NGINX_PORT]:-8080}
NGINX_SUBDOMAIN=${SERVICE_CONFIG[NGINX_SUBDOMAIN]:-files}
NGINX_UPSTREAM=${SERVICE_CONFIG[NGINX_UPSTREAM]}

EOF
    fi

    # Add Monitoring configuration if selected
    if is_service_selected "monitoring"; then
        cat >> .env << EOF
# Monitoring Configuration
PORTAINER_USER=${SERVICE_CONFIG[PORTAINER_USER]:-admin}
PORTAINER_PASSWORD=${SERVICE_CONFIG[PORTAINER_PASSWORD]}
PORTAINER_PORT=${SERVICE_CONFIG[PORTAINER_PORT]:-9000}
PORTAINER_SUBDOMAIN=${SERVICE_CONFIG[PORTAINER_SUBDOMAIN]:-portainer}
SOCKET_PROXY_ENABLED=${SERVICE_CONFIG[SOCKET_PROXY_ENABLED]:-false}

EOF
    fi

    echo -e "${GREEN}✔ .env file generated successfully${NC}"
}

# Function to merge YAML files
merge_yaml_files() {
    local output_file="$1"
    shift
    local input_files=("$@")
    
    # Start with base template
    cp templates/base.yml "$output_file"
    
    # Process each additional template
    for template in "${input_files[@]}"; do
        if [[ -f "templates/${template}.yml" ]]; then
            echo -e "${BLUE}  → Adding $template configuration...${NC}"
            
            # Use yq to merge if available, otherwise use simple concatenation
            if command -v yq &> /dev/null; then
                yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$output_file" "templates/${template}.yml" > temp_compose.yml
                mv temp_compose.yml "$output_file"
            else
                # Simple merge by appending services (less sophisticated but works)
                echo "" >> "$output_file"
                echo "# === $template configuration ===" >> "$output_file"
                tail -n +2 "templates/${template}.yml" >> "$output_file"
            fi
        fi
    done
}

# Function to apply service-specific configurations
apply_service_configurations() {
    local compose_file="$1"
    
    # Apply Traefik-specific configurations
    if is_service_selected "traefik"; then
        # Generate Traefik dashboard auth
        local auth_string=$(echo -n "${SERVICE_CONFIG[N8N_BASIC_AUTH_USER]}:${SERVICE_CONFIG[N8N_BASIC_AUTH_PASSWORD]}" | openssl passwd -apr1 -stdin)
        SERVICE_CONFIG[TRAEFIK_DASHBOARD_AUTH]="$auth_string"
        
        # Configure SSL method
        case "${SERVICE_CONFIG[SSL_METHOD]}" in
            "cloudflare")
                sed -i.bak 's/--certificatesresolvers.myresolver.acme.storage/--certificatesresolvers.myresolver.acme.dnschallenge=true\n      - "--certificatesresolvers.myresolver.acme.dnschallenge.provider=cloudflare"\n      - "--certificatesresolvers.myresolver.acme.dnschallenge.resolvers=1.1.1.1:53"\n      - "--certificatesresolvers.myresolver.acme.storage/' "$compose_file"
                ;;
            "http")
                sed -i.bak 's/--certificatesresolvers.myresolver.acme.storage/--certificatesresolvers.myresolver.acme.httpchallenge=true\n      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"\n      - "--certificatesresolvers.myresolver.acme.storage/' "$compose_file"
                ;;
        esac
    fi
    
    # Apply Qdrant-specific configurations
    if is_service_selected "qdrant"; then
        # Add storage configuration
        if [[ "${SERVICE_CONFIG[QDRANT_STORAGE]}" == "persistent" ]]; then
            # Add volume mount for persistent storage
            sed -i.bak '/qdrant:/a\
    volumes:\
      - qdrant_data:/qdrant/storage' "$compose_file"
            
            # Add volume definition
            echo "" >> "$compose_file"
            echo "volumes:" >> "$compose_file"
            echo "  qdrant_data:" >> "$compose_file"
            echo "    driver: local" >> "$compose_file"
        fi
        
        # Add API key if configured
        if [[ -n "${SERVICE_CONFIG[QDRANT_API_KEY]}" ]]; then
            sed -i.bak '/QDRANT__SERVICE__GRPC_PORT/a\
      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}' "$compose_file"
        fi
        
        # Add dashboard configuration
        if [[ "${SERVICE_CONFIG[QDRANT_DASHBOARD]}" == "true" ]]; then
            if is_service_selected "traefik"; then
                # Add Traefik labels for subdomain access
                sed -i.bak '/qdrant:/a\
    labels:\
      - "traefik.enable=true"\
      - "traefik.http.routers.qdrant.rule=Host(`${QDRANT_SUBDOMAIN}.${WEBHOOK_URL}`)"\
      - "traefik.http.routers.qdrant.entrypoints=websecure"\
      - "traefik.http.routers.qdrant.tls.certresolver=myresolver"\
      - "traefik.http.services.qdrant.loadbalancer.server.port=6333"' "$compose_file"
            else
                # Add port mapping for direct access
                sed -i.bak '/qdrant:/a\
    ports:\
      - "${QDRANT_PORT:-6333}:6333"' "$compose_file"
            fi
        fi
    fi
    
    # Apply Nginx-specific configurations
    if is_service_selected "nginx"; then
        if is_service_selected "traefik"; then
            # Add Traefik labels for subdomain access
            sed -i.bak '/nginx:/a\
    labels:\
      - "traefik.enable=true"\
      - "traefik.http.routers.nginx.rule=Host(`${NGINX_SUBDOMAIN}.${WEBHOOK_URL}`)"\
      - "traefik.http.routers.nginx.entrypoints=websecure"\
      - "traefik.http.routers.nginx.tls.certresolver=myresolver"\
      - "traefik.http.services.nginx.loadbalancer.server.port=80"' "$compose_file"
        else
            # Add port mapping for direct access
            sed -i.bak '/nginx:/a\
    ports:\
      - "${NGINX_PORT:-8080}:80"' "$compose_file"
        fi
    fi
    
    # Apply Monitoring-specific configurations
    if is_service_selected "monitoring"; then
        if is_service_selected "traefik"; then
            # Add Traefik labels for subdomain access
            sed -i.bak '/portainer:/a\
    labels:\
      - "traefik.enable=true"\
      - "traefik.http.routers.portainer.rule=Host(`${PORTAINER_SUBDOMAIN}.${WEBHOOK_URL}`)"\
      - "traefik.http.routers.portainer.entrypoints=websecure"\
      - "traefik.http.routers.portainer.tls.certresolver=myresolver"\
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"' "$compose_file"
        else
            # Add port mapping for direct access
            sed -i.bak '/portainer:/a\
    ports:\
      - "${PORTAINER_PORT:-9000}:9000"' "$compose_file"
        fi
    fi
    
    # Clean up backup files
    rm -f "${compose_file}.bak"
}

# Function to generate docker-compose.yml
generate_docker_compose() {
    echo -e "${BLUE}${BOLD}=== Generating Docker Compose Configuration ===${NC}"
    
    # Create backup if file exists
    if [[ -f "docker-compose.yml" ]]; then
        echo -e "${YELLOW}Creating backup of existing docker-compose.yml...${NC}"
        cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    echo -e "${BLUE}Building docker-compose.yml with selected services...${NC}"
    
    # Merge templates based on selected services
    merge_yaml_files "docker-compose.yml" "${SELECTED_SERVICES[@]}"
    
    # Apply service-specific configurations
    apply_service_configurations "docker-compose.yml"
    
    echo -e "${GREEN}✔ docker-compose.yml generated successfully${NC}"
    echo ""
    
    # Show services summary
    echo -e "${BLUE}Services included:${NC}"
    echo -e "${GREEN}✔ n8n (workflow automation)${NC}"
    for service in "${SELECTED_SERVICES[@]}"; do
        echo -e "${GREEN}✔ $service${NC}"
    done
    echo ""
}

# Generate configuration files
generate_env_file
generate_docker_compose

# Step 1: Check for required files
echo -e "${BLUE}Checking for required template files...${NC}"
if [ ! -f ".env.example" ]; then
    echo -e "${RED}Error: .env.example file not found. Please ensure it exists in the project directory.${NC}"
    exit 1
fi

if [ ! -f "docker-compose.template.yml" ]; then
    echo -e "${RED}Error: docker-compose.template.yml file not found. Please ensure it exists in the project directory.${NC}"
    exit 1
fi

# Step 2: Ensure letsencrypt/acme.json exists with correct permissions
echo -e "${BLUE}Preparing letsencrypt/acme.json...${NC}"
mkdir -p letsencrypt
if [ ! -f letsencrypt/acme.json ]; then
    touch letsencrypt/acme.json
fi
chmod 600 letsencrypt/acme.json
echo -e "${GREEN}✔ letsencrypt/acme.json is ready.${NC}"

# Step 3: Validate configuration
echo -e "${BLUE}Validating configuration...${NC}"
if is_service_selected "traefik"; then
    if [ -z "${SERVICE_CONFIG[CERTIFICATE_EMAIL]}" ] || [ "${SERVICE_CONFIG[CERTIFICATE_EMAIL]}" = "your-email@example.com" ]; then
        echo -e "${RED}✖ Please provide a valid certificate email address.${NC}"
        exit 1
    fi

    if [[ "${SERVICE_CONFIG[SSL_METHOD]}" == "cloudflare" ]]; then
        if [ -z "${SERVICE_CONFIG[CF_DNS_API_TOKEN]}" ] || [ "${SERVICE_CONFIG[CF_DNS_API_TOKEN]}" = "your-cloudflare-api-token-here" ]; then
            echo -e "${RED}✖ Please provide a valid Cloudflare DNS API token.${NC}"
            exit 1
        fi
    fi

    if [ -z "${SERVICE_CONFIG[WEBHOOK_URL]}" ] || [ "${SERVICE_CONFIG[WEBHOOK_URL]}" = "n8n.yourdomain.com" ]; then
        echo -e "${RED}✖ Please provide a valid webhook URL (domain name).${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✔ Configuration validation passed.${NC}"

# Step 4: Start services with Docker Compose
if [ "$DEBUG_MODE" = true ]; then
    echo -e "${BLUE}${BOLD}=== DEBUG MODE - CONFIGURATION SUMMARY ===${NC}"
    echo -e "${BLUE}Generated files:${NC}"
    echo -e "  ✔ .env"
    echo -e "  ✔ docker-compose.yml"
    echo ""
    echo -e "${BLUE}Configuration values:${NC}"
    echo -e "  WEBHOOK_URL: ${SERVICE_CONFIG[WEBHOOK_URL]}"
    echo -e "  N8N_BASIC_AUTH_USER: ${SERVICE_CONFIG[N8N_BASIC_AUTH_USER]}"
    if is_service_selected "traefik"; then
        echo -e "  HTTP_PORT: ${SERVICE_CONFIG[HTTP_PORT]}"
        echo -e "  HTTPS_PORT: ${SERVICE_CONFIG[HTTPS_PORT]}"
        echo -e "  CERTIFICATE_EMAIL: ${SERVICE_CONFIG[CERTIFICATE_EMAIL]}"
        echo -e "  SSL_METHOD: ${SERVICE_CONFIG[SSL_METHOD]}"
    fi
    echo ""
    echo -e "${BLUE}Selected services:${NC}"
    echo -e "  • n8n (workflow automation)"
    for service in "${SELECTED_SERVICES[@]}"; do
        case $service in
            traefik) echo -e "  • traefik (reverse proxy & SSL)" ;;
            qdrant) echo -e "  • qdrant (vector database)" ;;
            nginx) echo -e "  • nginx (web server)" ;;
            postgres) echo -e "  • postgres (database)" ;;
            monitoring) echo -e "  • portainer (monitoring)" ;;
        esac
    done
    echo ""
    echo -e "${YELLOW}To actually start the services, run:${NC}"
    echo -e "  ${BOLD}${DOCKER_COMPOSE_CMD:-docker compose} up -d${NC}"
    echo ""
    echo -e "${YELLOW}To view the generated docker-compose.yml:${NC}"
    echo -e "  ${BOLD}cat docker-compose.yml${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}✔ Debug mode completed successfully!${NC}"
else
    echo -e "${BLUE}Starting Docker Compose stack...${NC}"
    echo -e "${YELLOW}This may take a few minutes to download images and start services...${NC}"
    
    docker_result=0
    ${DOCKER_COMPOSE_CMD:-docker compose} up -d || docker_result=$?
    
    if [ $docker_result -eq 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}✔ All services are up and running!${NC}"
        
        # Show access information based on configuration
        if is_service_selected "traefik"; then
            echo -e "${GREEN}🌐 Access n8n at: https://${SERVICE_CONFIG[WEBHOOK_URL]}${NC}"
            
            # Show additional service URLs
            if is_service_selected "qdrant" && [[ "${SERVICE_CONFIG[QDRANT_DASHBOARD]}" == "true" ]]; then
                echo -e "${BLUE}📊 Qdrant dashboard: https://${SERVICE_CONFIG[QDRANT_SUBDOMAIN]}.${SERVICE_CONFIG[WEBHOOK_URL]}${NC}"
            fi
            
            if is_service_selected "nginx"; then
                echo -e "${BLUE}📁 Nginx files: https://${SERVICE_CONFIG[NGINX_SUBDOMAIN]}.${SERVICE_CONFIG[WEBHOOK_URL]}${NC}"
            fi
            
            if is_service_selected "monitoring"; then
                echo -e "${BLUE}🔧 Portainer: https://${SERVICE_CONFIG[PORTAINER_SUBDOMAIN]}.${SERVICE_CONFIG[WEBHOOK_URL]}${NC}"
            fi
            
            echo -e "${BLUE}🔒 Traefik dashboard: https://${SERVICE_CONFIG[WEBHOOK_URL]}/dashboard/${NC}"
        else
            echo -e "${GREEN}🌐 Access n8n at: http://localhost:5678${NC}"
            
            # Show port-based access for other services
            if is_service_selected "qdrant" && [[ "${SERVICE_CONFIG[QDRANT_DASHBOARD]}" == "true" ]]; then
                echo -e "${BLUE}📊 Qdrant dashboard: http://localhost:${SERVICE_CONFIG[QDRANT_PORT]:-6333}${NC}"
            fi
            
            if is_service_selected "nginx"; then
                echo -e "${BLUE}📁 Nginx: http://localhost:${SERVICE_CONFIG[NGINX_PORT]:-8080}${NC}"
            fi
            
            if is_service_selected "monitoring"; then
                echo -e "${BLUE}🔧 Portainer: http://localhost:${SERVICE_CONFIG[PORTAINER_PORT]:-9000}${NC}"
            fi
        fi
        
        echo ""
        echo -e "${YELLOW}Note: It may take a few minutes for SSL certificates to be generated.${NC}"
        echo -e "${YELLOW}Check logs with: ${DOCKER_COMPOSE_CMD:-docker compose} logs -f${NC}"
    else
        echo -e "${RED}✖ Something went wrong. Please check docker logs.${NC}"
        echo -e "${YELLOW}Debug with: ${DOCKER_COMPOSE_CMD:-docker compose} logs${NC}"
        exit 1
    fi
fi