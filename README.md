```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
Lightweight system monitoring with MQTT transport. Sets up in 60 Seconds. Console runs in Docker, agents are bare metal bash scripts.

<img width="700" alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

## Quick Start

**Console** (central dashboard):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/console/install.sh | bash
```

**Agent** (on each monitored system):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash -s '<invite-url>'
```


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
| BREATHE | 60s | memory, disk |
| CYCLE | 5m | proxmox vms/containers/storage/zfs |
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
| Proxmox VE | `/opt/lumenmon/` | systemd |

**Requirements:** `mosquitto-clients` (`apt install mosquitto-clients`)

**Install:**
1. Downloads scripts to `/opt/lumenmon/`
2. Creates systemd service `lumenmon-agent.service`
3. Creates CLI `/usr/local/bin/lumenmon-agent`

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
<summary>Data Retention</summary>

Metrics older than 24h are auto-deleted every 5 minutes. The most recent value per metric is always preserved so offline agents keep showing their last known status.

</details>

<details>
<summary>Writing Custom Collectors</summary>

Collectors are bash scripts in `agent/collectors/`. Standard structure:

```bash
#!/bin/bash
# What this collector does.
# Data source and calculation details.

RHYTHM="PULSE"         # Timing: PULSE(1s), BREATHE(10s), CYCLE(60s), REPORT(1h)
METRIC="generic_cpu"   # Metric name (prefix with category)
TYPE="REAL"            # REAL, INTEGER, or TEXT
MIN=0                  # Optional: minimum valid value
MAX=100                # Optional: maximum valid value

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    value="42.0"
    publish_metric "$METRIC" "$value" "$TYPE" "$PULSE" "$MIN" "$MAX"
    sleep $PULSE
done
```

**publish_metric** signature:
```bash
publish_metric "name" "value" "TYPE" interval [min] [max]
```

**Health Detection:** Values outside min/max bounds show as **failed** in dashboard.

```bash
# Static bounds (percentages)
publish_metric "cpu" "$val" "REAL" "$PULSE" 0 100

# Dynamic bounds (ZFS: online must equal total drives)
publish_metric "zfs_online" "$online" "INTEGER" "$CYCLE" "$total" "$total"

# One-time metric (interval=0, never stale)
publish_metric "hostname" "$host" "TEXT" 0
```

**Categories:**
| Directory | Prefix | Purpose |
|-----------|--------|---------|
| `collectors/generic/` | `generic_` | Universal (CPU, memory, disk) |
| `collectors/proxmox/` | `proxmox_` | Proxmox (VMs, containers, ZFS) |

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
