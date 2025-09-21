
# Lumenmon

Lumenmon is a one-command monitoring stack for Linux hosts.

- **One command install** – Pipe `install.sh`; the console is ready in seconds.
- **Copy/paste invites** – Every agent joins with a single SSH URL.
- **Standard tools** – SSH transport, TSV files, Bash scripts. Nothing exotic.
- **Live terminal view** – Textual TUI shows CPU, memory, disk, and invites.
- **Nothing extra** – No database, no cert dance, no dashboards to configure.

<img width="500" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

## Install

Get the console running, enroll an agent, open the dashboard—each step is one command.

1. **Install the console**
   ```bash
   curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
   ```

2. **Enroll an agent** (copy the invite URL printed by step 1)
   ```bash
   curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE='<invite_url>' bash
   ```

3. **Open the TUI**
   ```bash
   lumenmon
   ```

## Architecture

- **Console** – Listens on SSH, stores metrics in `/data/agents/<id>`, and serves the TUI.
- **Agent** – Runs shell collectors and ships TSV metrics over SSH at tight intervals.

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

**Agent**
- Collect CPU (100 ms), memory (1 s), and disk (60 s) samples via shell collectors.
- Stream each sample as a TSV row over SSH.

**Console**
- Ingress receives the SSH stream and writes TSV files under `/data/agents/<id>`.
- Enrollment scripts turn invite URLs into dedicated SSH users.
- The TUI reads the TSV files and renders live tables and graphs.


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

## Installation Options

The installer walks you through image selection (stable registry build by default, or dev/local builds) and wires up the console, agent, and CLI with Docker Compose.

Prefer to roll your own image? Clone the repo and run the compose files inside `console/` and `agent/` with your `CONSOLE_HOST` and optional `CONSOLE_PORT` values.

```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
