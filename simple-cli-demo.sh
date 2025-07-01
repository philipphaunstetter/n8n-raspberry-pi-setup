#!/bin/bash

# Simple CLI demo with enhanced formatting
source cli-enhancements.sh

echo -e "\n${BLUE}${BOLD}=== Enhanced CLI Demo ===${NC}"

section_header "n8n Setup Progress"

# Tool-like step formatting (Claude Code style)
setup_step "check_dependencies" "Verify system requirements"
docker_step "docker --version" "Check Docker installation"
echo -e "     Docker version 24.0.6, build ed223bc"

run_command "docker compose version" "Check Docker Compose version"

tool_step "Read" "Check configuration file" "/Users/user/setup.sh"

setup_step "generate_config" "Create environment configuration"
echo -e "     Generated .env with 15 variables"
echo -e "     Generated docker-compose.yml with 3 services"

# Traditional status messages
echo
success "Configuration generated successfully!"
error "This is how an error would look"
warning "This is a warning message"
info "This is an informational message"

echo -e "\n${CYAN}${BOLD}┌─────────────────────────────────┐${NC}"
echo -e "${CYAN}${BOLD}│${NC} ${WHITE}${BOLD}Setup Complete!${NC}              ${CYAN}${BOLD}│${NC}"
echo -e "${CYAN}${BOLD}└─────────────────────────────────┘${NC}"

echo -e "\n${GREEN}${ROCKET} Your n8n setup is ready!${NC}"
echo -e "${BLUE}${ARROW} Access: https://your-domain.com${NC}"