# Lumenmon

A lightweight, retro-styled system monitoring solution with a cyber-80s terminal aesthetic.

## Architecture

Lumenmon consists of two dockerized components: a metrics sink server with Streamlit dashboard (port 8080/8501) and distributed client collectors that gather system metrics. The sink stores data in SQLite while the dashboard provides real-time visualization with a retro-terminal interface inspired by 80s cyberpunk aesthetics.

## Quick Start

```bash
# Start server (sink + dashboard)
cd server && docker-compose up -d

# Start client collectors  
cd client && docker-compose up -d

# Run tests
./test_webhook.sh  # Test webhook forwarder (port 9090)
./test_smtp.sh     # Test SMTP forwarder (port 2525)
```

## Dashboard

Access the Streamlit dashboard at http://localhost:8501 featuring real-time metrics visualization with auto-refresh, cyber-retro terminal styling, and SQLite persistence for historical data analysis.

## Components

### Server
- **Sink API** (port 8080): Receives and stores metrics in SQLite
- **Dashboard** (port 8501): Streamlit-based monitoring interface with retro TUI theme
- **Database**: SQLite with automatic initialization and data retention management

### Client
- **Collectors**: OS-aware metric gathering (CPU, memory, disk, network)
- **Forwarders**: Webhook (9090) and SMTP (2525) message ingestion
- **Docker**: Alpine-based container with minimal footprint

## Configuration

### Client Environment
```bash
SERVER_URL=http://localhost:8080  # Sink endpoint
INTERVAL=5                         # Collection interval (seconds)
DEBUG=1                           # Enable debug output
```

### Deployment Modes
- **Development**: Separate containers on same machine using `localhost`
- **Production**: Client points to remote server via `SERVER_URL` environment variable

## Features
- Real-time system metrics monitoring
- ASCII art dashboard with terminal green phosphor theme
- Auto-refresh every 5 seconds
- Historical data visualization with Plotly charts
- Message feed from webhooks and SMTP
- Database maintenance controls
- Zero external dependencies for sink
- Modular OS-specific collectors

## License

MIT