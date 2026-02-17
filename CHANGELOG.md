# Changelog

## 2026-02-17

### Health, Deploy, and API/UI compatibility hardening

- Fixed host health rollup so out-of-bounds metrics propagate to entity status (not only stale metrics).
- Fixed detail-table compatibility by restoring typed value fields (`value_real`, `value_int`, `value_text`) alongside canonical `value`.
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
