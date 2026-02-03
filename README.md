```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
Lightweight system monitoring with MQTT transport. Sets up as docker server in 60 seconds, add clients via one magic command in 10 seconds to start monitoring. No dashboard config, no hassle.

<img width="400" alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

## Quick Start

**Console** (central dashboard):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/console/install.sh | bash
```

**Agent** (on each monitored host):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash
lumenmon-agent register '<invite-url>'
lumenmon-agent start
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

**Update:** `lumenmon-agent update` fetches and checks out the latest release tag. Credentials preserved. The console dashboard shows "UPDATE AVAILABLE" when a newer version exists.

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
<summary>Mail Forwarding</summary>

Agents automatically forward local system mail (`/var/mail/root`) to the console via MQTT. This captures:

- Cron job output and errors
- System alerts and notifications
- Automated reports from services (Proxmox, PBS, ZFS, etc.)

**How it works:**
```
/var/mail/root → agent (parse mbox) → MQTT → console → messages table → UI
```

**Requirements:** Any local MTA that delivers to `/var/mail/root` (postfix, sendmail, exim, nullmailer, etc.). Most systems have this by default.

**No SMTP port needed** - mail is forwarded via the existing MQTT connection (port 8884).

</details>

<details>
<summary>Data</summary>

All data stored in SQLite at `/data/metrics.db` (inside container).

**Retention:** Metrics older than 24h auto-deleted every 5 minutes. Most recent value per metric always preserved so offline agents keep their last known status.

**Metrics Table** (one per agent+metric, e.g. `id_abc123_generic_cpu`):

| Column | Type | Description |
|--------|------|-------------|
| timestamp | INTEGER | Unix timestamp (primary key) |
| value_real | REAL | Decimal values (CPU %, memory %) |
| value_int | INTEGER | Whole numbers |
| value_text | TEXT | Strings (hostname, version) |
| interval | INTEGER | Expected update interval (seconds) |
| min_value | REAL | Minimum valid value (optional) |
| max_value | REAL | Maximum valid value (optional) |

**Messages Table** (`messages`):

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Auto-increment primary key |
| agent_id | TEXT | Agent that received the email |
| mail_from | TEXT | Sender address |
| mail_to | TEXT | Recipient address |
| subject | TEXT | Email subject |
| body | TEXT | Email body |
| received_at | TIMESTAMP | When received |
| read | INTEGER | 0=unread, 1=read |

</details>

<details>
<summary>Writing Custom Collectors</summary>

Collectors are bash scripts in `agent/collectors/`. Standard structure:

```bash
#!/bin/bash
# What this collector does.
# Data source and calculation details.

METRIC="generic_example"
TYPE="REAL"            # REAL, INTEGER, or TEXT
MIN=0                  # Optional: minimum valid value
MAX=100                # Optional: maximum valid value

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # IMPORTANT: Use LC_ALL=C for commands that produce localized output
    value=$(LC_ALL=C some_command | parse_output)

    publish_metric "$METRIC" "$value" "$TYPE" "$BREATHE" "$MIN" "$MAX"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0  # Support: lumenmon-agent status

    sleep $BREATHE
done
```

**Locale handling:** Always use `LC_ALL=C` prefix for system commands to ensure consistent English output parsing:
```bash
# Good - forces English output
total=$(LC_ALL=C apt list --upgradable 2>/dev/null | grep -c "upgradable from")
usage=$(LC_ALL=C df -P / | tail -1 | awk '{print $5}' | tr -d '%')

# Bad - output varies by system locale
total=$(apt list --upgradable | grep -c "upgradable from")  # Fails on German systems
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

### Local Development
```bash
./dev/auto         # Full reset and setup with virtual agent
./dev/add3         # Spawn 3 test agents
```

### CSS (Tailwind)
```bash
cd console && npm install   # First time setup
cd console && npm run dev   # Watch mode - auto-recompile on changes
cd console && npm run build # One-time build
```

### Remote Test Server
Deploy directly to a test server via SSH (bypasses GitHub Actions):
```bash
export LUMENMON_TEST_HOST="root@your-test-server"
./dev/deploy-test web      # Build CSS + hot reload frontend (~3s)
./dev/deploy-test agent    # Deploy agent + restart (~1s)
./dev/deploy-test console  # Full console + restart (~5s)
./dev/deploy-test status   # Check remote status
```

### Releases
```bash
./dev/release      # Create version tag, triggers GitHub Actions build
```

GitHub Actions only builds Docker images on version tags (`v*`), not on every commit. This keeps the dev loop fast.

</details>
