```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
Lightweight system monitoring with MQTT transport. Sets up in 60 Seconds.

Console runs in Docker, agents are bare metal bash scripts.as

## Quick Start

**Console** (central dashboard):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/console/install.sh | bash
```

**Agent** (on each monitored system):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash -s '<invite-url>'
```

<img width="700" alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

## Supported Systems

| Component | Requirements | Metrics |
|-----------|--------------|---------|
| Console | Docker, Docker Compose | — |
| Agent (Generic) | Linux, bash, curl, openssl, systemd | cpu, memory, disk, heartbeat, hostname, os, kernel, uptime |

## Architecture

```
┌─────────────┐               ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤  MQTT/TLS     ├─────────────┤
│ • CPU 1s    │──────────────►│ • MQTT 8884 │──► Web :8080
│ • Mem 10s   │               │ • SQLite    │
│ • Disk 60s  │               │ • Flask     │
└─────────────┘               └─────────────┘
  (bare metal)                   (Docker)
```

## Commands

**Console** (`lumenmon`):
```bash
lumenmon            # Show status
lumenmon invite     # Generate agent invite
lumenmon logs       # View logs
lumenmon update     # Update container
lumenmon uninstall  # Remove everything
```

**Agent** (`lumenmon-agent`):
```bash
lumenmon-agent              # Show status
lumenmon-agent register     # Register with invite URL
lumenmon-agent start/stop   # Control service
lumenmon-agent logs         # View logs
lumenmon-agent uninstall    # Remove agent
```

<details>
<summary>Console</summary>

Docker container running MQTT broker (Mosquitto), SQLite database, and web dashboard (Flask + Caddy).

**Install:** Downloads `docker-compose.yml`, pulls image from GitHub Container Registry, starts container.

**Update:** `lumenmon update` pulls latest image and restarts container. Data in `~/.lumenmon/console/data/` is preserved.

**Uninstall:** `lumenmon uninstall` stops container, removes image and all data.

</details>

<details>
<summary>Agent</summary>

Pure bash scripts that collect metrics and publish via `mosquitto_pub` over TLS. No Docker, no compiled binaries.

**Install:** Asks for confirmation, then:
1. Installs `mosquitto-clients` via apt-get
2. Downloads scripts from GitHub to `/opt/lumenmon/`
3. Creates systemd service `lumenmon-agent.service`
4. Creates CLI `/usr/local/bin/lumenmon-agent`
5. Registers with console and starts service (if invite URL provided)

**Update:** `lumenmon-agent update` downloads latest scripts from GitHub, restarts service. Credentials in `/opt/lumenmon/data/` are preserved.

**Uninstall:** `lumenmon-agent uninstall` stops service, removes all files.

</details>

<details>
<summary>Security</summary>

- **TLS Pinning:** Agents verify server certificate fingerprint on first connection
- **Per-agent credentials:** Each agent gets unique MQTT credentials
- **Outbound only:** Agents initiate connections, console cannot connect to agents
- **Rate limiting:** MQTT broker limits connections and message rates

</details>

<details>
<summary>Development</summary>

```bash
./dev/auto      # Full reset and setup
./dev/add3      # Spawn 3 test agents
./dev/release   # Create new release
```

</details>
