# Lumenmon TUI Experiment Server

A lightweight terminal-based dashboard for Lumenmon using bash scripts and gum for an interactive TUI experience, now with **web browser access via ttyd**!

## Features

- 🌐 **NEW: Web Terminal Access** - Access TUI from any browser
- 🖥️ Terminal-based interface using gum
- 📊 Real-time metrics display with ASCII charts
- 🔄 Auto-refresh capability
- 📈 Fleet statistics and analytics
- ✅ Client approval/rejection management
- 🎨 Retro green phosphor terminal theme
- 🔒 Optional authentication for web access
- 📱 Mobile-friendly terminal interface

## Quick Start

### Web Browser Access (NEW - Recommended!)

```bash
# 1. Build and start the container
cd server_experiment
docker compose up --build -d

# 2. Open your browser to:
http://localhost:7681

# That's it! The TUI is now in your browser
```

### Traditional Terminal Access

```bash
# Direct terminal connection (if TUI_MODE=direct)
docker exec -it lumenmon-tui /app/scripts/tui.sh

# Or run locally without Docker (requires gum):
DB_PATH=../server/data/lumenmon.db ./scripts/tui.sh
```

## Requirements

- Docker & Docker Compose
- Access to the main server's SQLite database
- Terminal with UTF-8 support for box drawing characters

## Architecture

```
server_experiment/
├── scripts/
│   ├── tui.sh             # Main TUI interface
│   ├── db_query.sh        # Database query functions
│   ├── display_metrics.sh # Display formatting
│   └── charts.sh          # ASCII chart generation
├── Dockerfile             # Alpine-based container
├── docker-compose.yml     # Container configuration
└── .env                   # Environment settings
```

## Usage

### Main Menu Options

1. **View All Clients** - Display all connected clients with live metrics
2. **Select Client for Details** - Deep dive into specific client metrics
3. **View Pending Registrations** - Manage client approval/rejection
4. **Fleet Analytics** - View aggregate statistics and charts
5. **Auto-Refresh Toggle** - Enable/disable automatic updates
6. **Exit** - Close the TUI

### Navigation

- Use arrow keys to navigate menus
- Enter to select options
- ESC to go back
- Ctrl+C to exit

### Features

#### Client Overview
- CPU usage with progress bars
- Memory utilization
- Load average
- Online/offline status
- Last seen timestamp

#### Client Details
- Detailed system metrics
- CPU and memory history charts
- Disk usage statistics
- Network information
- Raw metrics viewer

#### Fleet Analytics
- Aggregate CPU/memory usage
- Client comparison charts
- System health overview

## Configuration

Edit `.env` or set environment variables:

```bash
# Mode Selection
TUI_MODE=web          # 'web' for browser access, 'direct' for terminal only

# Database location
DB_PATH=/app/data/lumenmon.db

# Refresh settings
REFRESH_RATE=5        # Seconds between refreshes
AUTO_REFRESH=true     # Enable auto-refresh

# Terminal
TERM=xterm-256color   # Terminal type

# Web Terminal Settings (ttyd)
TTYD_PORT=7681        # Web interface port
TTYD_AUTH=            # Set to 'username:password' for authentication
TTYD_MAX_CLIENTS=10   # Maximum concurrent web connections
TTYD_READONLY=false   # Set to true for read-only mode
TTYD_SSL=false        # Enable SSL/TLS (requires certificates)
```

### Enabling Authentication

To secure the web interface with a username and password:

```bash
# In .env file:
TTYD_AUTH=admin:secretpassword

# Or in docker-compose.yml:
environment:
  - TTYD_AUTH=admin:secretpassword
```

## Development

### Running Locally

```bash
# Install gum
brew install gum  # macOS
# or
go install github.com/charmbracelet/gum@latest

# Run the TUI
./scripts/tui.sh
```

### Modifying Scripts

Scripts are mounted as volumes in development, so changes are reflected immediately:

1. Edit scripts in `scripts/` directory
2. Changes appear on next menu action or refresh
3. No rebuild needed

## Comparison with Main Dashboard

| Feature | Streamlit Dashboard | TUI Experiment (with ttyd) |
|---------|-------------------|----------------------------|
| Technology | Python/Streamlit | Bash/Gum/ttyd |
| Resource Usage | ~200MB RAM | ~15MB RAM |
| Startup Time | ~5 seconds | <1 second |
| Remote Access | Web browser | Web browser + SSH |
| Charts | Plotly (interactive) | ASCII (static) |
| Auto-refresh | JavaScript | Bash loop |
| Mobile Support | Responsive design | Terminal in browser |
| Authentication | Via dashboard | Built-in (optional) |
| Dependencies | Python, many libs | Minimal (Alpine) |

## Troubleshooting

### Database Not Found
- Ensure the main server is running
- Check volume mount in docker-compose.yml
- Verify database path in .env

### Display Issues
- Use a terminal with UTF-8 support
- Set TERM=xterm-256color
- Ensure terminal width is at least 80 columns

### Gum Not Found
- Container will auto-install gum
- For local development, install from: https://github.com/charmbracelet/gum

## Future Enhancements

- [ ] Export metrics to CSV
- [ ] Alert thresholds
- [ ] Historical data browser
- [ ] Multi-database support
- [ ] Custom color themes
- [ ] Keyboard shortcuts