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

Next up: 
- Smart Collector Fail Detection (zfs.sh)
- Proxmox Suppor
- Failed Value State detection, deliver threshold values low and high (in DB yes or no?)
- Socket Status Collector Script
- github script test check
- docker update avilable check
- sysos update check 
- nextcloud backup check

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

## Supported Agent Systems

| OS | Components |
|----|------------|
| Debian/Ubuntu | **generic**: cpu, memory, disk, heartbeat, hostname |
| Proxmox VE | **generic** + **proxmox**: vms, containers, storage, ZFS |

## Architecture

```
┌─────────────┐               ┌─────────────┐
│   Agent     │──────────────►│   Console   │
├─────────────┤  MQTT/TLS     ├─────────────┤
│ Collectors  │──────────────►│ • MQTT 8884 │──► Web :8080
│ (see below) │               │ • SQLite    │
└─────────────┘               │ • Flask     │
  (bare metal)                └─────────────┘
                                 (Docker)
```

### Collection Intervals

| Rhythm | Interval | Metrics |
|--------|----------|---------|
| PULSE | 1s | cpu, heartbeat |
| BREATHE | 10s | memory |
| CYCLE | 60s | disk, proxmox vms/containers/storage |
| REPORT | 1h | hostname, os, kernel, uptime |

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

**Supported Platforms:**

| Platform | Install Path | Service |
|----------|--------------|---------|
| Debian/Ubuntu | `/opt/lumenmon/` | systemd |
| TrueNAS SCALE | `/mnt/yourpool/lumenmon/` | Init Script (WebUI) |
| Proxmox VE | `/opt/lumenmon/` | systemd |

**Requirements:** `mosquitto-clients` (`apt install mosquitto-clients`)

**Debian/Ubuntu Install:**
1. Downloads scripts to `/opt/lumenmon/`
2. Creates systemd service `lumenmon-agent.service`
3. Creates CLI `/usr/local/bin/lumenmon-agent`

**TrueNAS SCALE Install:**
1. Prompts for install path (must be on a pool under `/mnt/`)
2. Downloads scripts to chosen path (survives TrueNAS updates)
3. Requires manual Init Script setup in WebUI:
   - System Settings → Advanced → Init/Shutdown Scripts
   - Type: Script, When: Post Init
   - Script: `/mnt/yourpool/lumenmon/start-agent.sh`

**Update:** `lumenmon-agent update` pulls latest scripts. Credentials preserved.

**Uninstall:** `lumenmon-agent uninstall` stops service/process, removes files.

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
./dev/auto         # Full reset and setup
./dev/add3         # Spawn 3 test agents
./dev/add-virtual  # Virtual agent with ALL metrics (no Proxmox/ZFS needed)
./dev/release      # Create new release
```

The virtual agent publishes fake data for all collectors (generic + proxmox + zfs) for testing widgets without real infrastructure.

</details>
