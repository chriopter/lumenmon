# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lumenmon is a lightweight system monitoring solution with SSH transport and TUI dashboard. It consists of two main components:
- **Console**: Central monitoring dashboard with SSH server and TUI interface
- **Agent**: Metrics collector that sends data to console via SSH

## Development Commands

### Quick Start (Development)
```bash
# Full auto-setup: reset, start containers, register agent, and launch TUI
./dev/auto

# Individual commands
./dev/start      # Start console and agent containers
./dev/stop       # Stop all containers
./dev/reset      # Clean everything and restart fresh
./dev/register   # Register agent with console (requires invite URL)
./dev/tui        # Launch TUI dashboard
./dev/logs       # Show container logs
```

### Docker Operations
```bash
# Build and run console
docker compose -f console/docker-compose.yml up -d --build

# Build and run agent (with local console)
CONSOLE_HOST=localhost CONSOLE_PORT=2345 docker compose -f agent/docker-compose.yml up -d --build

# Access TUI directly
docker exec -it lumenmon-console python3 /app/tui/main.py
```

### Python Development (TUI)
```bash
# Python dependencies (installed in Docker, but for reference)
pip install rich textual plotext pyperclip

# No specific linting/testing commands defined yet
# GitHub Actions uses: black, isort, flake8, pylint, mypy
```

## Architecture

### Data Flow
1. Agents collect metrics at intervals (CPU: 0.1s, Memory: 1s, Disk: 60s)
2. Metrics sent as TSV through SSH: `timestamp\tagent_id\tmetric\ttype\tvalue\tinterval`
3. Console SSH ForceCommand routes to gateway script → storage in `/var/lib/lumenmon/hot/`
4. TUI reads from tmpfs-mounted directories for real-time display

### Directory Structure
- `console/`: Dashboard container
  - `tui/`: Python Textual-based TUI application
    - `views/`: Dashboard and detail views
    - `models/`: Agent, metrics, invite data models
    - `services/`: Monitor and clipboard services
    - `config/`: Settings and theme CSS
  - `core/`: Shell scripts for SSH, enrollment, ingress
  - `data/`: Persistent agent data and SSH keys (gitignored)

- `agent/`: Metrics collector container
  - `collectors/`: Metric collection scripts (CPU, memory, disk)
  - `core/`: Registration and connection scripts
  - `data/`: SSH keys and config (gitignored)

### Security Model
- SSH key-based authentication only (no passwords)
- Per-agent Linux users in console container
- ForceCommand prevents shell access
- Agent data isolated by user permissions

## Key Implementation Details

### Console TUI (`console/tui/`)
- Built with Python Textual framework
- Main entry: `main.py` - handles app lifecycle and routing
- Dashboard view shows agents table and invites
- Detail view shows real-time graphs using plotext
- Refresh rate configurable in `config/settings.py`

### SSH Enrollment Flow
1. Console creates invite: `/app/core/enrollment/invite_create.sh`
2. Agent registers: `/app/core/setup/register.sh <invite_url>`
3. Console creates dedicated user and sets up SSH access
4. Agent connects and starts streaming metrics

### Metric Storage
- Hot data: `/var/lib/lumenmon/hot/<agent_id>/` (tmpfs)
- Files: `cpu.tsv`, `memory.tsv`, `disk.tsv`, `meta.tsv`
- Format: TSV with timestamp, agent_id, metric_name, type, value, interval

## Common Tasks

### Adding New Metrics
1. Create collector script in `agent/collectors/`
2. Add to agent's main loop in `agent/agent.sh`
3. Update TUI models in `console/tui/models/metrics.py`
4. Add visualization in `console/tui/views/detail.py`

### Modifying TUI
- Theme: Edit `console/tui/config/theme.css`
- Layout: Modify views in `console/tui/views/`
- Data models: Update `console/tui/models/`
- Keybindings: Edit `BINDINGS` in `console/tui/main.py`

### Debugging
- Container logs: `docker logs lumenmon-console` or `./dev/logs`
- Agent debug output: Check `agent/data/debug/`
- SSH issues: Verify keys in `console/data/ssh/` and `agent/data/ssh/`
- TUI issues: Run directly with `docker exec -it lumenmon-console python3 /app/tui/main.py`