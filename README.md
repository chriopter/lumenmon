```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

Lightweight system monitoring with MQTT transport. Console runs in Docker, agents are bare metal bash scripts.

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

## Requirements

| Component | Requirements |
|-----------|--------------|
| Console | Docker, Docker Compose |
| Agent | Debian or Ubuntu, bash, curl, openssl, systemd |

<details>
<summary>Agent Installation Details</summary>

The installer will ask for confirmation before making any changes. It will:

1. **Install package:** `mosquitto-clients` via apt-get
2. **Download scripts** from GitHub to `/opt/lumenmon/`
3. **Create systemd service:** `lumenmon-agent.service`
4. **Create CLI symlink:** `/usr/local/bin/lumenmon-agent`

The agent is pure bash scripts - no compiled binaries. All scripts are downloaded from this repository and can be inspected at `/opt/lumenmon/`.

**Updates:** Run `lumenmon-agent update` to download the latest scripts from GitHub. This stops the service, replaces the scripts, and restarts. Your credentials and configuration in `/opt/lumenmon/data/` are preserved.

**Uninstall:** Run `lumenmon-agent uninstall` to stop the service, remove all files, and delete the systemd service.

</details>

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

**Agent** collects metrics and publishes to console via MQTT with TLS.

**Console** runs MQTT broker, stores in SQLite, serves web dashboard.

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
