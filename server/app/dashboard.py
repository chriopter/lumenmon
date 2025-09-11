#!/usr/bin/env python3
"""LUMENMON - Cyberpunk TUI Dashboard"""
import streamlit as st
import pandas as pd
from datetime import datetime
import sqlite3
import os
import time

# Database configuration
DB_PATH = os.getenv('DB_PATH', '/app/data/lumenmon.db')

# Page config
st.set_page_config(
    page_title="LUMENMON [TERMINAL]",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Cyberpunk terminal styling
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;700&display=swap');
    
    .stApp {
        background: linear-gradient(180deg, #000000 0%, #001100 100%);
    }
    
    .element-container, .stMarkdown {
        font-family: 'Fira Code', 'Courier New', monospace !important;
    }
    
    pre {
        background-color: #000000 !important;
        border: 1px solid #00ff00 !important;
        color: #00ff00 !important;
        text-shadow: 0 0 5px #00ff00;
        padding: 10px !important;
        font-family: 'Fira Code', monospace !important;
    }
    
    code {
        color: #00ff00 !important;
        background-color: #000000 !important;
    }
    
    .stPlotlyChart {
        background-color: #000000;
        border: 1px solid #00ff00;
        padding: 5px;
    }
</style>
""", unsafe_allow_html=True)

def log(msg):
    """Simple logging"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

def get_connection():
    conn = sqlite3.connect(DB_PATH, timeout=30.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=30000")
    return conn

@st.cache_data(ttl=5)
def get_latest_metrics():
    """Get the most recent metrics from database"""
    conn = get_connection()
    try:
        query = """
        WITH latest AS (
            SELECT 
                host,
                metric_name,
                metric_value,
                timestamp,
                ROW_NUMBER() OVER (PARTITION BY host, metric_name ORDER BY timestamp DESC) as rn
            FROM metrics
            WHERE metric_value IS NOT NULL
        )
        SELECT 
            host as hostname,
            metric_name,
            metric_value as value,
            timestamp
        FROM latest
        WHERE rn = 1
        ORDER BY host, metric_name
        """
        df = pd.read_sql_query(query, conn)
        if not df.empty:
            log(f"Dashboard read {len(df)} metrics")
        return df
    except Exception as e:
        log(f"ERROR reading metrics: {e}")
        return pd.DataFrame()
    finally:
        conn.close()

@st.cache_data(ttl=5)
def get_time_series_for_metric(metric_pattern, minutes=30):
    """Get time series for specific metric pattern - much faster"""
    conn = get_connection()
    try:
        # Only get data for specific metric type, sample if too many points
        query = """
        WITH filtered AS (
            SELECT 
                host as hostname,
                metric_name,
                metric_value as value,
                timestamp,
                ROW_NUMBER() OVER (ORDER BY timestamp DESC) as rn
            FROM metrics
            WHERE timestamp >= datetime('now', ? || ' minutes')
            AND metric_value IS NOT NULL
            AND metric_name LIKE ?
        )
        SELECT hostname, metric_name, value, timestamp
        FROM filtered
        WHERE rn % CASE 
            WHEN (SELECT COUNT(*) FROM filtered) > 200 THEN ((SELECT COUNT(*) FROM filtered) / 100)
            ELSE 1
        END = 0
        ORDER BY timestamp DESC
        LIMIT 100
        """
        df = pd.read_sql_query(query, conn, params=[f'-{minutes}', f'%{metric_pattern}%'])
        
        if df.empty:
            # Fallback with same pattern
            query = """
            SELECT 
                host as hostname,
                metric_name,
                metric_value as value,
                timestamp
            FROM metrics
            WHERE metric_value IS NOT NULL
            AND metric_name LIKE ?
            ORDER BY timestamp DESC
            LIMIT 50
            """
            df = pd.read_sql_query(query, conn, params=[f'%{metric_pattern}%'])
        
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        return df
    finally:
        conn.close()

@st.cache_data(ttl=5)
def get_hosts():
    """Get all unique hosts"""
    conn = get_connection()
    try:
        result = conn.execute("SELECT DISTINCT host FROM metrics ORDER BY host").fetchall()
        return [row[0] for row in result]
    finally:
        conn.close()

def create_ascii_bar(value, max_value=100, width=20):
    """Create ASCII progress bar"""
    filled = int((value / max_value) * width)
    bar = "█" * filled + "░" * (width - filled)
    return bar

def create_simple_chart(data, title):
    """Create simple line chart using Streamlit native"""
    # Much faster than Plotly for simple charts
    st.markdown(f"**{title}**")
    if len(data) > 30:
        # Sample data for performance
        data = data.iloc[::max(1, len(data)//30)]
    # Use native Streamlit line chart - much faster
    st.line_chart(data, height=100, use_container_width=True)

# ============= MAIN DASHBOARD =============

# ASCII Art Header
header = """╔══════════════════════════════════════════════════════════════════════════════╗
║  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗║
║  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║║
║  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║║
║  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║║
║  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║║
║  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝║
║                         [SYSTEM MONITOR v2.0] [CYBERPUNK MODE]                 ║
╚══════════════════════════════════════════════════════════════════════════════╝"""

st.code(header, language="")

# Get data
metrics_df = get_latest_metrics()
hosts = get_hosts()

if metrics_df.empty:
    st.code("╔════════════════════════════════════════╗\n║     [⚠] NO DATA - AWAITING METRICS     ║\n╚════════════════════════════════════════╝", language="")
else:
    # Display metrics for each host
    for host in hosts:
        host_metrics = metrics_df[metrics_df['hostname'] == host]
        
        # Get key metrics
        cpu_metrics = host_metrics[host_metrics['metric_name'].str.contains('cpu', case=False, na=False)]
        cpu_val = cpu_metrics['value'].values[0] if len(cpu_metrics) > 0 and pd.notna(cpu_metrics['value'].values[0]) else 0
        
        mem_metrics = host_metrics[host_metrics['metric_name'].str.contains('memory|mem', case=False, na=False)]
        mem_val = mem_metrics['value'].values[0] if len(mem_metrics) > 0 and pd.notna(mem_metrics['value'].values[0]) else 0
        
        disk_metrics = host_metrics[host_metrics['metric_name'].str.contains('disk', case=False, na=False)]
        disk_val = disk_metrics['value'].values[0] if len(disk_metrics) > 0 and pd.notna(disk_metrics['value'].values[0]) else 0
        
        # Display host status box
        status_box = f"""┌─[ {host.upper()} ]{"─" * (73 - len(host))}┐
│ CPU    [{create_ascii_bar(cpu_val)}] {cpu_val:5.1f}% │
│ MEMORY [{create_ascii_bar(mem_val)}] {mem_val:5.1f}% │
│ DISK   [{create_ascii_bar(disk_val)}] {disk_val:5.1f}% │
└{"─" * 78}┘"""
        
        st.code(status_box, language="")
    
    # Performance graphs - load only what we need
    st.code("┌─[ PERFORMANCE GRAPHS ]─────────────────────────────────────────────────────┐", language="")
    
    col1, col2 = st.columns(2)
    
    with col1:
        cpu_data = get_time_series_for_metric('cpu', 30)
        if not cpu_data.empty:
            chart_data = cpu_data.groupby(['timestamp', 'hostname'])['value'].mean().unstack(fill_value=0)
            create_simple_chart(chart_data, "▶ CPU USAGE")
    
    with col2:
        mem_data = get_time_series_for_metric('memory', 30)
        if not mem_data.empty:
            chart_data = mem_data.groupby(['timestamp', 'hostname'])['value'].mean().unstack(fill_value=0)
            create_simple_chart(chart_data, "▶ MEMORY USAGE")
    
    col3, col4 = st.columns(2)
    
    with col3:
        disk_data = get_time_series_for_metric('disk', 30)
        if not disk_data.empty:
            chart_data = disk_data.groupby(['timestamp', 'hostname'])['value'].mean().unstack(fill_value=0)
            create_simple_chart(chart_data, "▶ DISK I/O")
    
    with col4:
        net_data = get_time_series_for_metric('network', 30)
        if not net_data.empty:
            chart_data = net_data.groupby(['timestamp', 'hostname'])['value'].mean().unstack(fill_value=0)
            create_simple_chart(chart_data, "▶ NETWORK")
    
    st.code("└" + "─" * 78 + "┘", language="")

# Footer
footer = f"""╔════════════════════════════════════════════════════════════════════════════╗
║ [TIME: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [AUTO-REFRESH: 5s] [STATUS: ONLINE]                 ║
╚════════════════════════════════════════════════════════════════════════════╝"""

st.code(footer, language="")

# Auto-refresh
if st.sidebar.checkbox("Auto-refresh", value=True):
    time.sleep(5)
    st.rerun()