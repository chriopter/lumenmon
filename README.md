```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

> Lightweight system monitoring with MQTT transport. Pure push architecture — agents send metrics, the console never reaches into your systems. Sets up as docker server in 60 seconds, add clients via one magic command in 10 seconds to start monitoring. No dashboard config, no hassle.

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

| Rhythm | Interval | Typical collectors |
|--------|----------|--------------------|
| `PULSE` | 1s | `cpu`, `heartbeat` |
| `BREATHE` | 60s | `memory`, `disk` |
| `CYCLE` | 5m | `mail`, `proxmox_*` |
| `REPORT` | 1h | `hostname`, `lumenmon`, `version`, `debian_updates` |

### Collectors

All collectors are plain Bash scripts under `agent/collectors/`.

Read this section as:
- **Collector**: script name.
- **Publishes**: metric names sent to MQTT.
- **Interval**: update cadence.
- **Failure behavior**: when/why a metric marks host state as degraded.

#### Generic (all Linux systems)

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `cpu` | `generic_cpu` | 1s (`PULSE`) | stale only |
| `memory` | `generic_memory` | 60s (`BREATHE`) | stale only |
| `disk` | `generic_disk` | 60s (`BREATHE`) | stale only |
| `heartbeat` | `generic_heartbeat` | 1s (`PULSE`) | stale only (drives online/offline) |
| `hostname` | `generic_hostname` | 1h (`REPORT`) | stale only |
| `lumenmon` | `generic_sys_os`, `generic_sys_kernel`, `generic_sys_uptime` | 1h (`REPORT`) | stale only |
| `version` | `generic_agent_version` | 1h (`REPORT`) | stale only (UI may show update warning) |
| `mail` | `mail_message` | 5m (`CYCLE`) | informational (message stream) |
| `zpool` | `generic_zpool_total`, `generic_zpool_degraded` | 5m (`CYCLE`) | fails when any non-Proxmox pool is degraded |

#### Debian/Ubuntu

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `updates` | `debian_updates_total`, `debian_updates_security`, `debian_updates_release`, `debian_updates_age` | 1h (`REPORT`) | `debian_updates_total`: warn for 1..10, critical >10; security/release >0 stay critical |

#### Proxmox VE

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `vms` | `proxmox_vms_*` | 5m (`CYCLE`) | stale only |
| `containers` | `proxmox_containers_*` | 5m (`CYCLE`) | stale only |
| `storage` | `proxmox_storage_*` | 5m (`CYCLE`) | stale + bounds if configured |
| `zfs` | `proxmox_zfs_*` | 5m (`CYCLE`) | stale + bounds (online drives vs total) |
| `zpool_health` | `proxmox_zpool_*` | 5m (`CYCLE`) | degraded and upgrade-needed flags (`max=0`) |

#### Proxmox Backup Server (PBS)

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `datastore_count` | `pbs_datastore_count` | 5m (`CYCLE`) | fails when no datastore is detected |
| `task_failures` | `pbs_task_failures_24h` | 5m (`CYCLE`) | fails when errors/failures > 0 in last 24h |
| `backup_age` | `pbs_backup_age_hours` | 5m (`CYCLE`) | fails when age exceeds 24h |
| `verify_age` | `pbs_verify_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |
| `sync_age` | `pbs_sync_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |
| `gc_age` | `pbs_gc_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |

#### Hardware (real hosts)

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `temp` | `hardware_temp_*` | 5m (`CYCLE`) | fails on temperature thresholds |
| `pcie_errors` | `hardware_pcie_*` | 1h (`REPORT`) | fails on PCIe/AER errors |
| `intel_gpu` | `hardware_intel_gpu_*` | 5m (`CYCLE`) | fails on Intel GPU utilization thresholds |
| `vram` | `hardware_gpu_vram_*` | 5m (`CYCLE`) | fails on VRAM usage thresholds |
| `smart_values` | `hardware_smart_*` | 1h (`REPORT`) | fails on SMART health/temp/wear thresholds |
| `ssd_samsung` | `hardware_samsung_*` | 1h (`REPORT`) | inventory/firmware visibility for Samsung SSDs |

#### Optional

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `mullvad_active` | `optional_mullvad_active` | opt-in | stale/bounds depend on local config |

#### Quick policy note

Collector health is computed from:
- metric stale timeout (`interval` exceeded), and/or
- min/max bounds violations (`min_value`, `max_value`).

Entity (host) health rolls up from metric health. If any metric fails, entity status becomes degraded.

### Full Check Catalog

This is the complete check map currently implemented in repo (base + opt-in).

| Domain | Check | Source | Metric Prefix |
|--------|-------|--------|---------------|
| Core | CPU/Memory/Disk/Heartbeat | generic collectors | `generic_*` |
| Core | Host identity and runtime info | generic collectors | `generic_hostname`, `generic_sys_*`, `generic_agent_version` |
| Core | Debian updates | debian collector | `debian_updates_*` |
| Core | Proxmox VM/LXC/storage/ZFS | proxmox collectors | `proxmox_*` |
| Core | Proxmox zpool degraded/upgrade-needed | proxmox collector | `proxmox_zpool_*` |
| Mail | Mail ingest and per-agent mailbox | generic mail + SMTP receiver | `mail_message` |
| Mail | Mail staleness (>4d) | server-side messages API | `/api/messages/staleness` |
| PBS | Datastore/task/backup/verify/sync/gc freshness checks | pbs collectors | `pbs_*` |
| Storage | Generic zpool status summary (non-Proxmox) | generic collector | `generic_zpool_*` |
| Hardware | SMART health/temp/wear/powercycles | hardware collector | `hardware_smart_*` |
| Hardware | Samsung SSD inventory and firmware | hardware collector | `hardware_samsung_*` |
| Hardware | CPU/NVMe temps, PCIe errors, Intel GPU busy, VRAM usage | hardware collector | `hardware_temp_*`, `hardware_pcie_*`, `hardware_intel_gpu_*`, `hardware_gpu_vram_*` |
| Alerting | Webhook config status in GUI/API | console alert status endpoint | `/api/alerts/status` |

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
lumenmon-agent debug        # Run all collectors once (test output)
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

Two methods to receive system mail - use whichever fits your setup:

**Method 1: Local spool (Debian/Ubuntu)**
```
/var/mail/root → agent → MQTT → console
```
Agent automatically reads local mail spool every 5 minutes. Works out-of-the-box on systems where mail delivers to `/var/mail/root`.

**Method 2: SMTP (Proxmox/PBS)**
```
System notifications → SMTP (port 25) → console
```
Configure your system to send mail to `<agent_id>@<console-host>`. Works with Proxmox notification system.

Both methods store mail in the same messages table, displayed per-agent in the web UI.

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
MIN=0                  # Optional hard minimum (fail/red below)
MAX=100                # Optional hard maximum (fail/red above)
WARN_MIN=""           # Optional soft minimum (warn/yellow below)
WARN_MAX=""           # Optional soft maximum (warn/yellow above)

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # IMPORTANT: Use LC_ALL=C for commands that produce localized output
    value=$(LC_ALL=C some_command | parse_output)

    publish_metric "$METRIC" "$value" "$TYPE" "$BREATHE" "$MIN" "$MAX" "$WARN_MIN" "$WARN_MAX"
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
publish_metric "name" "value" "TYPE" interval [min] [max] [warn_min] [warn_max]
```

**Health Detection:**
- Values outside `min`/`max` show as **failed** (critical/red).
- Values outside `warn_min`/`warn_max` (but inside min/max) show as **warning** (degraded/yellow).

```bash
# Static bounds (percentages)
publish_metric "cpu" "$val" "REAL" "$PULSE" 0 100

# Dynamic bounds (ZFS: online must equal total drives)
publish_metric "zfs_online" "$online" "INTEGER" "$CYCLE" "$total" "$total"

# Warning before critical (Debian updates)
# 1..10 updates => warning, >10 => failed
publish_metric "debian_updates_total" "$total" "INTEGER" "$REPORT" 0 10 "" 0

# One-time metric (interval=0, never stale)
publish_metric "hostname" "$host" "TEXT" 0
```

**Categories:**
| Directory | Prefix | Purpose |
|-----------|--------|---------|
| `collectors/generic/` | `generic_` | Universal (CPU, memory, disk) |
| `collectors/proxmox/` | `proxmox_` | Proxmox (VMs, containers, ZFS) |
| `collectors/pbs/` | `pbs_` | Proxmox Backup Server checks |
| `collectors/hardware/` | `hardware_` | Real-hardware telemetry |
| `collectors/optional/` | `optional_` | Explicitly opt-in checks |

</details>

<details>
<summary>Development</summary>

### Local Development
```bash
./dev/auto         # Full reset and setup with virtual agent
./dev/add3         # Spawn 3 test agents
./dev/check-collectors  # Validate collector contract assumptions
./dev/sensor-inventory  # List current remote sensors and failed checks
./dev/sandboxer-maintain --once  # Run one auto-maintenance pass
./dev/lumenmon-diagnose  # End-to-end health/data-flow diagnosis
```

### Operational Checks (Current)

Use these commands as a complete fast-check list during development and direct deploy.

```bash
# Local script sanity
find . -name "*.sh" -type f -exec bash -n {} \;
./dev/check-collectors

# Console image sanity
docker build -t test-console:ci ./console

# E2E tests
cd dev/tests && npm test
cd dev/tests && npx playwright test lumenmon.spec.ts -g "Page Load & Initial State"

# Runtime status (local or remote)
lumenmon
lumenmon-agent

# Direct deploy + smoke checks
./dev/deploy-test agent
./dev/deploy-test console
./dev/deploy-test status
./dev/deploy-test check
```

### Optional Collector Config

Optional collectors are enabled via keys in `agent/data/config` (or `/opt/lumenmon/data/config` on host):

```ini
mullvad_active=1

# hardware collectors on virtual hosts (optional override)
hardware_force=0
```

### Alerting (Webhook Status Only)

Console exposes webhook alert configuration status in GUI and API:

- API: `GET /api/alerts/status`
- GUI footer: `alerts: not configured` / `alerts: webhook dry-run` / `alerts: active`

Current behavior is status-only scaffolding (no outbound webhook delivery yet).

### Mail Staleness (Server-side)

Mail staleness is evaluated in console backend from `messages.received_at`:

- API: `GET /api/messages/staleness?hours=96`
- Used by UI status warnings (`MAIL STALE > 4D`)
- This avoids agent-local spool heuristics and works for SMTP-only senders.

### CSS (Tailwind)
```bash
cd console && npm install   # First time setup
cd console && npm run dev   # Watch mode - auto-recompile on changes
cd console && npm run build # One-time build
```

### Remote Test Server
Deploy directly to a test server via SSH (bypasses GitHub Actions):
```bash
cp .env.example .env
# set LUMENMON_TEST_HOST in .env (gitignored)

export LUMENMON_TEST_HOST="root@your-test-server"  # optional shell override
./dev/deploy-test web      # Build CSS + hot reload frontend (~3s)
./dev/deploy-test agent    # Deploy agent + restart (~1s)
./dev/deploy-test console  # Full console + restart (~5s)
./dev/deploy-test status   # Check remote status
./dev/deploy-test check    # API/runtime smoke checks
```

### Releases
```bash
./dev/release      # Create version tag, triggers GitHub Actions build
```

GitHub Actions only builds Docker images on version tags (`v*`), not on every commit. This keeps the dev loop fast.

</details>

---

*Made with 🔆 by [chriopter](https://github.com/chriopter)*
