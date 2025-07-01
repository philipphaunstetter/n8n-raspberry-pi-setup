#!/bin/bash

# CLI Showcase - demonstrates all enhanced CLI features

echo "🎨 Enhanced CLI Showcase for n8n Setup"
echo "========================================"
echo

echo "1. 🐍 Python Rich CLI (Beautiful, Interactive)"
echo "   Source: n8n-cli.py"
echo "   Features: Tables, progress bars, rich formatting"
echo
source venv/bin/activate
./n8n-cli.py setup --debug --service traefik --service postgres
echo

echo "2. 🔧 Enhanced Bash CLI (Lightweight, Fast)"
echo "   Source: simple-cli-demo.sh"
echo "   Features: Colors, unicode symbols, boxes"
echo
./simple-cli-demo.sh
echo

echo "3. 📊 Service Status (Real Docker Integration)"
echo "   Source: n8n-cli.py status"
echo
./n8n-cli.py status
echo

echo "4. 📋 Help System (Auto-generated Documentation)"
echo
./n8n-cli.py --help
echo

echo "✨ All CLI enhancements are now available!"
echo "Choose your preferred style:"
echo "  • Python CLI: Rich, interactive, modern"
echo "  • Bash CLI: Fast, lightweight, colorful"
echo "  • Original: ./setup.sh (still works perfectly)"