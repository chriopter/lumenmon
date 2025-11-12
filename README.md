```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ██╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

Lumenmon connects **Glances** monitoring from multiple machines to a web dashboard.

**Lumenmon Console:** 30-second install—Docker container with MQTT broker + Flask web UI (any OS with Docker)
**Monitored Servers:** One-line command—auto-configures Glances with MQTT export + TLS certificate pinning (Ubuntu, Debian, Arch, Manjaro)

*Note: Glances works on any OS, but the auto-installer script only supports the distros listed above. Manual Glances setup works everywhere.*

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/refs/heads/main/install.sh | bash
```

The installer sets up the console. Run `lumenmon invite` to add monitored servers.

<img width="700"  alt="image" src="https://github.com/user-attachments/assets/6e9a1e4c-59ca-4b34-bfa5-269ab3f99b37" />

<details>
<summary>Commands</summary>

```bash
lumenmon            # Show status and available commands
lumenmon invite     # Generate invite to connect Glances on other servers
lumenmon logs       # Stream container logs
lumenmon update     # Update console
lumenmon uninstall  # Remove everything
```
</details>

## How It Works

**Glances** (installed on monitored servers) collects 150+ metrics and publishes to **Lumenmon Console** via MQTT.

**Console** (Docker container) receives metrics via MQTT broker, stores in SQLite, and serves a web dashboard.

```
┌─────────────┐               ┌─────────────┐
│  Glances    │──────────────►│   Console   │
├─────────────┤  MQTT/TLS     ├─────────────┤
│ • CPU       │──────────────►│ • MQTT 8884 │──► Web Dashboard
│ • Memory    │  150+ Metrics │ • SQLite DB │
│ • Disk, Net │               │ • WebTUI    │
└─────────────┘               └─────────────┘
```

<details>
<summary>Architecture, Data Flow & Security</summary>

### Architecture

**Glances** (system package on monitored servers):
- Installed via `apt install glances` or similar
- Configured with MQTT export to console
- Collects 150+ metrics every 3 seconds

**Console** (Docker container):
- MQTT broker (port 8884) receives metrics
- SQLite database stores time-series data
- Flask web dashboard (port 8080)

### Data Flow

1. Glances collects metrics (CPU, memory, disk, etc.)
2. Publishes to MQTT: `metrics/id_abc123/hostname/cpu/total`
3. Console gateway writes to SQLite table
4. Dashboard queries and displays real-time data

**Storage:** One SQLite table per metric. Schema: `(timestamp, value, interval)`

**Retention:** Automatic 7-day cleanup (runs daily at 3 AM)

### Security

- **TLS:** All MQTT connections use TLS with certificate pinning
- **Auth:** Per-agent MQTT credentials (32-char random passwords)
- **ACL:** Agents can only write to their own topic namespace
- **Network:** Outbound-only from Glances to console (firewall-friendly)

<img width="700" alt="Dashboard" src="https://github.com/user-attachments/assets/2e67ead2-e5ce-4291-80d1-db08f7dd6ee7" />

</details>

<details>
<summary>Development</summary>

```bash
# Start console + 1 Glances agent with clean database
./dev/auto

# Add 3 more Glances agents for testing
./dev/add3

# Reset all data/databases (keeps containers running)
./dev/reset-data

# Create git tag and trigger release (e.g., v0.13 → v0.14)
./dev/git-tag-release

# Update vendored CSS/JS dependencies (Chart.js, etc.)
./dev/update-vendor-deps
```

**Dev scripts:**
- `./dev/auto` - Full setup: console + agent with clean DB (~25s)
- `./dev/add3` - Add 3 test agents for multi-agent testing (~20s)
- `./dev/reset-data` - Clear all data/DB for fresh testing
- `./dev/git-tag-release` - Bump version and push git tag
- `./dev/update-vendor-deps` - Update Chart.js and other vendors

All scripts are inline bash (no lib files) - just open and read them!

</details>

---

**Powered by:** Glances • MQTT • SQLite • Flask • Docker • WebTUI
