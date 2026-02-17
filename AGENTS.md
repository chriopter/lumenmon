# AGENTS.md
Guide for coding agents working in `lumenmon`.
Focus: build/lint/test commands and practical code conventions.

## Repository Layout
- `console/`: Dockerized console (Flask API, Mosquitto, Caddy, SQLite).
- `agent/`: Bash collectors and MQTT publishing runtime.
- `dev/`: local automation, deployment helpers, Playwright E2E tests.
- Languages: Bash, Python, JavaScript, TypeScript.

## Build, Lint, and Test Commands

### Core dev commands (repo root)
- `./dev/auto` - full local reset + console + dev agent + virtual agent.
- `./dev/add3` - spawn extra test agents.
- `./dev/check-collectors` - validate collector script contract assumptions.
- `./dev/sensor-inventory` - list current sensor coverage/failures on target host.
- `./dev/sandboxer-maintain --once` - run one local auto-maintenance pass.
- `./dev/lumenmon-diagnose` - end-to-end runtime and health propagation checks.
- `./dev/updatedeps` - refresh vendored frontend dependencies.
- `./dev/release` - create release tag workflow.

### Frontend CSS (Tailwind v4)
Run in `console/`:
- `npm install`
- `npm run build`
- `npm run dev`
Files:
- Source: `console/web/public/css/input.css`
- Output: `console/web/public/css/styles.css` (generated)

### Console image build
- `docker build -t test-console:ci ./console`

### CI lint/static checks currently used
No dedicated lint config found (no ruff/eslint/shellcheck config files).
Current checks are:
- `find . -name "*.sh" -type f -exec bash -n {} \;`
- `docker build -t test-console:ci ./console`
- Optional local guard: `./dev/check-collectors`

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

## Remote Test Deployment
Set host first:
- `export LUMENMON_TEST_HOST="root@your-test-server.local"`
- Dev environment may have access to a real server, but do not hardcode real hostnames in tracked files.
- Store real host values only in gitignored env files (for example repo-root `.env`) or shell-local exports.
- Agents should read `LUMENMON_TEST_HOST` from environment (or repo-root `.env` loaded by scripts) when running deploy helpers.
Deploy commands:
- `./dev/deploy-test web`
- `./dev/deploy-test agent`
- `./dev/deploy-test console`
- `./dev/deploy-test all`
- `./dev/deploy-test status`
- `./dev/deploy-test check`
Use the narrowest target matching changed files.

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

### Python conventions (Flask blueprints)
- Keep modules function-oriented and straightforward.
- Naming: `snake_case` for functions/vars, lowercase module files.
- Imports: keep grouped and stable (stdlib, third-party, local).
- Database usage:
  - Parameterize value inputs (`?` placeholders).
  - If interpolating identifiers, validate with strict regex first.
- API responses:
  - Return JSON via `jsonify(...)`.
  - Use clear status codes (`400`, `404`, `500`).
- Error handling:
  - Catch exceptions at route boundaries.
  - Return generic client-facing error messages.
  - Close DB connections reliably (often in `finally`).

### JavaScript/TypeScript conventions
- Keep dashboard code modular (widget registry pattern is standard here).
- Prefer descriptive names for UI/data state.
- Use semicolons consistently.
- Preserve file-local formatting:
  - `dev/tests/*.ts`: 2-space indent, single quotes.
  - `console/web/public/js/widgets.js`: 4-space indent, single quotes.
- Avoid formatter-only churn unless requested.

### Types and contracts
- Metric payload contract fields: `value`, `type`, `interval`, optional `min`, `max`.
- Collector `TYPE` values: `REAL`, `INTEGER`, `TEXT`.
- Use `min`/`max` when a metric should drive health-state detection.
- Mail staleness is server-side (`/api/messages/staleness`, default 14 days / 336h) and should stay warning-only unless explicitly changed.
- Agent ID pattern used by APIs: `id_<hex...>`.
- SQLite metric table naming: `<agent_id>_<metric_name>`.

### Error handling and logging
- Shell: emit actionable warnings to stderr; keep non-critical failures non-fatal when possible.
- Python: log internals server-side, keep API error payloads generic.
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
- Prefer targeted deploy/test loops (`./dev/deploy-test ...`) during active development.
- Do not push commits unless explicitly asked.

## Fast Direct Deploy Strategy
- Keep host in gitignored env (`LUMENMON_TEST_HOST` in repo `.env` or shell export).
- Iterate with narrow targets:
  - `./dev/deploy-test agent` for agent/runtime script changes.
  - `./dev/deploy-test web` for frontend/public asset changes.
  - `./dev/deploy-test console` for backend/console app changes.
- Verify with `./dev/deploy-test status` / `./dev/deploy-test check` plus `lumenmon` and `lumenmon-agent` checks.
- After successful real-server validation, commit and promote via normal release flow.

## Release Notes Safety (Important)
- Never pass GitHub release notes as a double-quoted inline string when content contains backticks.
- Use `gh release create/edit --notes-file <file>` or a single-quoted heredoc (`<<'EOF'`) to avoid shell command substitution.
- Example safe pattern:
  - `gh release edit vX.Y --notes-file /tmp/release-notes.md`
- If using heredoc, assign notes first without interpolation:
  - `NOTES="$(cat <<'EOF' ... EOF)"`
  - then call `gh release edit ... --notes "$NOTES"`.
