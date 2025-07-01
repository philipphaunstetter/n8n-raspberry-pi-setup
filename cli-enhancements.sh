#!/bin/bash

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
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
BULLET="•"
STAR="★"
WARNING="⚠"
INFO="ℹ"
ROCKET="🚀"
GEAR="⚙"
LOCK="🔒"

# Enhanced status functions with tool-like formatting
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

step() {
    echo -e "${PURPLE}${BOLD}${ARROW}${NC} ${WHITE}$1${NC}"
}

# Tool-like step formatting (similar to Claude Code tool output)
tool_step() {
    local tool_name="$1"
    local description="$2"
    echo -e "${BLUE}${BOLD}${tool_name}${NC}(${description})"
    echo -e "  ${CYAN}⎿${NC}  $3"
}

# Command execution with tool-like output
run_command() {
    local command="$1"
    local description="$2"
    echo -e "${BLUE}${BOLD}Bash${NC}(${description})"
    echo -e "  ${CYAN}⎿${NC}  ${DIM}${command}${NC}"
    
    # Execute and capture output
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    if [[ -n "$output" ]]; then
        echo "$output" | while IFS= read -r line; do
            echo -e "     ${line}"
        done
    fi
    
    return $exit_code
}

# Docker operation with tool-like formatting
docker_step() {
    local operation="$1"
    local description="$2"
    echo -e "${BLUE}${BOLD}Docker${NC}(${description})"
    echo -e "  ${CYAN}⎿${NC}  ${operation}"
}

# Setup step with tool-like formatting
setup_step() {
    local step_name="$1"
    local description="$2"
    echo -e "${BLUE}${BOLD}Setup${NC}(${description})"
    echo -e "  ${CYAN}⎿${NC}  ${step_name}"
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}["
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "] ${percentage}%% (${current}/${total})${NC}"
}

# Interactive menu with better formatting
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} ${WHITE}${BOLD}$title${NC}$(printf "%*s" $((36 - ${#title})) "")${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════╣${NC}"
    
    for i in "${!options[@]}"; do
        echo -e "${CYAN}${BOLD}║${NC} ${YELLOW}$((i+1)).${NC} ${options[i]}$(printf "%*s" $((32 - ${#options[i]})) "")${CYAN}${BOLD}║${NC}"
    done
    
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}\n"
}

# Confirmation prompt with better styling
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ $default == "y" ]]; then
        local prompt="${GREEN}[Y/n]${NC}"
    else
        local prompt="${RED}[y/N]${NC}"
    fi
    
    echo -e -n "${YELLOW}${BOLD}${WARNING}${NC} ${WHITE}$message${NC} $prompt: "
    read -r response
    
    if [[ -z "$response" ]]; then
        response=$default
    fi
    
    [[ $response =~ ^[Yy]$ ]]
}

# Box drawing for sections
section_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo -e "\n${BLUE}${BOLD}┌$(printf '─%.0s' $(seq 1 $width))┐${NC}"
    echo -e "${BLUE}${BOLD}│$(printf ' %.0s' $(seq 1 $padding))${WHITE}$title${BLUE}$(printf ' %.0s' $(seq 1 $padding))│${NC}"
    echo -e "${BLUE}${BOLD}└$(printf '─%.0s' $(seq 1 $width))┘${NC}\n"
}

# Example usage
demo() {
    section_header "n8n Setup Demo"
    
    info "Starting setup process..."
    step "Checking dependencies"
    success "Docker found"
    success "Docker Compose found"
    warning "Git not found (optional)"
    
    echo
    show_menu "Select Services" \
        "Traefik (SSL Proxy)" \
        "PostgreSQL Database" \
        "Qdrant Vector DB" \
        "Nginx Web Server" \
        "Portainer Monitoring"
    
    if confirm "Continue with installation?" "y"; then
        step "Installing services..."
        for i in {1..10}; do
            progress_bar $i 10
            sleep 0.2
        done
        echo
        success "Installation completed!"
    else
        error "Installation cancelled"
    fi
}

# Uncomment to run demo
# demo