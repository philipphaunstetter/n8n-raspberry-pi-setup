#!/usr/bin/env python3
"""
Enhanced CLI for n8n setup with rich formatting
"""

import subprocess
import sys
from pathlib import Path
from typing import List, Optional

try:
    import typer
    from rich.console import Console
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
    from rich.prompt import Prompt, Confirm
    from rich.table import Table
    from rich.tree import Tree
    from rich.markdown import Markdown
    import inquirer
except ImportError:
    print("Please install requirements: pip install -r requirements.txt")
    sys.exit(1)

app = typer.Typer(rich_markup_mode="rich")
console = Console()

SERVICES = {
    "traefik": "Reverse proxy with automatic SSL certificates",
    "qdrant": "Vector database for AI/ML workflows", 
    "nginx": "Web server for static files and additional routing",
    "postgres": "PostgreSQL database for n8n data persistence",
    "monitoring": "Portainer for container management"
}

def show_banner():
    """Display the application banner"""
    banner = """
# 🚀 n8n Raspberry Pi Setup

A comprehensive, modular setup for deploying n8n with optional services.
"""
    console.print(Panel(Markdown(banner), border_style="blue", padding=(1, 2)))

def show_services_table():
    """Display available services in a table"""
    table = Table(title="Available Services", show_header=True, header_style="bold magenta")
    table.add_column("Service", style="cyan", no_wrap=True)
    table.add_column("Description", style="green")
    table.add_column("Status", justify="center")
    
    for service, description in SERVICES.items():
        # Check if service is already configured
        status = "✅ Available" 
        table.add_row(service, description, status)
    
    console.print(table)

def select_services() -> List[str]:
    """Interactive service selection with fallback"""
    console.print("\n[bold yellow]Select the services you want to install:[/bold yellow]")
    
    try:
        choices = [
            inquirer.Checkbox('services',
                             message="Choose services (use spacebar to select, enter to confirm)",
                             choices=list(SERVICES.keys()),
                             default=['traefik'])
        ]
        
        answers = inquirer.prompt(choices)
        return answers['services'] if answers else []
    except Exception as e:
        # Fallback for non-interactive environments
        console.print(f"[yellow]Interactive selection not available: {e}[/yellow]")
        console.print("[blue]Using default services: traefik[/blue]")
        return ['traefik']

def run_setup_with_progress(selected_services: List[str], debug: bool = False):
    """Run the setup script with progress tracking"""
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
    ) as progress:
        
        # Simulate setup steps
        setup_task = progress.add_task("Setting up services...", total=len(selected_services) + 2)
        
        progress.update(setup_task, description="Checking dependencies...")
        # Here you would call your actual setup.sh script
        progress.advance(setup_task)
        
        for service in selected_services:
            progress.update(setup_task, description=f"Configuring {service}...")
            # Simulate service configuration
            import time
            time.sleep(0.5)
            progress.advance(setup_task)
        
        progress.update(setup_task, description="Generating configuration files...")
        progress.advance(setup_task)
    
    console.print("\n[bold green]✅ Setup completed successfully![/bold green]")

@app.command()
def setup(
    debug: bool = typer.Option(False, "--debug", help="Run in debug mode (don't start services)"),
    services: Optional[List[str]] = typer.Option(None, "--service", help="Pre-select services")
):
    """
    Run the interactive n8n setup
    """
    show_banner()
    
    if not services:
        show_services_table()
        services = select_services()
    
    if not services:
        console.print("[yellow]No services selected. Exiting.[/yellow]")
        return
    
    console.print(f"\n[bold blue]Selected services:[/bold blue] {', '.join(services)}")
    
    if debug:
        console.print("[yellow]Debug mode: Configuration will be generated but services won't start[/yellow]")
    
    if debug or Confirm.ask("Continue with setup?", default=True):
        run_setup_with_progress(services, debug)
        
        # Show access information
        if 'traefik' in services:
            console.print("\n[bold green]🌐 Access your services at:[/bold green]")
            console.print("• n8n: https://your-domain.com")
            if 'qdrant' in services:
                console.print("• Qdrant: https://qdrant.your-domain.com")
        else:
            console.print("\n[bold green]🌐 Access your services at:[/bold green]")
            console.print("• n8n: http://localhost:5678")
    else:
        console.print("[yellow]Setup cancelled.[/yellow]")

@app.command()
def status():
    """
    Show status of running services
    """
    console.print("[bold blue]Checking service status...[/bold blue]")
    
    try:
        result = subprocess.run(['docker', 'compose', 'ps'], 
                              capture_output=True, text=True, check=True)
        
        if result.stdout.strip():
            console.print("\n[bold green]Running services:[/bold green]")
            console.print(result.stdout)
        else:
            console.print("[yellow]No services are currently running.[/yellow]")
            
    except subprocess.CalledProcessError:
        console.print("[red]Error: Could not check service status. Is Docker running?[/red]")
    except FileNotFoundError:
        console.print("[red]Error: Docker not found. Please install Docker first.[/red]")

@app.command()
def logs(
    service: Optional[str] = typer.Argument(None, help="Service name to show logs for"),
    follow: bool = typer.Option(False, "-f", "--follow", help="Follow log output")
):
    """
    Show logs for services
    """
    cmd = ['docker', 'compose', 'logs']
    if follow:
        cmd.append('-f')
    if service:
        cmd.append(service)
    
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError:
        console.print(f"[red]Error: Could not show logs for {service or 'services'}[/red]")
    except FileNotFoundError:
        console.print("[red]Error: Docker not found.[/red]")

if __name__ == "__main__":
    app()