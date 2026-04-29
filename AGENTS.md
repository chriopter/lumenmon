# AGENTS.md
Guide for coding agents working in `lumenmon`.
Focus: build/lint/test commands and practical code conventions.

## Repository Layout
- `console/`: Dockerized Rails 8 console (Rails API/UI, Mosquitto, Caddy, SQLite).
- `agent/`: Bash collectors and MQTT publishing runtime.
- `dev/`: local automation, deployment helpers, Playwright E2E tests.
- Languages: Bash, Ruby, JavaScript, TypeScript.

## Build, Lint, and Test Commands

### Core dev commands (repo root)
- `./dev/console` - live-edit console dev server (Rails, Mosquitto, MQTT ingest, Tailwind watch).
- `./dev/console --reset` - clear local console data before starting.
- `./dev/auto` - full local demo stack: starts `./dev/console --reset`, then three test agents.
- `./dev/quality` - run local validation, including collector contract checks.
- `./dev/update` - refresh dependencies and run the quality gate.

### Frontend CSS (Tailwind v4)
Run in `console/`:
- `npm install`
- `npm run build`
- `npm run dev`
Files:
- Source: `console/app/assets/tailwind/application.css`
- Output: `console/app/assets/stylesheets/application.css` (generated)

### Console image build
- `docker build -t test-console:ci ./console`

### CI lint/static checks currently used
No dedicated lint config found (no ruff/eslint/shellcheck config files).
Current checks are:
- `find . -name "*.sh" -type f -exec bash -n {} \;`
- `docker build -t test-console:ci ./console`
- Optional local guard: `./dev/quality`

### Playwright E2E tests
Run in `dev/tests/`:
- `npm install`
- `npm test`
- `npm run test:headed`
- `npm run test:ui`
- `npm run test:debug`
- `npm run report`
Optional target URL:
- `LUMENMON_TEST_URL=http://localhost:8080 npm test`

### Running a single test (important)
From `dev/tests/`:
- Single spec file: `npx playwright test lumenmon.spec.ts`
- Single test title pattern: `npx playwright test -g "loads dashboard within 3 seconds"`
- Single test in a file: `npx playwright test lumenmon.spec.ts -g "Page Load & Initial State"`
- Explicit project: `npx playwright test --project=chromium -g "status dot indicates agent state"`

### Single shell script validation
- `bash -n agent/collectors/generic/cpu.sh`

### Runtime sanity commands
- `lumenmon`
- `lumenmon logs`
- `lumenmon-agent`
- `lumenmon-agent logs`

## Code Style Guidelines

### Cross-cutting rules
- Keep diffs minimal; avoid unrelated refactors.
- Follow existing style in each file/directory.
- Prefer readable explicit code over clever compact code.
- Use ASCII unless a file already requires Unicode.
- Never commit secrets, real hostnames, or credentials.

### Bash conventions
- Shebang: `#!/bin/bash`.
- Add two short header comment lines under shebang (purpose + key behavior).
- Common safety flags: `set -euo pipefail` (some dev scripts use `set -e`; preserve local pattern).
- Quote expansions: `"$VAR"`.
- Use uppercase env/constant names (`LUMENMON_HOME`, `PULSE`, `BREATHE`).
- Use helper functions for repeated command blocks.
- When parsing command output, prefer `LC_ALL=C` for locale-stable output.
- Collectors should publish via `publish_metric` from `agent/core/mqtt/publish.sh`.
- Collectors must support test mode for `lumenmon-agent status`:
  - `[ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0`
- Collector naming prefixes:
  - `generic_*` (all Linux)
  - `debian_*` (Debian/Ubuntu)
  - `proxmox_*` (Proxmox)
  - optional collectors are opt-in

### Ruby/Rails conventions
- Keep controllers thin and helper/model logic straightforward.
- Naming: `snake_case` for methods/vars, `CamelCase` for classes/modules.
- Use ActiveRecord query APIs for value inputs; validate dynamic identifiers before use.
- API responses should return JSON with `render json:` and clear status codes (`400`, `404`, `500`).
- Keep client-facing error payloads generic; log internals server-side.

### JavaScript/TypeScript conventions
- Keep dashboard code modular and colocated with the Rails/Tailwind view when possible.
- Prefer descriptive names for UI/data state.
- Use semicolons consistently.
- Preserve file-local formatting:
  - `dev/tests/*.ts`: 2-space indent, single quotes.
  - Rails inline dashboard scripts: 4-space indent, single quotes.
- Avoid formatter-only churn unless requested.

### Types and contracts
- Metric payload contract fields: `value`, `type`, `interval`, optional `min`, `max`.
- Collector `TYPE` values: `REAL`, `INTEGER`, `TEXT`.
- Use `min`/`max` when a metric should drive health-state detection.
- Mail staleness is server-side (`/api/messages/staleness`, default 14 days / 336h) and should stay warning-only unless explicitly changed.
- Frontend mail widget must stay host-scoped (no cross-host/global fallback when selected host has no messages).
- Frontend collector summary legend: `total`, `fail`, `warn`, `stale`.
- Agent ID pattern used by APIs: `id_<hex...>`.
- Rails stores latest metric values in `metric_samples` keyed by `agent_id` + `metric_name`.

### Error handling and logging
- Shell: emit actionable warnings to stderr; keep non-critical failures non-fatal when possible.
- Rails: log internals server-side, keep API error payloads generic.
- Preserve security checks around input validation and SQL construction.

## Security-Sensitive Expectations
- Do not weaken TLS/certificate pinning related behavior.
- Do not loosen validation around `agent_id`, `metric_name`, or table identifiers.
- Do not hardcode MQTT credentials or infrastructure-specific secrets.
- Do not commit production hostnames; keep deployment host config in gitignored env files.

## Cursor/Copilot Rules Check
Checked for:
- `.cursorrules`
- `.cursor/rules/`
- `.github/copilot-instructions.md`
Result: none of these files currently exist in this repo.

## Recommended Agent Workflow
- Read touched files first and mirror local conventions.
- After edits, run the smallest command set that validates your change.
- Prefer local validation with `./dev/quality` during active development.
- Do not push commits unless explicitly asked.

## UI/API Contract Notes
Use this contract during dashboard/API refactors to avoid silent frontend breakage.

### Entities API (`GET /api/entities`)
For agent rows, the UI expects these fields:
- `id` (string, `id_<hex...>`)
- `type` (`agent`)
- `status` (`online`, `stale`, `offline`)
- `valid` (boolean)
- `hostname` (display hostname)
- `display_name` (display hostname)
- `last_seen` (unix timestamp)
- `failed_collectors` (int)
- `total_collectors` (int)
- `warning_collectors` (int)
- `cpu`, `memory`, `disk`, `heartbeat` (latest values)
- `metrics` (array with `name`, `value`, `data_type`, `interval`, `timestamp`, optional bounds)
- `pending_invite` (optional object)

If bounds or staleness logic changes, ensure `status` still rolls up metric failures.

### Agent Tables API (`GET /api/agents/<agent_id>/tables`)
Each table entry should include:
- `metric_name`
- `columns.timestamp`
- `columns.value`
- `columns.data_type`
- `columns.interval`, `columns.min`, `columns.max`
- `columns.warn_min`, `columns.warn_max`
- `staleness.age`, `staleness.is_stale`, `staleness.next_update_in`
- `health.is_failed`, `health.is_warning`, `health.is_stale`, `health.out_of_bounds`
- `health.warning_out_of_bounds`
- `history` array

### UI/API Footguns
- Changing field names in Rails API responses without updating `console/app/views/dashboard/*.erb` can render `-` values while health still fails.
- `console/core/status.sh` should prefer Rails health/API checks over raw SQLite timestamps.
- Invite rows should open detail view; avoid frontend calls to non-existent invite retrieval endpoints.

## Release Notes Safety (Important)
- Never pass GitHub release notes as a double-quoted inline string when content contains backticks.
- Use `gh release create/edit --notes-file <file>` or a single-quoted heredoc (`<<'EOF'`) to avoid shell command substitution.
- Example safe pattern:
  - `gh release edit vX.Y --notes-file /tmp/release-notes.md`
- If using heredoc, assign notes first without interpolation:
  - `NOTES="$(cat <<'EOF' ... EOF)"`
  - then call `gh release edit ... --notes "$NOTES"`.
