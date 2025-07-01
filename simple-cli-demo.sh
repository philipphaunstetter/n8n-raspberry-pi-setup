#!/bin/bash

# Simple CLI demo with enhanced formatting
source cli-enhancements.sh

echo -e "\n${BLUE}${BOLD}=== Enhanced CLI Demo ===${NC}"

section_header "n8n Setup Progress"

info "Initializing setup..."
step "Checking system requirements"
success "Docker found and running"
success "Docker Compose v2 available"
warning "Optional: Git not found"

echo
step "Processing configuration..."

# Simulate progress
for i in {1..5}; do
    echo -n "Processing step $i... "
    sleep 0.5
    echo -e "${GREEN}${CHECK}${NC}"
done

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