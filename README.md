# Lumenmon

Lumenmon is a one-command monitoring stack for Linux hosts.

- **One command install** – Pipe `install.sh`; the console is ready in seconds.
- **Copy/paste invites** – Every agent joins with a single SSH URL.
- **Standard tools** – SSH transport, TSV files, Bash scripts. Nothing exotic.
- **Live terminal view** – Textual TUI shows CPU, memory, disk, and invites.
- **Nothing extra** – No database, no cert dance, no dashboards to configure.


<img width="500" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />


## Install
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

## Add Agents

The console prints an invite URL—copy/paste it on your agent host:

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE='<invite_url>' bash
```

Open the Textual dashboard anytime with:

```bash
lumenmon
```

## Architecture

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

**Console**
- Accepts SSH on port 2345 (container 22) and writes TSV metrics under `/data/agents/<id>`.
- Runs invite-driven enrollment to mint per-agent SSH users.
- Serves the Textual TUI for live agents and metrics.

**Agent**
- Runs Bash collectors for CPU (100 ms), memory (1 s), and disk (60 s).
- Streams each sample as a TSV row over SSH.

### Security
- **SSH-only**: Key-based auth
- **User isolation**: Each agent gets its own Linux user
- **ForceCommand**: Agents can't get shell access

## CLI Commands

```bash
lumenmon            # Open TUI dashboard (or show status)
lumenmon status     # Show system status (alias: s)
lumenmon logs       # Stream container logs (alias: l)
lumenmon invite     # Generate agent invite (alias: i)
lumenmon register   # Register agent with invite
lumenmon update     # Update to latest version (alias: u)
lumenmon uninstall  # Remove everything
lumenmon help       # Show help (alias: h)
```

## Installation Options

The installer walks you through image selection (stable registry build by default, or dev/local builds) and wires up the console, agent, and CLI with Docker Compose.

Prefer to roll your own image? Clone the repo and run the compose files inside `console/` and `agent/` with your `CONSOLE_HOST` and optional `CONSOLE_PORT` values.

## Contributing

PRs welcome—keep it simple, readable, and Bash-first.

Thanks to Textual, plotext, Docker, and OpenSSH for the heavy lifting.

```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
