#!/usr/bin/env python3
"""LUMENMON - Simple Terminal Dashboard"""
import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import sqlite3
import time

# Database path
DB_PATH = '/app/data/lumenmon.db'

# Page config - wide layout for terminal feel
st.set_page_config(
    page_title="LUMENMON",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Minimal CSS for phosphor glow effect only (theme handles colors)
st.markdown("""
<style>
    /* Phosphor glow effect for that CRT monitor feel */
    pre, code {
        text-shadow: 0 0 10px #00ff00, 0 0 20px #00ff00;
    }
    
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

# Header
st.code("""
╔═══════════════════════════════════════════════════════════════════════════════╗
║  LUMENMON SYSTEM MONITOR v2.0                              [TERMINAL MODE]    ║
╚═══════════════════════════════════════════════════════════════════════════════╝
""", language="")

# Database connection
@st.cache_resource
def get_connection():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

# Get latest metrics
@st.cache_data(ttl=5)
def get_latest_metrics():
    """Simple query for latest metrics"""
    try:
        conn = get_connection()
        query = """
        SELECT metric_name, metric_value, timestamp, host 
        FROM metrics 
        WHERE metric_value IS NOT NULL
        ORDER BY timestamp DESC 
        LIMIT 100
        """
        df = pd.read_sql_query(query, conn)
        return df
    except Exception as e:
        st.error(f"Database error: {e}")
        return pd.DataFrame()

# Get time series data
@st.cache_data(ttl=5)
def get_time_series():
    """Get last hour of data for charts"""
    try:
        conn = get_connection()
        query = """
        SELECT metric_name, metric_value, timestamp 
        FROM metrics 
        WHERE timestamp > datetime('now', '-1 hour')
        AND metric_value IS NOT NULL
        ORDER BY timestamp
        """
        df = pd.read_sql_query(query, conn)
        if not df.empty:
            df['timestamp'] = pd.to_datetime(df['timestamp'])
        return df
    except:
        return pd.DataFrame()

# Main content
col1, col2 = st.columns([1, 1])

with col1:
    st.code("═══ CURRENT STATUS ═══", language="")
    
    # Get latest metrics
    latest = get_latest_metrics()
    
    if not latest.empty:
        # Show key metrics
        for metric in ['cpu', 'memory', 'disk', 'network']:
            metric_data = latest[latest['metric_name'].str.contains(metric, case=False)]
            if not metric_data.empty:
                value = metric_data.iloc[0]['metric_value']
                st.code(f"{metric.upper():10} : {value:6.1f}", language="")
    else:
        st.code("NO DATA", language="")

with col2:
    st.code("═══ SYSTEM INFO ═══", language="")
    
    try:
        conn = get_connection()
        # Get database stats
        count = conn.execute("SELECT COUNT(*) FROM metrics").fetchone()[0]
        oldest = conn.execute("SELECT MIN(timestamp) FROM metrics").fetchone()[0]
        newest = conn.execute("SELECT MAX(timestamp) FROM metrics").fetchone()[0]
        
        st.code(f"TOTAL METRICS : {count}", language="")
        st.code(f"OLDEST DATA   : {oldest}", language="")
        st.code(f"NEWEST DATA   : {newest}", language="")
    except:
        st.code("DATABASE ERROR", language="")

# Time series graphs
st.code("═══ PERFORMANCE GRAPHS (LAST HOUR) ═══", language="")

time_series = get_time_series()

if not time_series.empty:
    # Create simple charts for each metric type
    col1, col2 = st.columns(2)
    
    with col1:
        # CPU chart
        cpu_data = time_series[time_series['metric_name'].str.contains('cpu', case=False)]
        if not cpu_data.empty:
            st.text("CPU USAGE")
            chart_data = cpu_data.pivot_table(index='timestamp', columns='metric_name', values='metric_value')
            st.line_chart(chart_data, height=200)
        
        # Memory chart  
        mem_data = time_series[time_series['metric_name'].str.contains('memory', case=False)]
        if not mem_data.empty:
            st.text("MEMORY USAGE")
            chart_data = mem_data.pivot_table(index='timestamp', columns='metric_name', values='metric_value')
            st.line_chart(chart_data, height=200)
    
    with col2:
        # Disk chart
        disk_data = time_series[time_series['metric_name'].str.contains('disk', case=False)]
        if not disk_data.empty:
            st.text("DISK USAGE")
            chart_data = disk_data.pivot_table(index='timestamp', columns='metric_name', values='metric_value')
            st.line_chart(chart_data, height=200)
        
        # Network chart
        net_data = time_series[time_series['metric_name'].str.contains('network', case=False)]
        if not net_data.empty:
            st.text("NETWORK")
            chart_data = net_data.pivot_table(index='timestamp', columns='metric_name', values='metric_value')
            st.line_chart(chart_data, height=200)
else:
    st.code("NO TIME SERIES DATA AVAILABLE", language="")

# Raw data table
st.code("═══ RAW METRICS DATA ═══", language="")

latest_full = get_latest_metrics()
if not latest_full.empty:
    # Display as simple table
    st.dataframe(
        latest_full,
        width='stretch',
        height=300
    )
else:
    st.code("NO DATA TO DISPLAY", language="")

# Footer with refresh info
st.code(f"""
╔═══════════════════════════════════════════════════════════════════════════════╗
║ {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | AUTO-REFRESH: 5s | STATUS: MONITORING            ║
╚═══════════════════════════════════════════════════════════════════════════════╝
""", language="")

# Auto-refresh
time.sleep(5)
st.rerun()