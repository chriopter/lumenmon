#!/usr/bin/env python3
# Agent metrics reading and aggregation.
# Reads TSV files and generates formatted metrics for agents.

import os
import glob
import time
from tsv import read_last_line, read_last_n_lines, parse_tsv_line
from formatters import generate_tui_sparkline, format_age

DATA_DIR = "/data/agents"

def get_history_from_file(file_path, minutes=60):
    """Read history from TSV file for the last N minutes."""
    history = []
    if not os.path.exists(file_path):
        return history

    current_time = int(time.time())
    cutoff_time = current_time - (minutes * 60)

    # Read last 1000 lines to ensure we get all data from last 60 minutes
    lines = read_last_n_lines(file_path, 1000)
    for line in lines:
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None and timestamp >= cutoff_time:
            history.append({'timestamp': timestamp, 'value': round(value, 1)})

    # Sort by timestamp
    history.sort(key=lambda x: x['timestamp'])
    return history

def get_agent_metrics(agent_id):
    """Read all metrics for a specific agent."""
    agent_dir = os.path.join(DATA_DIR, agent_id)

    metrics = {
        'id': agent_id,
        'cpu': 0.0,
        'memory': 0.0,
        'disk': 0.0,
        'hostname': '',
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

        metrics['cpuHistory'] = get_history_from_file(cpu_file, 60)

    # Read Memory
    mem_file = os.path.join(agent_dir, 'generic_mem.tsv')
    if os.path.exists(mem_file):
        line = read_last_line(mem_file)
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None:
            metrics['memory'] = round(value, 1)
            metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)

        metrics['memHistory'] = get_history_from_file(mem_file, 60)

    # Read Disk
    disk_file = os.path.join(agent_dir, 'generic_disk.tsv')
    if os.path.exists(disk_file):
        line = read_last_line(disk_file)
        timestamp, value = parse_tsv_line(line)
        if timestamp and value is not None:
            metrics['disk'] = round(value, 1)
            metrics['lastUpdate'] = max(metrics['lastUpdate'], timestamp)

        metrics['diskHistory'] = get_history_from_file(disk_file, 60)

    # Read Hostname
    hostname_file = os.path.join(agent_dir, 'generic_hostname.tsv')
    if os.path.exists(hostname_file):
        line = read_last_line(hostname_file)
        if line:
            parts = line.strip().split()
            if len(parts) >= 3:
                # Format: timestamp interval hostname
                # Hostname is everything after the interval (could contain spaces)
                metrics['hostname'] = ' '.join(parts[2:])

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

    # Add formatted fields for HTML templates
    metrics['age_formatted'] = format_age(metrics['age'])
    # Generate sparklines from history values only
    cpu_values = [h['value'] for h in metrics['cpuHistory']]
    mem_values = [h['value'] for h in metrics['memHistory']]
    disk_values = [h['value'] for h in metrics['diskHistory']]
    metrics['cpuSparkline'] = generate_tui_sparkline(cpu_values)
    metrics['memSparkline'] = generate_tui_sparkline(mem_values)
    metrics['diskSparkline'] = generate_tui_sparkline(disk_values)

    return metrics

def get_agent_tsv_files(agent_id):
    """Get all TSV files for an agent with their latest data line."""
    agent_dir = os.path.join(DATA_DIR, agent_id)
    tsv_files = []

    if not os.path.exists(agent_dir):
        return tsv_files

    # Get all .tsv files in the agent directory
    tsv_pattern = os.path.join(agent_dir, '*.tsv')
    for file_path in sorted(glob.glob(tsv_pattern)):
        filename = os.path.basename(file_path)

        # Always include the file, even if reading fails
        try:
            # Read the last line
            last_line = read_last_line(file_path)
            timestamp, value = parse_tsv_line(last_line)

            # Count total lines in file
            line_count = 0
            try:
                with open(file_path, 'r') as f:
                    line_count = sum(1 for line in f if line.strip())
            except:
                line_count = 0

            tsv_info = {
                'filename': filename,
                'path': file_path,
                'lastLine': last_line if last_line else 'No data',
                'timestamp': timestamp if timestamp else '-',
                'value': round(value, 1) if value is not None else '-',
                'line_count': line_count
            }
        except Exception as e:
            # If there's any error, still show the file
            tsv_info = {
                'filename': filename,
                'path': file_path,
                'lastLine': f'Error reading file: {str(e)}',
                'timestamp': '-',
                'value': '-',
                'line_count': 0
            }

        tsv_files.append(tsv_info)

    return tsv_files

def get_all_agents():
    """Get metrics for all agents, sorted by status."""
    agents = []

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

    return agents
