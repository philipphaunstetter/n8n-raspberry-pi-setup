# n8n Raspberry Pi Setup

A comprehensive, modular setup script for deploying n8n (workflow automation) with optional services on Raspberry Pi and other Linux systems. This project provides a flexible, production-ready deployment with automatic SSL certificates, monitoring, and database options.

## 🚀 Features

### Core Capabilities
- **Modular Service Selection**: Choose exactly which services you need
- **Automatic SSL Certificates**: Let's Encrypt integration with Cloudflare DNS challenge
- **Production Ready**: Secure defaults and best practices
- **Raspberry Pi Optimized**: Tested and optimized for ARM-based systems
- **Multi-Platform Support**: Works on Ubuntu, Debian, CentOS, Fedora, Arch Linux, and macOS

### Available Services

| Service | Description | Use Case |
|---------|-------------|----------|
| **n8n** | Workflow automation platform | Core service (always included) |
| **Traefik** | Reverse proxy with automatic SSL | Production deployments with HTTPS |
| **Qdrant** | Vector database | AI/ML workflows and embeddings |
| **PostgreSQL** | Relational database | Persistent data storage for n8n |
| **Nginx** | Web server | Static files and additional routing |
| **Portainer** | Container management UI | Docker monitoring and management |

### Smart Configuration
- **Infrastructure Requirements Guide**: Pre-setup checklist and instructions
- **Service Dependencies**: Automatic dependency resolution
- **Context-Aware Setup**: Adapts configuration based on selected services
- **Multiple SSL Options**: Cloudflare DNS, HTTP challenge, or manual certificates
- **Flexible Access**: Subdomain routing with Traefik or port-based access

## 📋 Prerequisites

### System Requirements
- **Minimum**: 2GB RAM, 10GB free disk space
- **Recommended**: 4GB+ RAM for full stack deployment
- **Raspberry Pi**: Pi 4 with 4GB+ RAM, SSD storage recommended

### Required Software
- Docker (20.10+)
- Docker Compose (v2 recommended)
- gettext (for envsubst)

### Optional Requirements
- Domain name (for SSL certificates)
- Cloudflare account and API token (for automatic SSL)
- Router/firewall configuration for external access

## 🛠️ Installation

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/n8n-raspberry-pi-setup.git
   cd n8n-raspberry-pi-setup
   ```

2. **Make the setup script executable**:
   ```bash
   chmod +x setup.sh
   ```

3. **Run the setup**:
   ```bash
   ./setup.sh
   ```

### Setup Options

| Command | Description |
|---------|-------------|
| `./setup.sh` | Full guided setup with infrastructure requirements |
| `./setup.sh --debug` | Generate configuration without starting services |
| `./setup.sh --help` | Show help and usage information |

## 🎯 Usage Scenarios

### 1. Quick Start (Recommended)
**Services**: n8n + Traefik  
**Best for**: Production deployment with SSL  
**Access**: `https://n8n.yourdomain.com`

### 2. Minimal Setup
**Services**: n8n only  
**Best for**: Local development  
**Access**: `http://localhost:5678`

### 3. AI/ML Stack
**Services**: n8n + Traefik + Qdrant  
**Best for**: AI workflows with vector storage  
**Access**: 
- n8n: `https://n8n.yourdomain.com`
- Qdrant: `https://qdrant.yourdomain.com`

### 4. Full Stack
**Services**: All services included  
**Best for**: Complete production environment  
**Access**: Multiple subdomains with monitoring

### 5. Database Enhanced
**Services**: n8n + Traefik + PostgreSQL  
**Best for**: High-volume workflows with persistent storage  
**Features**: pgAdmin web interface, automatic n8n database configuration

## 🔧 Configuration

### Environment Variables
The setup automatically generates a `.env` file with all necessary configuration. Key variables include:

```bash
# Core n8n Configuration
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password
WEBHOOK_URL=n8n.yourdomain.com

# Traefik Configuration (if selected)
HTTP_PORT=80
HTTPS_PORT=443
CERTIFICATE_EMAIL=your-email@example.com
CF_DNS_API_TOKEN=your-cloudflare-token

# Service-specific configurations
POSTGRES_PASSWORD=auto-generated-password
QDRANT_API_KEY=optional-api-key
```

### Service Configuration
Each service can be configured during setup:

- **Traefik**: SSL method, domain configuration, dashboard access
- **Qdrant**: Storage type, dashboard exposure, API protection
- **PostgreSQL**: Database credentials, pgAdmin interface
- **Nginx**: Purpose (static files, proxy, custom), access method
- **Monitoring**: Portainer credentials, security options

## 🌐 Infrastructure Setup

### Domain and DNS
1. **Domain Requirements**: Own a domain name for SSL certificates
2. **DNS Configuration**: Point A record to your server's public IP
3. **Cloudflare Setup**: (Recommended) Manage domain through Cloudflare

### Network Configuration
- **Traefik Setup**: Open ports 80 and 443
- **Development Setup**: Access via localhost ports
- **Router Configuration**: Port forwarding for home servers

### Cloudflare API Token
Required for automatic SSL certificates:
1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to "My Profile" → "API Tokens"
3. Create custom token with permissions:
   - Zone:Zone:Read (all zones)
   - Zone:DNS:Edit (specific zone)

## 📁 Project Structure

```
n8n-raspberry-pi-setup/
├── setup.sh                    # Main setup script
├── .env.example                # Environment variables template
├── docker-compose.template.yml # Legacy template (for reference)
├── templates/                  # Modular service templates
│   ├── base.yml               # Core n8n service
│   ├── traefik.yml            # Reverse proxy + SSL
│   ├── qdrant.yml             # Vector database
│   ├── postgres.yml           # PostgreSQL database
│   ├── nginx.yml              # Web server
│   └── monitoring.yml         # Portainer monitoring
├── static/                    # Static files directory
│   └── robots.txt
├── letsencrypt/               # SSL certificates storage
│   └── acme.json
└── README.md                  # This file
```

## 🔒 Security Features

- **Automatic SSL Certificates**: Let's Encrypt integration
- **Strong Password Generation**: Auto-generated secure passwords
- **Basic Authentication**: Protected admin interfaces
- **Docker Socket Proxy**: Optional security for Portainer
- **Firewall Guidance**: Port and security configuration help

## 🐛 Troubleshooting

### Common Issues

1. **SSL Certificate Generation Fails**
   - Verify DNS records point to correct IP
   - Ensure ports 80/443 are accessible
   - Check Cloudflare API token permissions

2. **Docker Permission Errors**
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

3. **Service Won't Start**
   ```bash
   docker compose logs service-name
   ```

### Debug Mode
Use debug mode to test configuration without starting services:
```bash
./setup.sh --debug
```

### Log Checking
```bash
# View all service logs
docker compose logs

# View specific service logs
docker compose logs -f traefik
docker compose logs -f n8n
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Test with `./setup.sh --debug`
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) - The amazing workflow automation platform
- [Traefik](https://traefik.io/) - Modern reverse proxy and load balancer
- [Qdrant](https://qdrant.tech/) - Vector similarity search engine
- [Docker](https://docker.com/) - Containerization platform

## 📞 Support

- **Documentation**: Check the inline help and comments in `setup.sh`
- **Issues**: Report bugs and request features via GitHub Issues
- **Community**: Join the n8n community for workflow-related questions

---

**Made with ❤️ for the self-hosting community**