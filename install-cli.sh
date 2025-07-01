#!/bin/bash

# Install enhanced CLI tools for n8n setup

set -e

GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Installing enhanced CLI tools...${NC}"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Python 3 not found. Installing...${NC}"
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3 python3-pip
    elif command -v brew &> /dev/null; then
        brew install python3
    else
        echo "Please install Python 3 manually"
        exit 1
    fi
fi

# Install Python dependencies
echo -e "${BLUE}Installing Python dependencies...${NC}"
pip3 install -r requirements.txt

# Make scripts executable
chmod +x n8n-cli.py
chmod +x cli-enhancements.sh

# Create symlink for easy access (optional)
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(pwd)/n8n-cli.py" "$HOME/.local/bin/n8n-setup"
    echo -e "${GREEN}✓ Created symlink: n8n-setup command available${NC}"
fi

echo -e "${GREEN}✓ CLI tools installed successfully!${NC}"
echo
echo -e "${BLUE}Usage examples:${NC}"
echo "  ./n8n-cli.py setup                 # Interactive setup"
echo "  ./n8n-cli.py setup --debug         # Debug mode"
echo "  ./n8n-cli.py status                # Check service status"
echo "  ./n8n-cli.py logs                  # View all logs"
echo "  ./n8n-cli.py logs n8n              # View n8n logs"
echo
echo "  # If symlink was created:"
echo "  n8n-setup setup                    # Same as above"