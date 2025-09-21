# Lumenmon

Monitor all your servers from a single terminal. No config files, no databases, just SSH.

- **30 seconds to monitoring** – One command, and you're watching live metrics
- **Add servers with a magic link** – Copy, paste, done. Each agent gets its own SSH invite
- **Just works everywhere** – If you have Docker and SSH, you have monitoring
- **Live in your terminal** – Beautiful TUI shows everything at a glance
- **Zero overhead** – Tiny agents, TSV files, no bloat

<img width="650" alt="screenshot-2025-09-21_20-57-39" src="https://github.com/user-attachments/assets/a900ed9c-d519-4c1c-8268-2d2417807aed" />

## Quick Start

Install the console:
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | bash
```

You'll see:
```
✓ Console ready at localhost:2345
✓ Generated invite:

  ssh://invite:xK3mP9Qw@your-server.com:2345

Copy this invite to any server you want to monitor.
```

On each server, just paste the invite:
```bash
curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | \
  LUMENMON_INVITE='ssh://invite:xK3mP9Qw@your-server.com:2345' bash
```

Watch everything live:
```bash
lumenmon
```

That's it. Your servers are talking.

## How It Works

```
Your Servers                    Console
─────────────                   ─────────

[Agent] ──SSH──> [Port 2345] ──> [TUI Dashboard]
         metrics               live view
```

Each agent streams metrics over SSH. No APIs, no certificates, no complexity.
The console shows everything in a beautiful terminal dashboard.

## Commands

```bash
lumenmon          # Open dashboard
lumenmon invite   # Get a new server invite
lumenmon status   # Check everything's running
```

## Why Lumenmon?

Traditional monitoring is heavy. Prometheus needs configuration. Grafana needs dashboards.
Cloud services need agents and API keys.

Lumenmon is different. It's built on SSH—the tool you already trust.
One command to install, one link to connect, one terminal to monitor everything.

## Contributing

Keep it simple, keep it working, keep it Bash.

```
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```