# CLAUDE.md

Development guide for Lumenmon monitoring system.

## Current Architecture

### Server Components (`/server`)

**Structure:**
```
server/
├── docker-compose.yml     # Container orchestration
├── Dockerfile            # Python 3.11 slim base
├── .gitignore           # Excludes data/ folder
├── data/                # SQLite database storage
│   └── lumenmon.db
└── app/                 # Application code
    ├── sink.py          # Metrics sink API (port 8080)
    ├── dashboard.py     # Streamlit dashboard (port 8501)
    └── requirements.txt # Python dependencies
```

**Stack:**
- Python 3.11 with Streamlit
- SQLite for persistence (auto-initialized)
- Plotly for data visualization
- Cyber-retro 80s TUI theme (terminal green phosphor)
- Auto-refresh every 5 seconds

### Client Components (`/client`)

**Structure:**
```
client/
├── docker-compose.yml
├── Dockerfile           # Alpine Linux base
├── .env                # Configuration
├── collectors/         # Metric collection scripts
│   ├── collect.sh     # Main orchestrator
│   ├── detect_os.sh   # OS detection
│   └── generic/       # Universal collectors
│       ├── cpu.sh
│       ├── memory.sh
│       ├── disk.sh
│       └── network.sh
└── forwarders/        # External data ingestion
    ├── webhook.sh     # HTTP webhook receiver
    └── smtp.sh        # SMTP email receiver
```

**Features:**
- POSIX shell compliant
- OS detection (Debian, Arch, Alpine, Proxmox)
- Modular collector system
- Network mode: host for accurate metrics

## Running the System

### Development (Same Machine, Separate Containers)

```bash
# Terminal 1 - Server
cd server && docker-compose up --build

# Terminal 2 - Client  
cd client && docker-compose up --build

# Access dashboard
open http://localhost:8501
```

### Production (Different Machines)

```bash
# On server machine
cd server && docker-compose up -d

# On client machine
export SERVER_URL=http://server-ip:8080
cd client && docker-compose up -d
```

### Testing

```bash
# Test webhook forwarding
./test_webhook.sh

# Test SMTP forwarding
./test_smtp.sh

# Manual metric test
curl -X POST localhost:8080/metrics -d "test_metric:42"

# Check sink is receiving
curl -X POST localhost:8080/metrics -d "test:123" -v
```

## Key Design Principles

1. **KISS**: Keep components simple and focused
2. **Separation**: Sink writes, dashboard reads, no cross-dependencies
3. **Minimal Dependencies**: Only Streamlit/Pandas/Plotly for dashboard
4. **Container Isolation**: Separate containers for production deployment
5. **Retro Aesthetic**: Terminal green with ASCII art and box drawing

## Data Flow

```
Collectors → POST /metrics → Sink → SQLite ← Dashboard (read-only)
Webhooks  → POST /api/feed → Sink → SQLite ← Dashboard (read-only)
SMTP      → POST /api/feed → Sink → SQLite ← Dashboard (read-only)
```

## Database Schema

```sql
-- Metrics table
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    metric_name TEXT NOT NULL,
    metric_value REAL,
    metric_text TEXT,
    host TEXT DEFAULT 'localhost'
);

-- Messages table  
CREATE TABLE messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    source TEXT,
    message TEXT
);
```

## Environment Variables

### Server
- `STREAMLIT_BROWSER_GATHER_USAGE_STATS=false` - Disable telemetry
- `STREAMLIT_SERVER_HEADLESS=true` - Headless mode for containers

### Client
- `SERVER_URL` - Sink endpoint (default: http://localhost:8080)
- `INTERVAL` - Collection interval in seconds (default: 5)
- `DEBUG` - Debug output (0/1, default: 1)

## Adding New Collectors

1. Create script in `client/collectors/generic/` or OS-specific folder
2. Output format: `metric_name:value` (one per line)
3. Make executable: `chmod +x collector.sh`
4. Collector will be auto-discovered by `collect.sh`

## Dashboard Features

- **ASCII Art Header**: Retro terminal branding
- **Status Bar**: Live connection status with data freshness
- **Metrics Cards**: CPU, Memory, Disk, Load with progress bars
- **Charts Tab**: Time series visualization with Plotly
- **Metrics Tab**: Current values in terminal table format
- **Messages Tab**: Webhook/email feed display
- **Control Tab**: Database statistics and maintenance

## Troubleshooting

### Client Can't Connect
```bash
# Check sink is accessible
curl -X POST http://localhost:8080/metrics -d "test:1"

# For containers on same host
SERVER_URL=http://localhost:8080  # with network_mode: host

# For different machines
SERVER_URL=http://actual-server-ip:8080
```

### Database Issues
- Database auto-creates on first run
- Located at `server/data/lumenmon.db`
- Delete file to reset completely

### Dashboard Not Updating
- Check sink is receiving data
- Verify database has recent timestamps
- Auto-refresh is 5 seconds, manual refresh button available