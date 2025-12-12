# Collector Development Guide

Collectors are bash scripts that gather metrics and publish them via MQTT.

## Standard Structure

```bash
#!/bin/bash
# Brief description of what this collector does.
# Additional details about data source or calculation method.

# Config
RHYTHM="PULSE"         # Timing: PULSE(1s), BREATHE(10s), CYCLE(60s), REPORT(3600s)
METRIC="generic_cpu"   # Metric name (prefix with category)
TYPE="REAL"            # Data type: REAL, INTEGER, TEXT
MIN=0                  # Optional: minimum valid value
MAX=100                # Optional: maximum valid value

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Collect your metric value here
    value="42.0"

    # Publish with interval and optional bounds
    publish_metric "$METRIC" "$value" "$TYPE" "$RHYTHM_VAR" "$MIN" "$MAX"

    sleep $RHYTHM_VAR
done
```

## Configuration Variables

| Variable | Description |
|----------|-------------|
| `RHYTHM` | Timing category for agent.sh to manage (not used at runtime) |
| `METRIC` | Metric name, prefixed with category (e.g., `generic_`, `proxmox_`) |
| `TYPE` | SQLite column type: `REAL` (decimals), `INTEGER` (whole numbers), `TEXT` (strings) |
| `MIN` | Optional minimum valid value (for health detection) |
| `MAX` | Optional maximum valid value (for health detection) |

## Timing Constants (from agent.sh)

| Constant | Interval | Use Case |
|----------|----------|----------|
| `$PULSE` | 1s | High-frequency metrics (CPU) |
| `$BREATHE` | 10s | Medium-frequency (memory, heartbeat) |
| `$CYCLE` | 60s | Low-frequency (disk, ZFS) |
| `$REPORT` | 3600s | Rarely changing (hostname, version) |

## publish_metric Function

```bash
publish_metric "metric_name" "value" "TYPE" "interval" ["min"] ["max"]
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| metric_name | Yes | Name of the metric |
| value | Yes | The value to publish |
| TYPE | Yes | `REAL`, `INTEGER`, or `TEXT` |
| interval | Yes | Update interval in seconds (use timing variable) |
| min | No | Minimum valid value (for bounds checking) |
| max | No | Maximum valid value (for bounds checking) |

## Health Detection (Min/Max Bounds)

Values outside min/max bounds trigger **failed** state in the dashboard.

### Static Bounds
For percentage metrics:
```bash
MIN=0
MAX=100
publish_metric "$METRIC" "$value" "REAL" "$CYCLE" "$MIN" "$MAX"
```

### Dynamic Bounds
For relative metrics (e.g., ZFS online drives):
```bash
total_drives=4
online_drives=3
# min=max=total, so online < total triggers failure (degraded pool)
publish_metric "zfs_pool_online" "$online_drives" "INTEGER" "$CYCLE" "$total_drives" "$total_drives"
```

## One-Time Metrics

For values that never change (hostname, version), use interval `0`:
```bash
publish_metric "generic_hostname" "$hostname" "TEXT" 0
```
This marks the metric as "once" and it won't be flagged as stale.

## Examples

### Simple Percentage Metric
```bash
publish_metric "generic_cpu" "42.5" "REAL" "$PULSE" 0 100
```

### Integer Counter
```bash
publish_metric "proxmox_vms_running" "5" "INTEGER" "$CYCLE"
```

### Text Value
```bash
publish_metric "generic_hostname" "server01" "TEXT" "$REPORT"
```

### Dynamic Health Check
```bash
# Fails if online < total (degraded state)
publish_metric "zfs_rpool_online" "$online" "INTEGER" "$CYCLE" "$total" "$total"
```

## Directory Structure

```
collectors/
├── generic/          # Universal metrics (CPU, memory, disk)
│   ├── cpu.sh
│   ├── memory.sh
│   ├── disk.sh
│   ├── hostname.sh
│   └── heartbeat.sh
├── proxmox/          # Proxmox-specific metrics
│   ├── _init.sh      # Category init (optional)
│   ├── vms.sh
│   ├── containers.sh
│   ├── storage.sh
│   └── zfs.sh
└── README.md
```

## Best Practices

1. **Prefix metrics** with category (`generic_`, `proxmox_`, `docker_`)
2. **Set bounds** for numeric metrics to enable health detection
3. **Use appropriate timing** - don't poll faster than needed
4. **Handle missing commands** gracefully (check with `command -v`)
5. **Use `set -euo pipefail`** for safer bash scripts
