# Lumenmon “Simple Mode” Design Notes (SSH + TSV + TUI)

A minimal, write-light pipeline without HTTP or SQLite. Uses SSH for transport, TSV for data, tmpfs for live state, and cron for periodic flush and retention.

## Goals
- Simpler, fewer moving parts; easy to debug with plain files.
- Low SSD wear: hot data in RAM; cold data flushed in batches.
- Good UX: fast TUI that reads small “latest” snapshots and short sliding windows.

## High-Level Flow
1) Collector (client): Bash collectors → TSV lines → buffer in `/dev/shm` → send via SSH (persistent or batched every minute).
2) Receiver (server): SSH forced-command appender writes to per-minute buckets in tmpfs and updates a per-host latest env.
3) Flusher (server): Minutely cron appends the current minute bucket to per-day, per-host spool on SSD and rotates the RAM bucket.
4) Viewer (TUI): Reads `/var/lib/lumenmon/hot` (RAM) for live graphs; reads `/var/lib/lumenmon/latest/<host>.env` for gauges; 5s refresh.
5) Maintenance: Nightly gzip yesterday’s spools, keep 7 days, delete older.

## Data Model & Formats
- TSV fields: `ts_utc\thost\tmetric\ttype\tvalue\tinterval`
  - Example: `1726312205\tweb-01\tcpu_usage\tfloat\t37.5\t1`
- Latest env (per host): KEY=VALUE lines, safe to source in shell.
  - Keys are UPPERCASE + sanitized (non `[A-Z0-9_]` → `_`; if starts with digit, prefix `_`).
  - Numbers unquoted; strings double-quoted and escaped.
  - Always include: `HOST`, `LAST_SEEN` (epoch), optionally `UPDATED_AT` (ISO8601).
  - Example:
    - `HOST=web-01`
    - `LAST_SEEN=1726312205`
    - `GENERIC_CPU_USAGE=37.5`
    - `GENERIC_NETWORK_PRIMARY_IP="10.0.1.23"`

## Storage Tiers & Layout
- Hot (RAM, tmpfs): `/var/lib/lumenmon/hot`
  - Minute buckets: `/var/lib/lumenmon/hot/minutes/YYYY-MM-DD/HH/MM/<host>.tsv`
  - Latest env: `/var/lib/lumenmon/hot/latest/<host>.env` (atomic mv updates)
  - Optional hot rings for charts: `/var/lib/lumenmon/hot/ring/<host>/<metric>.tsv` (e.g., last 120–300 points)
- Warm/Cold (SSD): `/var/lib/lumenmon/spool/YYYY-MM-DD/<host>.tsv` (append-only, gzip daily)
- Recommended tmpfs mount: `tmpfs /var/lib/lumenmon/hot tmpfs size=512m,mode=0755 0 0`

## End-to-End Components

### Collector (client)
- Collectors output TSV lines locally to `/dev/shm/lumenmon/buffer.tsv`.
- Every minute (or via a persistent stream), batch-send over SSH.
- Sketch:
  - Append helper: `printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%s)" "$HOST" "$NAME" "$TYPE" "$VAL" "$INTERVAL" >> "$BUFFER"`
  - Flush step:
    - `mv buffer.tsv batch-$(date +%s).tsv`
    - `ssh -i /etc/lumenmon/id_rsa -oBatchMode=yes metrics@server \
       '/usr/local/bin/lumenmon-append --host "$HOSTNAME"' < batch-*.tsv`
    - On success, remove the batch file; on failure, requeue.
- Performance tip: use a persistent SSH (`ssh -NT`) or ControlMaster to avoid per-minute handshakes; for 1 Hz live data, stream continuously.

### Receiver (server, forced command)
- Program: `/usr/local/bin/lumenmon-append` (shell or small Go/Python) reads stdin lines, validates, and writes to tmpfs minute buckets.
- Ignores TSV `host` field; trusts `--host` provided via `authorized_keys` forced-command.
- For each line: stamp server UTC, sanitize fields, route to current minute file, and update latest env atomically.
- Example filesystem ops:
  - `DATE=$(date -u +%F)`; `YYYY=$(date -u +%Y)`; `HH=$(date -u +%H)`; `MM=$(date -u +%M)`
  - `mkdir -p /var/lib/lumenmon/hot/minutes/$DATE/$HH/$MM`
  - Append to `/var/lib/lumenmon/hot/minutes/$DATE/$HH/$MM/$HOST.tsv`
  - Update `/var/lib/lumenmon/hot/latest/$HOST.env.tmp` → sanitize to KEY=VALUE → `mv` to `.env`
- Optional: also maintain small `/var/lib/lumenmon/hot/ring/<host>/<metric>.tsv` for quick charts.

### Flusher (server, cron every minute)
- For each host with a current minute file, append to spool with `flock` and remove the minute file.
- Paths:
  - Source (RAM): `/var/lib/lumenmon/hot/minutes/YYYY-MM-DD/HH/MM/<host>.tsv`
  - Dest (SSD): `/var/lib/lumenmon/spool/YYYY-MM-DD/<host>.tsv`
- Pseudocode:
  - `mkdir -p "/var/lib/lumenmon/spool/$DATE"`
  - `exec flock -x "/var/lib/lumenmon/spool/$DATE/$HOST.tsv.lock" -c "cat src.tsv >> dest.tsv"`
  - Optionally snapshot latest env from RAM to SSD once/min for reboot continuity.

### Viewer (TUI)
- Bash + `tput`/`dialog`, 5s refresh.
- Reads `/var/lib/lumenmon/hot/latest/*.env` and, for charts, tails recent minute buckets (or reads hot rings).
- Online status: `now - LAST_SEEN < 30` → ONLINE.
- Overview: 20 hosts × CPU/MEM sparklines + gauges. Detail view: more metrics and top processes.

## Practical Touches
- Trust source identity: don’t rely on TSV `host`.
  - In `authorized_keys`, pin host identity into forced-command:
    - `command="/usr/local/bin/lumenmon-append --host client-alpha",no-pty,no-agent-forwarding,no-X11-forwarding,no-port-forwarding ssh-rsa AAA...`
  - The appender ignores TSV host and uses `--host`.
- Atomic latest writes:
  - Write to `/var/lib/lumenmon/hot/latest/<host>.env.tmp` then `mv` to `.env`.
  - Readers don’t need locks; rename is atomic.
- Format
  - TSV: `epoch_utc  host  metric  type  value  interval`
  - Latest env keys: uppercase sanitized metric names, e.g., `GENERIC_CPU_USAGE=37.5`
  - Include `LAST_SEEN=<epoch>` per host for online/offline checks.
- Rate control
  - Batch to RAM; flush to SSD once/min to minimize wear.
  - For 1 Hz live graphs: keep persistent SSH streams and RAM buckets; TUI reads RAM only.

## Security Hardening
- `authorized_keys` forced-command, no-pty, no-port-forwarding, no-agent-forwarding, no-X11.
- Validate and sanitize all fields; reject overly long lines; allowlist metric name charset.
- Directory permissions: `0755` dirs, latest env files `0644` (or `0640` with group).
- Path safety: never derive paths from unsanitized input; only from trusted `--host` and server time.
- Resource limits: ulimits, rate limits per connection if needed.

## Performance & Wear Budget (example: 20 hosts × 10 metrics × 1 Hz)
- Live writes: ~200 lines/s to RAM (~16–25 KB/s total) → trivial.
- SSD writes: ~1 append/host/min to spools (~1 MB/min total typical) → very low wear.
- RAM for last hour: O(60–120 MB). Size tmpfs to 256–512 MB.
- TUI rendering: overview reads 20×2 short series; detail reads 8–10 series → smooth at 5 Hz.

## Dependencies
- Server: `openssh-server`, `util-linux` (flock), `gzip`, `awk`, `coreutils`, `cron` (or systemd timer), optional `dialog`.
- Client: `openssh-client`, `bash`/`sh`, `awk`, standard collector deps (`top`, `ps`, `df`, etc.).
- Docker: mount tmpfs for `/var/lib/lumenmon/hot` if containerized.

## Implementation Sketch
- Server scripts
  - `/usr/local/bin/lumenmon-append` (forced command): reads stdin, writes minute bucket + latest env (RAM).
  - `/usr/local/bin/lumenmon-flush` (cron `* * * * *`): RAM minute → SSD spool with `flock`; rotate RAM file.
  - `/usr/local/bin/lumenmon-rotate` (daily cron): gzip yesterday’s spools; purge > 7 days.
  - `/usr/local/bin/lumenmon-tui` (optional): renders overview/detail from RAM.
- Client scripts
  - `/usr/local/bin/lumenmon-flush-client` (minutely or persistent): send buffer via SSH or keep stream.
  - Reuse existing collectors; add a small TSV adapter.
- Example `authorized_keys` entry
  - `command="/usr/local/bin/lumenmon-append --host client-alpha",no-pty,no-agent-forwarding,no-X11-forwarding,no-port-forwarding ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... client-alpha`
- Example crontab
  - `* * * * * root /usr/local/bin/lumenmon-flush`
  - `0 2 * * * root /usr/local/bin/lumenmon-rotate`

## Alternative: Netcat Receiver (not preferred)
- `nc -lk 9999` → append to `/var/lib/lumenmon/spool/YYYY-MM-DD/<host>.tsv` under `flock`.
- Downsides: open port, weaker auth, portability quirks (`-k`, `-e`), no identity pinning, brittle under concurrency. SSH forced-command is safer.

## Tradeoffs vs HTTP + SQLite
- Pros: fewer services, smaller footprint, easier to debug (cat files), resilient with local buffering.
- Cons: no ad-hoc queries/JOINs; rollups handled by scripts; very large fleets may need sharding or later DB ingestion.
- Scale knob: per-host files + “today only” processing → O(hosts) per cycle, not O(history).

## Why this works
- Clear split between hot (RAM) and cold (disk) avoids re-scans and reduces wear.
- Minute sharding gives precise, cheap reads for any window.
- Archives stay as TSV, future‑proof for bulk import if a DB is added later.

---

## Final Plan (5 Lines — Preferred / SSH)
1. Collector: Bash → TSV → buffer in `/dev/shm` → SSH (persistent or minutely batch) to server.
2. Receiver: SSH forced-command appender → write per-minute buckets to `/var/lib/lumenmon/hot/minutes` and update `/var/lib/lumenmon/hot/latest/<host>.env` atomically.
3. Processor: Cron every minute → append RAM minute files to `/var/lib/lumenmon/spool/YYYY-MM-DD/<host>.tsv` with `flock` → rotate RAM minute.
4. Viewer: TUI with `tput`/`dialog` → read RAM latest/rings → live bars/graphs with 5s refresh.
5. Maintenance: Nightly gzip yesterday’s spools → keep 7 days → delete older.

## Final Plan (5 Lines — Alternative / Netcat)
1. Collector: Bash → TSV → buffer in `/dev/shm` → netcat batch send every minute.
2. Receiver: `nc -lk 9999` → append to `/var/lib/lumenmon/spool/YYYY-MM-DD/<host>.tsv` with `flock`.
3. Processor: Cron every minute → derive `/var/lib/lumenmon/latest/<host>.env` for quick reads.
4. Viewer: TUI reads latest files over SSH; show bars/graphs; 5s refresh.
5. Maintenance: Nightly gzip → keep 7 days → delete older.

