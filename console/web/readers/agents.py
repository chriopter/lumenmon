#!/usr/bin/env python3
# Reads agent metrics from TSV files and provides agent data endpoints.
# Mirrors tui/readers/agents.sh functionality for web interface.

from flask import Blueprint, jsonify
import os
import glob
import time

agents_bp = Blueprint('agents', __name__)

DATA_DIR = "/data/agents"

def read_last_line(filepath):
    """Read the last line of a file efficiently."""
    try:
        with open(filepath, 'rb') as f:
            # Seek to end
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            if file_size == 0:
                return None

            # Read backwards to find last line
            buffer_size = min(1024, file_size)
            f.seek(max(0, file_size - buffer_size))
            lines = f.read().decode('utf-8', errors='ignore').splitlines()

            # Return last non-empty line
            for line in reversed(lines):
                if line.strip():
                    return line.strip()
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return None

def read_last_n_lines(filepath, n=10):
    """Read the last N lines of a file."""
    try:
        with open(filepath, 'rb') as f:
            # Seek to end
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            if file_size == 0:
                return []

            # Read backwards to find last N lines
            buffer_size = min(8192, file_size)
            f.seek(max(0, file_size - buffer_size))
            lines = f.read().decode('utf-8', errors='ignore').splitlines()

            # Return last N non-empty lines
            result = []
            for line in reversed(lines):
                if line.strip():
                    result.append(line.strip())
                    if len(result) >= n:
                        break

            return list(reversed(result))
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return []

def parse_tsv_line(line):
    """Parse TSV line: timestamp interval value"""
    if not line:
        return None, None

    parts = line.split('\t')
    if len(parts) < 3:
        parts = line.split()

    if len(parts) >= 3:
        try:
            timestamp = int(parts[0])
            value = float(parts[2].rstrip('%'))
            return timestamp, value
        except (ValueError, IndexError):
            pass
    return None, None

def get_agent_metrics(agent_id):
    """Read all metrics for a specific agent."""
    agent_dir = os.path.join(DATA_DIR, agent_id)

    metrics = {
        'id': agent_id,
        'cpu': 0.0,
        'memory': 0.0,
        'disk': 0.0,
        'age': 0,
        'status': 'offline',
        'lastUpdate': 0,
        'cpuHistory': [],
        'memHistory': [],
        'diskHistory': []
    }

    # Read CPU
    cpu_file = os.path.join(agent_dir, 'generic_cpu.tsv')
    if os.path.exists(cpu_file):
        line = read_last_line(cpu_file)
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None:
            metrics['cpu'] = round(value, 1)
            metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)

        # Read history for sparkline
        history_lines = read_last_n_lines(cpu_file, 10)
        for history_line in history_lines:
            _, history_value = parse_tsv_line(history_line)
            if history_value is not None:
                metrics['cpuHistory'].append(round(history_value, 1))

    # Read Memory
    mem_file = os.path.join(agent_dir, 'generic_mem.tsv')
    if os.path.exists(mem_file):
        line = read_last_line(mem_file)
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None:
            metrics['memory'] = round(value, 1)
            metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)

        # Read history for sparkline
        history_lines = read_last_n_lines(mem_file, 10)
        for history_line in history_lines:
            _, history_value = parse_tsv_line(history_line)
            if history_value is not None:
                metrics['memHistory'].append(round(history_value, 1))

    # Read Disk
    disk_file = os.path.join(agent_dir, 'generic_disk.tsv')
    if os.path.exists(disk_file):
        line = read_last_line(disk_file)
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None:
            metrics['disk'] = round(value, 1)
            metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)

        # Read history for sparkline
        history_lines = read_last_n_lines(disk_file, 10)
        for history_line in history_lines:
            _, history_value = parse_tsv_line(history_line)
            if history_value is not None:
                metrics['diskHistory'].append(round(history_value, 1))

    # Calculate age and status
    current_time = int(time.time())
    if metrics['lastUpdate'] > 0:
        metrics['age'] = current_time - metrics['lastUpdate']

        if metrics['age'] < 5:
            metrics['status'] = 'online'
        elif metrics['age'] < 30:
            metrics['status'] = 'stale'
        else:
            metrics['status'] = 'offline'

    return metrics

@agents_bp.route('/api/agents', methods=['GET'])
def get_agents():
    """Get all connected agents with their metrics."""
    agents = []

    # Find all agent directories
    if os.path.exists(DATA_DIR):
        agent_dirs = glob.glob(os.path.join(DATA_DIR, 'id_*'))

        for agent_dir in agent_dirs:
            if os.path.isdir(agent_dir):
                agent_id = os.path.basename(agent_dir)
                metrics = get_agent_metrics(agent_id)
                agents.append(metrics)

    # Sort by status (online first) then by ID
    status_order = {'online': 0, 'stale': 1, 'offline': 2}
    agents.sort(key=lambda x: (status_order.get(x['status'], 3), x['id']))

    return jsonify({
        'agents': agents,
        'timestamp': int(time.time()),
        'count': len(agents)
    })
