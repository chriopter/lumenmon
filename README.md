```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```
Lightweight system monitoring with MQTT transport. Pure push architecture — agents send metrics, the console never reaches into your systems. Run the console as a Docker container, add clients with one invite command, and get monitoring without dashboard config.

<img width="400" alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

## Quick Start

**Console** (central dashboard):
```bash
mkdir -p lumenmon-console
cd lumenmon-console
curl -fsSLO https://raw.githubusercontent.com/chriopter/lumenmon/main/console/docker-compose.yml
printf 'CONSOLE_HOST=%s\n' "$(hostname -f 2>/dev/null || hostname)" > .env
docker compose up -d
```

Open `http://<console-host>:8080`, then create an invite from the UI or run:

```bash
docker exec lumenmon-console /app/core/enrollment/invite_create.sh
```

**Agent** (on each monitored host):
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash
lumenmon-agent register '<invite-url>'
lumenmon-agent start
```

## Architecture

```
┌─────────────┐  MQTT/TLS     ┌─────────────┐
│   Agent     │──────────────►│   Console   │──► Web :8080
├─────────────┤               ├─────────────┤
│ Collectors  │               │ • MQTT 8884 │
│ Mail spool  │               │ • SMTP 25   │◄── Direct mail
└─────────────┘               │ • Rails 8   │
  (bare metal)                │ • SQLite    │
                              └─────────────┘
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

<details>
<summary>Generic (all Linux systems)</summary>

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

</details>

<details>
<summary>Debian/Ubuntu</summary>

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `updates` | `debian_updates_total`, `debian_updates_security`, `debian_updates_release`, `debian_updates_age` | 1h (`REPORT`) | total/security only warn after updates are pending for >=24h; release >0 stays critical |

</details>

<details>
<summary>Proxmox VE</summary>

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `vms` | `proxmox_vms_*` | 5m (`CYCLE`) | stale only |
| `containers` | `proxmox_containers_*` | 5m (`CYCLE`) | stale only |
| `storage` | `proxmox_storage_*` | 5m (`CYCLE`) | stale + bounds if configured |
| `zfs` | `proxmox_zfs_*` | 5m (`CYCLE`) | stale + bounds (online drives vs total) |
| `zpool_health` | `proxmox_zpool_*` | 5m (`CYCLE`) | degraded and upgrade-needed flags (`max=0`) |

</details>

<details>
<summary>Proxmox Backup Server (PBS)</summary>

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `datastore_count` | `pbs_datastore_count` | 5m (`CYCLE`) | fails when no datastore is detected |
| `task_failures` | `pbs_task_failures_24h` | 5m (`CYCLE`) | fails when errors/failures > 0 in last 24h |
| `backup_age` | `pbs_backup_age_hours` | 5m (`CYCLE`) | fails when age exceeds 24h |
| `verify_age` | `pbs_verify_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |
| `sync_age` | `pbs_sync_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |
| `gc_age` | `pbs_gc_age_hours` | 5m (`CYCLE`) | fails when age exceeds 168h |

</details>

<details>
<summary>Hardware (real hosts)</summary>

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `temp` | `hardware_temp_*` | 5m (`CYCLE`) | fails on temperature thresholds; negative sensor glitches are clamped to 0 |
| `pcie_errors` | `hardware_pcie_*` | 1h (`REPORT`) | fails on PCIe/AER errors |
| `intel_gpu` | `hardware_intel_gpu_*` | 5m (`CYCLE`) | fails on Intel GPU utilization thresholds |
| `vram` | `hardware_gpu_vram_*` | 5m (`CYCLE`) | fails on VRAM usage thresholds |
| `smart_values` | `hardware_smart_*` | 1h (`REPORT`) | fails on SMART health/temp/wear thresholds |
| `ssd_samsung` | `hardware_samsung_*` | 1h (`REPORT`) | inventory/firmware visibility for Samsung SSDs |

Note: on virtualized guests, hardware collectors stay disabled by default. If GPU passthrough is detected, `hardware_intel_gpu` and `hardware_vram` are enabled automatically.

</details>

<details>
<summary>Optional</summary>

| Collector | Publishes | Interval | Failure behavior |
|-----------|-----------|----------|------------------|
| `mullvad_active` | `optional_mullvad_active` | opt-in | stale/bounds depend on local config |

</details>

## Dev / Architecture / Operations

Lumenmon is a push-only monitor: agents connect outbound over MQTT/TLS, the console stores latest state in SQLite, and Rails renders the UI on `8080`.

<details>
<summary>Console</summary>

One Docker container runs Rails 8, Caddy, Mosquitto, MQTT ingest, SMTP receive, and SQLite. Persist `./data:/data`; MQTT/TLS listens on `8884`, SMTP on `25`.

```bash
docker compose up -d
docker compose logs -f
docker compose pull && docker compose up -d
docker exec lumenmon-console /app/core/status.sh
docker exec lumenmon-console /app/core/enrollment/invite_create.sh
```

</details>

<details>
<summary>Agent</summary>

Bash collectors publish metrics with `mosquitto_pub` over TLS. The installer uses `/opt/lumenmon/`, creates `lumenmon-agent.service`, and installs the CLI.

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/agent/install.sh | bash
lumenmon-agent register '<invite-url>'
lumenmon-agent start
lumenmon-agent logs
lumenmon-agent debug
```

</details>

<details>
<summary>Security</summary>

- Agents connect outbound only.
- MQTT uses TLS and per-agent credentials.
- Invites create individual MQTT users.
- Do not expose Rails directly; put public HTTPS in front of `8080` with a reverse proxy.

</details>

<details>
<summary>Data and UI</summary>

Rails owns `/data/lumenmon.sqlite3`.

```text
agent collector -> Mosquitto :8884 -> Ruby MQTT ingest -> ActiveRecord -> metric_samples
```

`metric_samples` stores latest values by `agent_id` + `metric_name`; observation history is kept for seven days. Status uses stale intervals and bounds: `fail`, `warn`, `stale`.

Mail is stored in `messages` and shown host-scoped. It can arrive through agent local-spool forwarding (`mail_message` over MQTT) or direct SMTP delivery to `<agent_id>@<console-host>` for systems that cannot run an agent.

</details>

<details>
<summary>Custom collectors</summary>

Custom collectors are Bash scripts in `agent/collectors/` and publish through:

```bash
publish_metric "name" "value" "TYPE" interval [min] [max] [warn_min] [warn_max]
```

Use `REAL`, `INTEGER`, or `TEXT`. Use `LC_ALL=C` when parsing command output. Prefix metrics by collector family: `generic_`, `proxmox_`, `pbs_`, `hardware_`, or `optional_`.

</details>

<details>
<summary>Local dev</summary>

```bash
./dev/console
./dev/console --reset
./dev/auto
./dev/quality
./dev/update
```

Rails/Tailwind work happens in `console/`. Release tags (`v*`) trigger the GitHub Actions container build.

</details>

---

*Made with 🔆 by [chriopter](https://github.com/chriopter)*
