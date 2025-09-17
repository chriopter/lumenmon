# Lumenmon

Lightweight system monitoring with SSH transport and TUI dashboard.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/user/lumenmon/main/install.sh | bash
```

## Usage

Run installer and choose:
- **Console** - Central monitoring dashboard
- **Agent** - Metrics collector (can be on different machines)

View dashboard:
```bash
docker exec -it lumenmon-console python3 /usr/local/bin/tui.py
```

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