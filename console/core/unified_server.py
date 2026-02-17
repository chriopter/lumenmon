#!/usr/bin/env python3
"""
Unified MQTT + HTTP Server for Lumenmon Console.

WHY UNIFIED?
The original architecture had Flask query SQLite on every API request (80+ queries
per request). This caused 46% CPU usage under normal load. By keeping all state in
RAM and serving pre-serialized JSON, we achieve 0.5% CPU (-99%) and 4KB responses
instead of 31KB (-87% with gzip).

ARCHITECTURE:
┌─────────────────────────────────────────────────────────────┐
│  MQTT Subscriber  →  RAM State  →  Pre-serialized JSON     │
│       ↓                                                     │
│  SQLite Persister (every 30s, for restart recovery)        │
└─────────────────────────────────────────────────────────────┘

- MQTT thread receives metrics, updates RAM state
- HTTP requests return pre-built, gzip-compressed JSON from cache
- Background thread persists to SQLite every 30s (not for reads, only backup)
- On startup, loads last known state from SQLite (backfill)

REPLACES: mqtt_to_sqlite.py, app.py, agents.py, metrics.py
"""

import gzip
import json
import os
import re
import sqlite3
import sys
import threading
import time
from collections import deque
from datetime import datetime
from flask import Flask, jsonify, request, render_template, Response
import paho.mqtt.client as mqtt

# Add app directory for imports
sys.path.insert(0, '/app/web/app')
from pending_invites import get_invite, clear_invite
from formatters import generate_tui_sparkline, format_age

DB_PATH = "/data/metrics.db"
MQTT_PASSWD_FILE = "/data/mqtt/passwd"
HISTORY_SIZE = 30  # Sparkline points to keep in RAM
PERSIST_INTERVAL = 30  # Seconds between SQLite writes (was 5)
JSON_CACHE_INTERVAL = 1  # Seconds between JSON rebuilds

# =============================================================================
# GLOBAL STATE (RAM)
# =============================================================================

class AgentState:
    """Thread-safe agent state storage with pre-computed JSON cache."""

    def __init__(self):
        self.lock = threading.RLock()
        self.agents = {}  # {agent_id: {metric_name: {value, timestamp, interval, ...}}}
        self.history = {}  # {agent_id: {metric_name: deque([{ts, value}, ...])}}
        self.db_write_queue = []  # Queue of metrics to persist
        self.stats = {
            'mqtt_messages': 0,
            'http_requests': 0,
            'db_writes': 0,
            'json_builds': 0
        }
        # Pre-computed JSON cache (rebuilt every JSON_CACHE_INTERVAL)
        self._entities_json = None
        self._entities_json_bytes = None  # Pre-serialized JSON bytes
        self._entities_json_gzip = None   # Pre-compressed gzip bytes
        self._entities_json_time = 0
        # MQTT users cache
        self._mqtt_users = {}
        # Display names cache {agent_id: display_name}
        self.display_names = {}
        self._mqtt_users_time = 0
        # Agent tables cache {agent_id: (bytes, gzip_bytes, timestamp)}
        self._tables_cache = {}
        # Mail-only agents (agents that only send mail, no metrics)
        self.mail_only_agents = set()
        # Agent groups {agent_id: group_name}
        self.agent_groups = {}

    def update_metric(self, agent_id, metric_name, value, data_type, interval, min_val, max_val):
        """Update metric in RAM (called from MQTT thread)."""
        timestamp = int(time.time())

        with self.lock:
            # Initialize agent if needed
            if agent_id not in self.agents:
                self.agents[agent_id] = {}
                self.history[agent_id] = {}

            # Store current value
            self.agents[agent_id][metric_name] = {
                'value': value,
                'timestamp': timestamp,
                'interval': interval,
                'min': min_val,
                'max': max_val,
                'type': data_type
            }

            # Store in history for sparklines (numeric only)
            if data_type in ('REAL', 'INTEGER'):
                if metric_name not in self.history[agent_id]:
                    self.history[agent_id][metric_name] = deque(maxlen=HISTORY_SIZE)
                try:
                    self.history[agent_id][metric_name].append({
                        'timestamp': timestamp,
                        'value': round(float(value), 1)
                    })
                except (ValueError, TypeError):
                    pass

            # Queue for DB persistence
            self.db_write_queue.append({
                'agent_id': agent_id,
                'metric_name': metric_name,
                'value': value,
                'type': data_type,
                'timestamp': timestamp,
                'interval': interval,
                'min': min_val,
                'max': max_val
            })

            self.stats['mqtt_messages'] += 1

    def get_all_entities_bytes(self, accept_gzip=False):
        """Get pre-serialized JSON bytes (for zero-copy response)."""
        current_time = time.time()

        # Return cached bytes if still fresh
        if self._entities_json_bytes and (current_time - self._entities_json_time) < JSON_CACHE_INTERVAL:
            with self.lock:
                self.stats['http_requests'] += 1
            return (self._entities_json_gzip, True) if accept_gzip else (self._entities_json_bytes, False)

        # Rebuild (this also sets _entities_json_bytes and _entities_json_gzip)
        self.get_all_entities()
        return (self._entities_json_gzip, True) if accept_gzip else (self._entities_json_bytes, False)

    def get_all_entities(self):
        """Get entities from pre-computed cache (rebuilt every second)."""
        current_time = time.time()

        # Return cached JSON if still fresh
        if self._entities_json and (current_time - self._entities_json_time) < JSON_CACHE_INTERVAL:
            with self.lock:
                self.stats['http_requests'] += 1
            return self._entities_json

        # Rebuild JSON
        with self.lock:
            self.stats['http_requests'] += 1
            self.stats['json_builds'] += 1

            entities = []
            current_time_int = int(current_time)

            # Get MQTT users from passwd file (cached)
            mqtt_users = self._get_mqtt_users()

            # Collect all known agent IDs
            all_agent_ids = set(self.agents.keys()) | set(mqtt_users.keys())

            # First pass: find max values per group for each metric
            # Group None = ungrouped agents
            group_cpu_vals = {}  # {group_name: [values]}
            group_mem_vals = {}
            group_disk_vals = {}

            for agent_id in all_agent_ids:
                if not agent_id.startswith('id_'):
                    continue
                agent_history = self.history.get(agent_id, {})
                group = self.agent_groups.get(agent_id)  # None for ungrouped

                if group not in group_cpu_vals:
                    group_cpu_vals[group] = []
                    group_mem_vals[group] = []
                    group_disk_vals[group] = []

                group_cpu_vals[group].extend([h['value'] for h in agent_history.get('generic_cpu', [])])
                group_mem_vals[group].extend([h['value'] for h in agent_history.get('generic_memory', [])])
                group_disk_vals[group].extend([h['value'] for h in agent_history.get('generic_disk', [])])

            # Calculate max per group (100 as fallback for percentage metrics)
            group_maxes = {}
            for group in set(list(group_cpu_vals.keys()) + list(group_mem_vals.keys()) + list(group_disk_vals.keys())):
                group_maxes[group] = {
                    'cpu': max(group_cpu_vals.get(group, [100])) if group_cpu_vals.get(group) else 100,
                    'mem': max(group_mem_vals.get(group, [100])) if group_mem_vals.get(group) else 100,
                    'disk': max(group_disk_vals.get(group, [100])) if group_disk_vals.get(group) else 100,
                }

            # Also keep global max as fallback
            all_cpu_vals = [v for vals in group_cpu_vals.values() for v in vals]
            all_mem_vals = [v for vals in group_mem_vals.values() for v in vals]
            all_disk_vals = [v for vals in group_disk_vals.values() for v in vals]
            global_cpu_max = max(all_cpu_vals) if all_cpu_vals else 100
            global_mem_max = max(all_mem_vals) if all_mem_vals else 100
            global_disk_max = max(all_disk_vals) if all_disk_vals else 100

            for agent_id in all_agent_ids:
                if not agent_id.startswith('id_'):
                    continue

                agent_data = self.agents.get(agent_id, {})
                agent_history = self.history.get(agent_id, {})

                # Check if mail-only agent
                is_mail_only = agent_id in self.mail_only_agents and not agent_data

                # Get group for this agent
                agent_group = self.agent_groups.get(agent_id)

                # Build entity
                display_name = self.display_names.get(agent_id)
                entity = {
                    'id': agent_id,
                    'type': 'agent',
                    'valid': bool(agent_data) or is_mail_only,
                    'has_mqtt_user': agent_id in mqtt_users,
                    'has_table': bool(agent_data),
                    'is_mail_only': is_mail_only,
                    'mail_only': is_mail_only,
                    'pending_invite': get_invite(agent_id),
                    'display_name': display_name,
                    'group': agent_group,
                }

                if is_mail_only:
                    # Mail-only agent - show special status
                    entity.update({
                        'status': 'mail-only',
                        'hostname': '',
                        'cpu': 0,
                        'memory': 0,
                        'disk': 0,
                        'failed_collectors': 0,
                        'total_collectors': 0,
                    })
                elif agent_data:
                    # Extract core metrics
                    cpu_data = agent_data.get('generic_cpu', {})
                    mem_data = agent_data.get('generic_memory', {})
                    disk_data = agent_data.get('generic_disk', {})
                    heartbeat_data = agent_data.get('generic_heartbeat', {})
                    hostname_data = agent_data.get('generic_hostname', {})
                    uptime_data = agent_data.get('generic_sys_uptime', {})
                    version_data = agent_data.get('generic_agent_version', {})

                    # Calculate status
                    heartbeat_ts = heartbeat_data.get('timestamp', 0)
                    heartbeat_age = current_time_int - heartbeat_ts if heartbeat_ts else 999999
                    is_offline = heartbeat_age > 10  # 10s timeout

                    last_update = max(
                        cpu_data.get('timestamp', 0),
                        mem_data.get('timestamp', 0),
                        disk_data.get('timestamp', 0)
                    )
                    age = current_time_int - last_update if last_update else 0

                    # Count failed collectors (stale OR out-of-bounds)
                    failed = 0
                    total = len(agent_data)
                    for metric_name, metric_data in agent_data.items():
                        if '_registration_test' in metric_name:
                            total -= 1
                            continue

                        ts = metric_data.get('timestamp', 0)
                        interval = metric_data.get('interval', 60)
                        is_stale = interval > 0 and (current_time_int - ts) > (interval + 1)

                        is_out_of_bounds = False
                        value = metric_data.get('value')
                        min_val = metric_data.get('min')
                        max_val = metric_data.get('max')
                        data_type = metric_data.get('type', 'REAL')
                        if data_type in ('REAL', 'INTEGER') and value is not None:
                            try:
                                value_num = float(value)
                                if min_val is not None and value_num < float(min_val):
                                    is_out_of_bounds = True
                                elif max_val is not None and value_num > float(max_val):
                                    is_out_of_bounds = True
                            except (ValueError, TypeError):
                                pass

                        if is_stale or is_out_of_bounds:
                            failed += 1

                    status = 'offline' if is_offline else ('degraded' if failed > 0 else 'online')

                    # Get history for sparklines
                    cpu_hist = list(agent_history.get('generic_cpu', []))
                    mem_hist = list(agent_history.get('generic_memory', []))
                    disk_hist = list(agent_history.get('generic_disk', []))

                    # Use group-specific max values for sparklines
                    grp_max = group_maxes.get(agent_group, {})
                    sparkline_cpu_max = grp_max.get('cpu', global_cpu_max)
                    sparkline_mem_max = grp_max.get('mem', global_mem_max)
                    sparkline_disk_max = grp_max.get('disk', global_disk_max)

                    original_hostname = hostname_data.get('value', '')
                    entity.update({
                        'cpu': cpu_data.get('value', 0),
                        'memory': mem_data.get('value', 0),
                        'disk': disk_data.get('value', 0),
                        'hostname': display_name or original_hostname,
                        'original_hostname': original_hostname,
                        'status': status,
                        'failed_collectors': failed,
                        'total_collectors': total,
                        'age': age,
                        'age_formatted': format_age(age),
                        'lastUpdate': last_update,
                        'uptime': str(uptime_data.get('value', '')),
                        'heartbeat': heartbeat_ts,
                        'cpuHistory': cpu_hist,
                        'memHistory': mem_hist,
                        'diskHistory': disk_hist,
                        'cpuSparkline': generate_tui_sparkline([h['value'] for h in cpu_hist], global_max=sparkline_cpu_max),
                        'memSparkline': generate_tui_sparkline([h['value'] for h in mem_hist], global_max=sparkline_mem_max),
                        'diskSparkline': generate_tui_sparkline([h['value'] for h in disk_hist], global_max=sparkline_disk_max),
                        'agent_version': str(version_data.get('value', ''))
                    })

                entities.append(entity)

            # Add invites
            for user_id in mqtt_users:
                if user_id.startswith('reg_'):
                    entities.append({
                        'id': user_id,
                        'type': 'invite',
                        'valid': True,
                        'has_mqtt_user': True,
                        'pending_invite': get_invite(user_id)
                    })

            # Sort: by group (ungrouped last), then by status, then by hostname/id
            entities.sort(key=lambda e: (
                # Groups alphabetically, ungrouped (None) at the end
                (e.get('group') or '\xff'),  # \xff sorts after all normal chars
                # Then by status
                0 if e.get('status') == 'online' else (1 if e.get('status') == 'degraded' else 2),
                # Then by hostname
                (e.get('hostname') or e['id']).lower()
            ))

            # Cache the result
            self._entities_json = entities
            self._entities_json_time = current_time

            # Pre-serialize to JSON bytes for zero-copy response
            response = {
                'entities': entities,
                'count': len(entities),
                'timestamp': current_time_int,
                'source': 'ram'
            }
            self._entities_json_bytes = json.dumps(response, separators=(',', ':')).encode('utf-8')
            self._entities_json_gzip = gzip.compress(self._entities_json_bytes, compresslevel=1)  # Fast compression

            return entities

    def get_agent_tables_bytes(self, agent_id, accept_gzip=False):
        """Get pre-serialized JSON bytes for agent tables (cached 1s)."""
        current_time = time.time()

        # Check cache
        cached = self._tables_cache.get(agent_id)
        if cached and (current_time - cached[2]) < JSON_CACHE_INTERVAL:
            return (cached[1], True) if accept_gzip else (cached[0], False)

        # Build and cache
        tables = self.get_agent_tables(agent_id)
        response = {
            'agent_id': agent_id,
            'tables': tables,
            'count': len(tables),
            'timestamp': int(current_time),
            'source': 'ram'
        }
        json_bytes = json.dumps(response, separators=(',', ':')).encode('utf-8')
        gzip_bytes = gzip.compress(json_bytes, compresslevel=1)
        self._tables_cache[agent_id] = (json_bytes, gzip_bytes, current_time)
        return (gzip_bytes, True) if accept_gzip else (json_bytes, False)

    def get_agent_tables(self, agent_id):
        """Get all metrics for a specific agent."""
        with self.lock:
            agent_data = self.agents.get(agent_id, {})
            agent_history = self.history.get(agent_id, {})
            current_time = int(time.time())

            tables = []
            for metric_name, data in agent_data.items():
                if '_registration_test' in metric_name:
                    continue

                timestamp = data.get('timestamp', 0)
                interval = data.get('interval', 60)
                value = data.get('value')
                min_val = data.get('min')
                max_val = data.get('max')
                data_type = data.get('type', 'REAL')

                # Staleness
                age = current_time - timestamp if timestamp else 0
                is_stale = interval > 0 and age > (interval + 1)

                # Bounds check
                is_out_of_bounds = False
                bounds_error = None
                if data_type in ('REAL', 'INTEGER') and value is not None:
                    try:
                        v = float(value)
                        if min_val is not None and v < min_val:
                            is_out_of_bounds = True
                            bounds_error = f"value {v} < min {min_val}"
                        elif max_val is not None and v > max_val:
                            is_out_of_bounds = True
                            bounds_error = f"value {v} > max {max_val}"
                    except (ValueError, TypeError):
                        pass

                # History for this metric
                hist = list(agent_history.get(metric_name, []))

                # Backward-compatible typed value columns (used by detail table UI)
                value_real = None
                value_int = None
                value_text = None
                if data_type == 'REAL':
                    value_real = value
                elif data_type == 'INTEGER':
                    value_int = value
                else:
                    value_text = value

                # Next update countdown for UI
                next_update_in = 0
                if interval > 0 and timestamp:
                    next_update_in = (timestamp + interval) - current_time

                # Data span (history coverage)
                data_span = '-'
                if len(hist) >= 2:
                    span_seconds = hist[-1]['timestamp'] - hist[0]['timestamp']
                    if span_seconds < 60:
                        data_span = f"{span_seconds}s"
                    elif span_seconds < 3600:
                        data_span = f"{span_seconds // 60}m"
                    elif span_seconds < 86400:
                        data_span = f"{span_seconds // 3600}h"
                    else:
                        data_span = f"{span_seconds // 86400}d"

                tables.append({
                    'metric_name': metric_name,
                    'table_name': f"{agent_id}_{metric_name}",
                    'columns': {
                        'timestamp': timestamp,
                        'value_real': value_real,
                        'value_int': value_int,
                        'value_text': value_text,
                        'value': value,
                        'interval': interval,
                        'min_value': min_val,
                        'max_value': max_val
                    },
                    'staleness': {
                        'age': age,
                        'is_stale': is_stale,
                        'next_update_in': next_update_in
                    },
                    'health': {
                        'is_failed': is_stale or is_out_of_bounds,
                        'is_stale': is_stale,
                        'out_of_bounds': is_out_of_bounds,
                        'bounds_error': bounds_error
                    },
                    'metadata': {
                        'type': data_type,
                        'timestamp_age': f"{age}s ago",
                        'data_span': data_span,
                        'line_count': len(hist)
                    },
                    'history': hist
                })

            tables.sort(key=lambda t: t['metric_name'].lower())
            return tables

    def update_display_name(self, agent_id, display_name):
        """Update display name in RAM cache and invalidate JSON cache."""
        with self.lock:
            if display_name:
                self.display_names[agent_id] = display_name
            elif agent_id in self.display_names:
                del self.display_names[agent_id]
            # Invalidate JSON cache so it gets rebuilt
            self._entities_json_time = 0

    def update_agent_group(self, agent_id, group_name):
        """Update agent group in RAM cache and invalidate JSON cache."""
        with self.lock:
            if group_name:
                self.agent_groups[agent_id] = group_name
            elif agent_id in self.agent_groups:
                del self.agent_groups[agent_id]
            # Invalidate JSON cache so it gets rebuilt
            self._entities_json_time = 0

    def get_stats(self):
        """Get server statistics."""
        with self.lock:
            return dict(self.stats)

    def pop_db_queue(self):
        """Get and clear the DB write queue."""
        with self.lock:
            queue = self.db_write_queue
            self.db_write_queue = []
            return queue

    def _get_mqtt_users(self):
        """Get MQTT users from passwd file (cached for 5s)."""
        current_time = time.time()
        if self._mqtt_users and (current_time - self._mqtt_users_time) < 5:
            return self._mqtt_users

        users = {}
        try:
            if os.path.isfile(MQTT_PASSWD_FILE):
                with open(MQTT_PASSWD_FILE, 'r') as f:
                    for line in f:
                        if ':' in line:
                            username = line.split(':')[0].strip()
                            if username.startswith('id_') or username.startswith('reg_'):
                                users[username] = True
        except Exception:
            pass

        self._mqtt_users = users
        self._mqtt_users_time = current_time
        return users

    def load_from_sqlite(self, db_conn):
        """Load last known state from SQLite on startup."""
        try:
            cursor = db_conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'id_%'")

            for (table_name,) in cursor.fetchall():
                # Parse agent_id and metric_name
                parts = table_name.split('_', 2)
                if len(parts) < 3:
                    continue
                agent_id = f"{parts[0]}_{parts[1]}"
                metric_name = '_'.join(parts[2:]) if len(parts) > 2 else parts[2]

                # Get latest value
                try:
                    cursor.execute(f'''
                        SELECT timestamp, value_real, value_int, value_text, interval, min_value, max_value
                        FROM "{table_name}" ORDER BY timestamp DESC LIMIT 1
                    ''')
                    row = cursor.fetchone()
                    if row:
                        timestamp, val_real, val_int, val_text, interval, min_val, max_val = row
                        value = val_real if val_real is not None else (val_int if val_int is not None else val_text)
                        data_type = 'REAL' if val_real is not None else ('INTEGER' if val_int is not None else 'TEXT')

                        with self.lock:
                            if agent_id not in self.agents:
                                self.agents[agent_id] = {}
                                self.history[agent_id] = {}

                            self.agents[agent_id][metric_name] = {
                                'value': value,
                                'timestamp': timestamp,
                                'interval': interval if interval is not None else 60,
                                'min': min_val,
                                'max': max_val,
                                'type': data_type
                            }

                    # Load history for sparklines
                    cursor.execute(f'''
                        SELECT timestamp, COALESCE(value_real, value_int)
                        FROM "{table_name}"
                        WHERE value_real IS NOT NULL OR value_int IS NOT NULL
                        ORDER BY timestamp DESC LIMIT {HISTORY_SIZE}
                    ''')
                    rows = cursor.fetchall()
                    if rows:
                        with self.lock:
                            if metric_name not in self.history[agent_id]:
                                self.history[agent_id][metric_name] = deque(maxlen=HISTORY_SIZE)
                            for ts, val in reversed(rows):
                                if val is not None:
                                    self.history[agent_id][metric_name].append({
                                        'timestamp': ts,
                                        'value': round(float(val), 1)
                                    })
                except Exception:
                    pass

            # Load mail-only agents (agents that have sent messages)
            try:
                cursor.execute("SELECT DISTINCT agent_id FROM messages")
                for (agent_id,) in cursor.fetchall():
                    self.mail_only_agents.add(agent_id)
            except Exception:
                pass  # messages table might not exist

            # Load display names
            try:
                cursor.execute("SELECT agent_id, display_name FROM host_settings WHERE display_name IS NOT NULL")
                for agent_id, display_name in cursor.fetchall():
                    self.display_names[agent_id] = display_name
            except Exception:
                pass  # host_settings table might not exist

            # Load agent groups
            try:
                cursor.execute("SELECT agent_id, group_name FROM host_settings WHERE group_name IS NOT NULL")
                for agent_id, group_name in cursor.fetchall():
                    self.agent_groups[agent_id] = group_name
            except Exception:
                pass  # host_settings table might not exist or no group_name column

            print(f"[unified] Loaded {len(self.agents)} agents, {len(self.mail_only_agents)} mail senders, {len(self.display_names)} display names, {len(self.agent_groups)} groups from SQLite", flush=True)
        except Exception as e:
            print(f"[unified] Error loading from SQLite: {e}", flush=True)


# Global state instance
STATE = AgentState()

# =============================================================================
# SQLITE PERSISTENCE (Background Thread)
# =============================================================================

def validate_identifier(value):
    """Validate SQL identifier."""
    if not value or not isinstance(value, str):
        return False
    return bool(re.match(r'^[a-zA-Z0-9_-]+$', value))

class SQLitePersister(threading.Thread):
    """Background thread that periodically writes to SQLite."""

    def __init__(self):
        super().__init__(daemon=True)
        self.running = True
        self.db_conn = None

    def run(self):
        self.db_conn = sqlite3.connect(DB_PATH)
        self.db_conn.execute("PRAGMA synchronous=NORMAL")
        print(f"[persister] Started SQLite persister (interval: {PERSIST_INTERVAL}s)", flush=True)

        while self.running:
            time.sleep(PERSIST_INTERVAL)
            self.persist()

    def persist(self):
        """Write queued metrics to SQLite."""
        queue = STATE.pop_db_queue()
        if not queue:
            return

        cursor = self.db_conn.cursor()
        written = 0

        for item in queue:
            try:
                agent_id = item['agent_id']
                metric_name = item['metric_name']
                table_name = f"{agent_id}_{metric_name}"

                if not validate_identifier(table_name):
                    continue

                # Ensure table exists
                cursor.execute(f'''
                    CREATE TABLE IF NOT EXISTS "{table_name}" (
                        timestamp INTEGER PRIMARY KEY,
                        value_real REAL,
                        value_int INTEGER,
                        value_text TEXT,
                        interval INTEGER,
                        min_value REAL,
                        max_value REAL
                    )
                ''')

                # Insert
                data_type = item['type']
                if data_type == 'REAL':
                    cursor.execute(
                        f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value_real, interval, min_value, max_value) VALUES (?, ?, ?, ?, ?)',
                        (item['timestamp'], item['value'], item['interval'], item['min'], item['max'])
                    )
                elif data_type == 'INTEGER':
                    cursor.execute(
                        f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value_int, interval, min_value, max_value) VALUES (?, ?, ?, ?, ?)',
                        (item['timestamp'], item['value'], item['interval'], item['min'], item['max'])
                    )
                else:
                    cursor.execute(
                        f'INSERT OR REPLACE INTO "{table_name}" (timestamp, value_text, interval, min_value, max_value) VALUES (?, ?, ?, ?, ?)',
                        (item['timestamp'], item['value'], item['interval'], item['min'], item['max'])
                    )
                written += 1
            except Exception as e:
                print(f"[persister] Error writing {item.get('metric_name')}: {e}", flush=True)

        self.db_conn.commit()
        STATE.stats['db_writes'] += written
        # Only log periodically to reduce output
        if written > 0 and STATE.stats['db_writes'] % 500 == 0:
            print(f"[persister] Total writes: {STATE.stats['db_writes']}", flush=True)

# =============================================================================
# MQTT CLIENT
# =============================================================================

class MQTTClient(threading.Thread):
    """MQTT subscriber thread."""

    def __init__(self):
        super().__init__(daemon=True)
        self.client = None

    def run(self):
        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

        try:
            self.client.connect("localhost", 1883, 60)
            print("[mqtt] Connected to MQTT broker", flush=True)
            self.client.loop_forever()
        except Exception as e:
            print(f"[mqtt] Error: {e}", flush=True)

    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            client.subscribe("metrics/#")
            print("[mqtt] Subscribed to metrics/#", flush=True)

    def on_message(self, client, userdata, msg):
        try:
            parts = msg.topic.split('/')
            if len(parts) != 3 or parts[0] != 'metrics':
                return

            agent_id = parts[1]
            metric_name = parts[2]

            if not validate_identifier(agent_id) or not validate_identifier(metric_name):
                return

            data = json.loads(msg.payload.decode())

            if metric_name == 'mail_message':
                # Track as mail-sending agent (might be mail-only)
                STATE.mail_only_agents.add(agent_id)
                clear_invite(agent_id)
                return

            if 'value' not in data:
                return

            value = data['value']
            data_type = data.get('type', 'REAL')
            interval = data.get('interval', 60)
            min_val = data.get('min')
            max_val = data.get('max')

            STATE.update_metric(agent_id, metric_name, value, data_type, interval, min_val, max_val)
            clear_invite(agent_id)

        except Exception as e:
            print(f"[mqtt] Error processing message: {e}", flush=True)

# =============================================================================
# FLASK HTTP SERVER
# =============================================================================

template_dir = os.path.join(os.path.dirname(__file__), '..', 'web', 'public', 'html')
static_dir = os.path.join(os.path.dirname(__file__), '..', 'web', 'public')
app = Flask(__name__, template_folder=template_dir, static_folder=static_dir, static_url_path='')
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

@app.route('/')
def index():
    import random, string
    v = ''.join(random.choices(string.ascii_letters + string.digits, k=6))
    return render_template('index.html', v=v)

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'service': 'lumenmon-unified'})

@app.route('/api/entities')
def get_entities():
    """Zero-query API - returns pre-serialized JSON bytes with gzip."""
    accept_gzip = 'gzip' in request.headers.get('Accept-Encoding', '')
    data, is_gzip = STATE.get_all_entities_bytes(accept_gzip)
    resp = Response(data, mimetype='application/json')
    if is_gzip:
        resp.headers['Content-Encoding'] = 'gzip'
    return resp

@app.route('/api/agents/<agent_id>/tables')
def get_agent_tables(agent_id):
    """Get all metrics for an agent - returns pre-serialized JSON bytes with gzip."""
    accept_gzip = 'gzip' in request.headers.get('Accept-Encoding', '')
    data, is_gzip = STATE.get_agent_tables_bytes(agent_id, accept_gzip)
    resp = Response(data, mimetype='application/json')
    if is_gzip:
        resp.headers['Content-Encoding'] = 'gzip'
    return resp

@app.route('/api/stats')
def get_stats():
    """Server statistics."""
    stats = STATE.get_stats()
    stats['uptime'] = int(time.time() - START_TIME)
    stats['agents'] = len(STATE.agents)
    return jsonify(stats)

@app.route('/api/agents/<agent_id>/name', methods=['PUT', 'POST'])
def update_agent_name(agent_id):
    """Update the display name for an agent."""
    from db import set_host_display_name
    data = request.get_json() or {}
    display_name = data.get('name', '').strip()

    # Update in database
    if set_host_display_name(agent_id, display_name if display_name else None):
        # Update RAM cache
        STATE.update_display_name(agent_id, display_name if display_name else None)
        return jsonify({
            'success': True,
            'agent_id': agent_id,
            'display_name': display_name if display_name else None
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Failed to update display name'
        }), 500

@app.route('/api/agents/<agent_id>/group', methods=['PUT', 'POST'])
def update_agent_group_api(agent_id):
    """Update the group for an agent."""
    from db import set_host_group
    data = request.get_json() or {}
    group_name = data.get('group', '').strip()

    # Update in database
    if set_host_group(agent_id, group_name if group_name else None):
        # Update RAM cache
        STATE.update_agent_group(agent_id, group_name if group_name else None)
        return jsonify({
            'success': True,
            'agent_id': agent_id,
            'group': group_name if group_name else None
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Failed to update group'
        }), 500

@app.route('/api/groups')
def get_groups():
    """Get all groups with their agents."""
    groups = {}
    for agent_id, group_name in STATE.agent_groups.items():
        if group_name not in groups:
            groups[group_name] = []
        groups[group_name].append(agent_id)
    return jsonify({
        'groups': groups,
        'count': len(groups)
    })

# Import other blueprints for non-optimized endpoints
sys.path.insert(0, '/app/web/app')
from invites import invites_bp
from management import management_bp
from messages import messages_bp
from alerts import alerts_bp
app.register_blueprint(invites_bp)
app.register_blueprint(management_bp)
app.register_blueprint(messages_bp)
app.register_blueprint(alerts_bp)

# =============================================================================
# MAIN
# =============================================================================

START_TIME = time.time()

def main():
    print("=" * 60, flush=True)
    print("  LUMENMON UNIFIED SERVER (RAM-based)", flush=True)
    print("=" * 60, flush=True)

    # Load existing state from SQLite
    print("[unified] Loading state from SQLite...", flush=True)
    db_conn = sqlite3.connect(DB_PATH)
    STATE.load_from_sqlite(db_conn)
    db_conn.close()

    # Start SQLite persister
    persister = SQLitePersister()
    persister.start()

    # Start MQTT client
    mqtt_client = MQTTClient()
    mqtt_client.start()

    # Start Flask (blocking)
    print("[unified] Starting HTTP server on port 5000...", flush=True)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)

if __name__ == '__main__':
    main()
