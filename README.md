  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝

Lightweight system monitoring with SSH transport and TUI dashboard.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

## Usage

Run installer and choose:
- **Console** - Central monitoring dashboard
- **Agent** - Metrics collector (can be on different machines)

View dashboard:
```bash
docker exec -it lumenmon-console python3 /app/tui/tui.py
```

## How It Works

**Architecture:** Agents collect metrics and send them to a central console via SSH. The console stores metrics in RAM (tmpfs) and displays them in a TUI dashboard.

**Data Flow:**
1. Agent collectors gather metrics at defined intervals (CPU: 0.1s, Memory: 1s, Disk: 60s)
2. Metrics sent as TSV lines through SSH tunnel: `timestamp\tagent_id\tmetric\ttype\tvalue\tinterval`
3. Console SSH ForceCommand routes data through gateway script to appropriate storage
4. TUI reads from `/var/lib/lumenmon/hot/` for real-time display

**Security:** SSH key-only authentication, per-agent Linux users, ForceCommand prevents shell access.

## Structure

```
~/.lumenmon/
├── console/           # Dashboard container
│   ├── docker-compose.yml
│   └── data/         # Persistent data (gitignored)
├── agent/            # Metrics collector
│   ├── docker-compose.yml
│   └── data/         # Config (.env with CONSOLE_HOST)
└── install.sh        # Installer/updater
```

## Update

Run installer again - it pulls latest and restarts containers.

## Requirements

- Docker
- Docker Compose

## Performance Note

For high-frequency deployments (>10,000 metrics/sec), consider using tmpfs mount for `/data/agents/` directory to reduce disk I/O.
