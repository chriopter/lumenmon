# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Server Operations
```bash
# Start the monitoring server (runs on port 8080)
cd server && python3 server.py

# Server endpoints:
# GET  /         - Web dashboard with metrics visualization
# POST /metrics  - Receives metrics data from clients
# GET  /api/feed - Returns webhook/email feed data as JSON
```

### Client Operations
```bash
# Build and run client with Docker Compose
cd client && docker-compose up -d

# Run collectors manually (from client directory)
cd client/collectors && ./collect.sh

# Environment variables for client:
# SERVER_URL - Server endpoint (default: http://localhost:8080)
# INTERVAL   - Collection interval in seconds (default: 5)
# DEBUG      - Enable debug output (0/1, default: 0)
```

### Testing
```bash
# Test webhook forwarder (port 9090)
./test_webhook.sh

# Test SMTP forwarder (port 2525)
./test_smtp.sh
```

## Architecture

Lumenmon is a lightweight monitoring system with two main components:

### Server (`server/server.py`)
- Single-file Python HTTP server using only standard library
- Stores metrics in memory with rolling history (last 60 values per metric)
- Provides real-time web dashboard with Chart.js visualizations
- Maintains webhook/email feed (last 50 messages)
- No external dependencies, runs standalone

### Client (`client/`)
- Shell-based collectors organized by OS type
- Docker container with Alpine Linux base
- Runs two parallel services:
  1. **Collectors**: Gather system metrics and send to server
  2. **Forwarders**: Listen for webhooks (9090) and SMTP (2525), forward to server

## Key Implementation Details

### Collector System (`client/collectors/`)
- **OS Detection**: `detect_os.sh` identifies the system type (debian, proxmox, arch, alpine, etc.)
- **Modular Structure**: Collectors organized in folders by OS type
  - `generic/` - Universal collectors (CPU, memory, disk, network)
  - OS-specific folders for specialized metrics
- **Main Orchestrator**: `collect.sh` runs appropriate collectors based on detected OS
- All collectors output simple key-value pairs for the server to parse

### Forwarders (`client/forwarders/`)
- **Webhook Forwarder**: `webhook.sh` - Accepts HTTP POST on port 9090, forwards to server feed
- **SMTP Forwarder**: `smtp.sh` - Simple SMTP server on port 2525, forwards emails to server feed

### Data Flow
1. Collectors gather metrics → Send to `/metrics` endpoint
2. Server stores in memory → Updates rolling history
3. Dashboard polls `/` → Displays real-time charts
4. Forwarders receive external data → Send to server feed
5. Feed accessible via dashboard or `/api/feed` endpoint

## Development Notes

- The client uses POSIX shell (`/bin/sh`) for maximum compatibility, with bash only where needed
- Server intentionally has no dependencies beyond Python standard library
- Client Docker image based on Alpine Linux for minimal footprint
- All scripts follow similar structure: configuration section, functions, main execution
- Collectors can be added by creating new `.sh` files in appropriate OS folder