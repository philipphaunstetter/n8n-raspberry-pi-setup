#!/bin/bash

# Enhanced setup script with tool-like output formatting
# This is a demonstration of how to integrate the new formatting into setup.sh

# Load enhanced CLI functions
source cli-enhancements.sh

echo -e "${BLUE}${BOLD}=== n8n Setup with Enhanced Logging ===${NC}"

# Example of how to modify the setup process with tool-like output
enhanced_setup_demo() {
    section_header "Enhanced Setup Process"
    
    # System checks with tool-like output
    setup_step "check_system" "Detect operating system and package manager"
    echo -e "     Detected: macOS (Darwin 24.5.0)"
    echo -e "     Package manager: brew"
    
    # Dependency checking
    docker_step "docker info" "Verify Docker daemon status"
    echo -e "     Docker daemon is running"
    echo -e "     Docker version 24.0.6, build ed223bc"
    
    run_command "docker compose version" "Check Docker Compose availability"
    
    # Configuration generation
    tool_step "Read" "Load service templates" "templates/base.yml"
    tool_step "Read" "Load traefik template" "templates/traefik.yml"
    
    setup_step "generate_env" "Create environment configuration"
    echo -e "     N8N_BASIC_AUTH_USER=admin"
    echo -e "     WEBHOOK_URL=n8n.yourdomain.com"
    echo -e "     CF_DNS_API_TOKEN=****"
    
    tool_step "Write" "Generate docker-compose.yml" "docker-compose.yml"
    echo -e "     Services: n8n, traefik"
    echo -e "     Networks: n8n-network"
    echo -e "     Volumes: n8n_data"
    
    # Service startup
    run_command "docker compose up -d" "Start services"
    
    success "Setup completed successfully!"
    info "Services are now running"
    
    echo -e "\n${GREEN}${ROCKET} Access your n8n instance at: https://n8n.yourdomain.com${NC}"
}

# Run the demo
enhanced_setup_demo