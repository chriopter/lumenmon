```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

# The One-Button Monitoring Setup

Lightweight, KISS system monitoring that just works. No databases to configure, no dashboards to set up, no custom endpoints to manage.

Lumenmon connects agents via standard SSH and pipes metrics as TSV files. Everything is stupidly simple shell scripts, except the TUI for navigating data.

<img width="400" alt="screenshot-2025-09-21_20-57-00" src="https://github.com/user-attachments/assets/99c6eefa-8d93-4874-9ec6-0c9674d31f2b" />
<img width="400" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

## Install

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

This installs the console and generates invites for agents. Once installed, run `lumenmon invite` to get a one-line agent installer.

<img width="600" alt="image" src="https://github.com/user-attachments/assets/3389a70a-2bf6-460c-908c-198184dd21ec" />

The invite command creates a temporary SSH account, registers the agent's key, and establishes a permanent connection - all automatically.

## How It Works

**Console**: Docker container running an SSH daemon with one user per agent
**Agent**: Docker container that connects to console and pipes metrics from collector scripts

### Key Features

- 🚀 **Instant setup** - One-line installation, auto-generated agent invites
- 🔒 **SSH transport** - Secure without additional ports
- 📊 **Real-time TUI** - Beautiful terminal dashboard
- 🪶 **Lightweight** - No databases or web servers
- 🐳 **Docker-powered** - Consistent deployment everywhere
- 🔑 **Zero passwords** - SSH key authentication only

### Architecture

```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent 1   │──────────────►│             │
├─────────────┤               │   Console   │◄──── TUI Dashboard
│ Collectors  │               │ SSH Server  │
└─────────────┘               │ Port 2345   │
                              │             │
┌─────────────┐               │             │
│   Agent 2   │──────────────►│             │
├─────────────┤               └─────────────┘
│ Collectors  │                     │
└─────────────┘                     ▼
                              TSV Storage
                            (/data/agents)
```

1. **Agents** collect metrics at intervals (CPU: 0.1s, Memory: 1s, Disk: 60s)
2. **SSH tunnel** transports metrics as TSV lines
3. **Console** receives data via SSH ForceCommand
4. **Storage** uses tmpfs for hot data, disk for persistence
5. **TUI** reads TSV files and renders real-time graphs

### Security

- **SSH-only**: No additional attack surface
- **Key-based auth**: No passwords ever
- **User isolation**: Each agent gets its own Linux user
- **ForceCommand**: Agents can't get shell access
- **No root**: Everything runs as regular users

## CLI Commands

```bash
lumenmon              # Open TUI dashboard (or show status)
lumenmon status       # Show system status
lumenmon logs         # Stream container logs
lumenmon invite       # Generate agent invite
lumenmon register     # Register agent with invite
lumenmon update       # Update to latest version
lumenmon uninstall    # Remove everything
```

Short aliases available: `s` (status), `l` (logs), `i` (invite), `u` (update), `h` (help)

## TUI Dashboard

The terminal UI provides:
- **Overview**: List of all agents and their status
- **Agent details**: CPU, memory, disk graphs (press Enter on agent)
- **Invites**: Pending enrollment invites
- **Keybindings**:
  - `↑↓` Navigate agents
  - `Enter` View agent details
  - `Backspace` Return to overview
  - `i` Create invite
  - `y` Copy invite to clipboard
  - `r` Force refresh
  - `q` Quit

## Installation Options

### Docker Images

During installation, you can choose:
1. **Stable** (recommended) - Latest release from registry
2. **Dev** - Development builds with newest features
3. **Local** - Build from source on your machine

### Manual Installation

```bash
# Clone repository
git clone https://github.com/your-org/lumenmon
cd lumenmon

# Install console
cd console
CONSOLE_HOST=your-server.com docker compose up -d

# Install agent
cd ../agent
CONSOLE_HOST=your-server.com CONSOLE_PORT=2345 docker compose up -d
```

## Configuration

### Console Settings

Environment variables in `console/.env`:
- `CONSOLE_HOST`: Where agents connect (required)
- `CONSOLE_PORT`: SSH port (default: 2345)

### Agent Settings

Environment variables in `agent/.env`:
- `CONSOLE_HOST`: Console server address
- `CONSOLE_PORT`: Console SSH port

### Custom Collectors

Add collectors in `agent/collectors/`:

```bash
#!/bin/sh
# Custom metric collector
echo "$(date -Iseconds)\t$(hostname)\tcustom_metric\tgauge\t42\t60"
```


## Contributing

Feel free to contribute - the codebase values simplicity over complexity.

### Current State

Basic installation and SSH key exchange are complete and working. The TUI and monitoring scripts are being reworked for better performance and clarity.

## License

MIT License - See LICENSE file for details

## Credits

Built with:
- [Textual](https://github.com/Textualize/textual) - Terminal UI framework
- [plotext](https://github.com/piccolomo/plotext) - Terminal plotting
- Docker - Container runtime
- OpenSSH - Secure transport
