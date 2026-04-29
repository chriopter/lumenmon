# Changelog

## v1.16.0 — 2026-03-24

### MQTT Spool-Queue (agent-side buffering)

- Added local spool-queue to `agent/core/mqtt/publish.sh`: failed publishes are buffered to `$LUMENMON_DATA/mqtt/spool.jsonl` and replayed on next successful publish.
- Spool file is bounded to 1000 entries (oldest dropped when exceeded).
- Ensures no metric data is lost during broker restarts or network outages.

### Reconnect-Aware Collector Triggering

- Added background MQTT connection monitor to `agent/agent.sh` that pings the broker every 30 seconds.
- On DOWN→UP transition, writes `$LUMENMON_DATA/mqtt/reconnected` trigger file.
- Long-interval collectors (e.g., `debian/updates.sh` with REPORT=3600s) check for the trigger file and run immediately on reconnect instead of waiting up to 1 hour.
- Prevents stale update sensor data after server restarts.

### Intel nvtop GPU Monitoring

- Added `nvtop` as a fallback GPU utilization source in `agent/collectors/hardware/intel_gpu.sh`.
- Priority chain is now: `intel_gpu_top` (JSON) → `intel_gpu_top` (text) → `nvtop` → sysfs.
- Captures nvtop TUI output via `script(1)` and parses GPU busy percentage.

## 2026-02-17

### Health, Deploy, and API/UI compatibility hardening

- Fixed host health rollup so out-of-bounds metrics propagate to entity status (not only stale metrics).
- Fixed detail-table rendering by aligning the API response with the dashboard value contract.
- Added missing API fields used by detail UI (`staleness.next_update_in`, `metadata.data_span`) to prevent misleading table output.
- Normalized MQTT TLS certificate fingerprints (strip separators + uppercase) to avoid false mismatch warnings.
- Unified MQTT port handling end-to-end (register, status, publish path, collectors, runtime) with backward-compatible `8884` fallback.
- Hardened messages API limit parsing with bounded validation and proper `400` responses on invalid input.
- Refactored direct deploy tooling:
  - `dev/deploy-test` now uses strict mode, env loading, preflight checks, and cleaner target flow.
  - `deploy.sh` now delegates to `dev/deploy-test` for safer direct deploy behavior.
- Fixed frontend invite interaction path by removing callsites to non-existent invite URL endpoint and opening detail view consistently.
- Improved console status online detection by preferring unified API entity status with SQLite fallback.

### Documentation

- Expanded `AGENTS.md` with direct deploy strategy and environment-driven host configuration guidance.
- Improved README collector section readability (publishes/interval/failure behavior and health rollup explanation).
- Added `docs/ui-api-contract.md` to document frontend/backend field expectations and known compatibility footguns.
- Removed stale `CLAUDE.md`.
