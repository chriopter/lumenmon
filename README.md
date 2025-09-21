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
Just install the console once, the console will generate an invitation for new agents as well.

<img width="400" height="644" alt="image" src="https://github.com/user-attachments/assets/66e8d653-bd2e-4fc7-8f66-4233dcec360a" />
<img width="400" height="880" alt="image" src="https://github.com/user-attachments/assets/3389a70a-2bf6-460c-908c-198184dd21ec" />

This invitation command will immediately connect the new agent to a temporary user account, registers the agent ssh key and then establishes a permanent connection.

 ✔ Container lumenmon-console                 Started                                      0.2s
[✓] Console started
[→] Initializing console...
[✓] Invite generated
[✓] Command 'lumenmon' already installed in ~/.local/bin

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ LUMENMON Console installed!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next steps:

1. Install agent on server (expires in 5 minutes):

   curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE='ssh://reg_1758481722414:c734b0b18901@localhost:2345/#ssh-ed25519_AAAAC3NzaC1lZDI1NTE5AAAAIImZwbLPoVLRJpPPh6xjpTqILLbBYfwv7603ommQh0Fg' bash

2. Open dashboard:

   lumenmon


lumenmon main ❯

Done 
## How It Works


Lumenmon Console is a Docker container that runs an ssh deamon with one user per agent to connect.
Lumenmon Agent is a Docker container that connects to the Console and Pipes infos in from Collector Scripts.

**Key Features:**
- 🚀 **Instant setup** - One-line installation. Lumenmon generates Install-links for Agents 
- 🔒 **SSH-based** - Secure transport without additional ports
- 📊 **Real-time TUI** - Beautiful terminal dashboard
- 🪶 **Lightweight** - No databases or web servers
- 🐳 **Docker-powered** - Consistent deployment everywhere
- 🔑 **Zero passwords** - SSH key authentication only
- 
```
┌─────────────┐  SSH Tunnel   ┌─────────────┐
│   Agent 1   │──────────────►│             │
├─────────────┤               │   Console   │◄──── TUI Dashboard
│ Collectors  │               │             │
└─────────────┘               │             │
                              │ SSH Server  │
┌─────────────┐               │   Port 2345 │
│   Agent 2   │──────────────►│             │
├─────────────┤               └─────────────┘
│ Collectors  │                     │
└─────────────┘                     ▼
                              Permanent TSV Storage
                            (/data/lumenmon)
```

### Architecture

1. **Agents** collect metrics every few seconds (CPU: 0.1s, Memory: 1s, Disk: 60s)
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

## FAQ

### Why SSH instead of HTTP?

SSH provides authentication, encryption, and NAT traversal out of the box. No certificates, no reverse proxies, no firewall rules - just SSH.

### Why TSV instead of JSON?

TSV (Tab-Separated Values) is simple, fast to parse, and human-readable. Each metric is one line, making it perfect for streaming and grep.

### Can I monitor non-Docker hosts?

The agent runs in Docker but monitors the host system through volume mounts. The host just needs Docker - nothing else.

### How much overhead?

Minimal. Agents use ~10MB RAM and <1% CPU. The console uses ~50MB RAM. No databases means no memory bloat.

### Is it production-ready?

Lumenmon is designed for small to medium deployments. For thousands of servers, consider Prometheus or similar.

### How do I add custom metrics?

Drop a shell script in `agent/collectors/` that outputs TSV lines. The agent automatically picks it up.

### Can I use my own SSH keys?

Yes. The console and agents generate keys on first run, but you can replace them in the `data/ssh/` directories.

### What about Windows?

Windows with WSL2 and Docker Desktop works. Native Windows is not supported.

### How do updates work?

`lumenmon update` pulls the latest code and rebuilds containers. It detects whether you're using registry images or local builds and updates accordingly.

### Where is data stored?

- Console: `/var/lib/lumenmon/` in container, `./console/data/` on host
- Agent: `/tmp/` for metrics buffer, `./agent/data/` for keys

## Troubleshooting

### Agent can't connect

1. Check network: `lumenmon status`
2. Verify console is reachable from agent machine
3. Check firewall allows port 2345 (or your custom port)
4. Ensure invite hasn't expired (1 hour timeout)

### No metrics showing

1. Run `lumenmon status` - check "Data Flow" on console
2. Verify collectors are running on agent
3. Check logs: `lumenmon logs`

### TUI won't start

1. Ensure console container is running
2. Try direct access: `docker exec -it lumenmon-console python3 /app/tui/main.py`
3. Check terminal supports Unicode and colors

## Contributing

Contributions welcome! The codebase follows KISS principles:
- Shell scripts for system tasks
- Python (Textual) for TUI only
- No external dependencies beyond Docker
- Clear, readable code over clever tricks

## License

MIT License - See LICENSE file for details

## Credits

Built with:
- [Textual](https://github.com/Textualize/textual) - Terminal UI framework
- [plotext](https://github.com/piccolomo/plotext) - Terminal plotting
- Docker - Container runtime
- OpenSSH - Secure transport
