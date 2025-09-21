
# Lumenmon

Lumenmon is a one-command monitoring stack for Linux hosts. It delivers everything you need to see the health of your fleet without adding new infrastructure:

- **Instant install** – Pipe `install.sh` and get a ready-to-use console in seconds.
- **One invite per agent** – Every enrollment is just a magic SSH URL; no manual key exchange.
- **SSH-only transport** – Metrics ride existing SSH ports with ForceCommand locking agents into the data gateway.
- **Live terminal dashboard** – The Textual TUI streams CPU, memory, disk, and invite status in real time.
- **Minimal footprint** – Collectors are shell scripts, hot data lives in tmpfs, and there is no database to babysit.
- **Container-native workflow** – Console and agent are Docker Compose stacks that ship consistently everywhere.

<img width="500" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

Absolutely KISS. Just Bash scripts piping metrics over SSH. No dashboards to wire up, no extra ports, and nothing outside your shell.


## Install

Run central installer to setup the Console Container:

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```
<img width="500" height="864" alt="image" src="https://github.com/user-attachments/assets/7c53ed47-cc74-42d9-9e37-dd1f44e65917" />


After installation, the console generates a magic link to setup your first agent. This is just a temporary ssh user, the servers fingerprint is encoded in it. 

''' example
   curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE='ssh://reg_1758482881441:b71f0da33953@localhost:2345/#ssh-ed25519_AAAAC3NzaC1lZDI1NTE5AAAAIImZwbLPoVLRJpPPh6xjpTqILLbBYfwv7603ommQh0Fg' bash
'''
<img width="500" alt="image" src="https://github.com/user-attachments/assets/3389a70a-2bf6-460c-908c-198184dd21ec" />


## Architecture

**Console**: Runs an SSH Server to receive data from agents.
**Agent**: Delievers data from 




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
Agent
> Collectors collect metrics at intervals (CPU: 0.1s, Memory: 1s, Disk: 60s)
> tunnel transports metrics as TSV lines
console
> ingress receives data via SSH ForceCommand
> enrollment
> storage   uses tmpfs for hot data, disk for persistence
> tui reads TSV files and renders real-time graphs


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

```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
