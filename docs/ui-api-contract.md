# UI/API Contract Notes

This is a lightweight compatibility guide for the dashboard UI and unified API.
Use it during refactors to avoid silent frontend breakage.

## Entities API (`GET /api/entities`)

For agent rows, the UI expects these fields to exist:

- `id` (string, `id_<hex...>`)
- `type` (`agent` or `invite`)
- `status` (`online`, `degraded`, `offline`, `mail-only`)
- `valid` (boolean)
- `display_name` (optional string)
- `hostname` (display hostname)
- `original_hostname` (raw hostname when present)
- `group` (optional string)
- `failed_collectors` (int)
- `total_collectors` (int)
- `cpu`, `memory`, `disk` (numbers)
- `cpuSparkline`, `memSparkline`, `diskSparkline` (strings)
- `cpuHistory`, `memHistory`, `diskHistory` (arrays)
- `mail_only` (boolean compatibility alias)
- `is_mail_only` (boolean canonical field)
- `pending_invite` (optional object)

Notes:
- Keep both `mail_only` and `is_mail_only` for compatibility.
- If bounds/staleness logic changes, ensure `status` still rolls up metric failures.

## Agent Tables API (`GET /api/agents/<agent_id>/tables`)

Each table entry should include:

- `metric_name`
- `columns` object:
  - `timestamp`
  - `value` (canonical)
  - `value_real`, `value_int`, `value_text` (compat fields)
  - `interval`, `min_value`, `max_value`
- `staleness` object:
  - `age`
  - `is_stale`
  - `next_update_in`
- `health` object:
  - `is_failed`
  - `is_stale`
  - `out_of_bounds`
  - `bounds_error`
- `metadata` object:
  - `type`
  - `timestamp_age`
  - `data_span`
  - `line_count`
- `history` array

Notes:
- Frontend detail table still renders legacy typed columns; do not remove `value_real/value_int/value_text` without frontend migration.

## Known footguns

- Changing field names in unified API without updating `console/web/public/html/*.html` can render `-` values while health still fails.
- `console/core/status.sh` online count should prefer unified API over raw SQLite timestamps (SQLite is persisted in batches).
- Invite rows should open detail view; avoid frontend calls to non-existent invite retrieval endpoints.
