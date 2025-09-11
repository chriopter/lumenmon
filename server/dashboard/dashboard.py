#!/usr/bin/env python3
"""LUMENMON - Dead Simple Dashboard"""
import streamlit as st
import pandas as pd
import sqlite3
from datetime import datetime

# Page config
st.set_page_config(page_title="LUMENMON", layout="wide")

# Database connection
DB_PATH = '/app/data/lumenmon.db'

try:
    # Connect and get ALL data
    conn = sqlite3.connect(DB_PATH)
    
    # Title with pulse indicator
    col1, col2, col3 = st.columns([3, 1, 1])
    with col1:
        st.title("🟢 LUMENMON MONITOR")
    with col2:
        # Check pulse - is client alive?
        pulse_query = """
        SELECT MAX(timestamp) as last_pulse 
        FROM metrics 
        WHERE metric_name = 'generic_pulse_heartbeat'
        """
        pulse_result = conn.execute(pulse_query).fetchone()
        if pulse_result and pulse_result[0]:
            last_pulse = datetime.strptime(pulse_result[0], '%Y-%m-%d %H:%M:%S')
            seconds_ago = (datetime.now() - last_pulse).total_seconds()
            if seconds_ago < 10:
                st.markdown("### 💚 LIVE")
            elif seconds_ago < 30:
                st.markdown("### 💛 DELAYED")
            else:
                st.markdown("### 💔 OFFLINE")
        else:
            st.markdown("### ⚫ NO PULSE")
    with col3:
        st.markdown(f"### ⏰ {datetime.now().strftime('%H:%M:%S')}")
    
    st.markdown("---")
    
    # Show metrics count
    count = conn.execute("SELECT COUNT(*) FROM metrics").fetchone()[0]
    st.metric("Total Metrics in Database", count)
    
    # Get latest 100 metrics
    query = "SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 100"
    df = pd.read_sql_query(query, conn)
    
    # Show CPU Load Graph
    st.subheader("📊 CPU Load (Live)")
    
    # Get CPU load history
    cpu_query = """
    SELECT timestamp, metric_value 
    FROM metrics 
    WHERE metric_name = 'generic_cpu_load' 
    AND metric_value IS NOT NULL
    AND timestamp > datetime('now', '-10 minutes')
    ORDER BY timestamp DESC
    LIMIT 100
    """
    cpu_df = pd.read_sql_query(cpu_query, conn)
    
    if not cpu_df.empty:
        cpu_df['timestamp'] = pd.to_datetime(cpu_df['timestamp'])
        cpu_df = cpu_df.sort_values('timestamp')
        
        # Create line chart
        st.line_chart(
            data=cpu_df.set_index('timestamp')['metric_value'],
            height=300
        )
        
        # Show current value
        current_load = cpu_df.iloc[-1]['metric_value']
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Current Load", f"{current_load:.2f}")
        with col2:
            st.metric("Max (10min)", f"{cpu_df['metric_value'].max():.2f}")
        with col3:
            st.metric("Avg (10min)", f"{cpu_df['metric_value'].mean():.2f}")
    else:
        st.info("No CPU load data yet - waiting for metrics...")
    
    st.markdown("---")
    
    # Show System Snapshots (Blobs)
    st.subheader("📋 System Snapshots")
    
    # Get latest blob entries
    blob_query = """
    SELECT metric_name, metric_text, timestamp 
    FROM metrics 
    WHERE type = 'blob' 
    AND metric_text IS NOT NULL
    ORDER BY timestamp DESC
    LIMIT 20
    """
    blob_df = pd.read_sql_query(blob_query, conn)
    
    if not blob_df.empty:
        # Group by metric name to show latest of each type
        unique_blobs = blob_df.groupby('metric_name').first().reset_index()
        
        # Create columns for different blob types
        cols = st.columns(min(3, len(unique_blobs)))
        
        for idx, row in enumerate(unique_blobs.iterrows()):
            _, blob = row
            col_idx = idx % 3
            
            with cols[col_idx]:
                # Clean name for display
                display_name = blob['metric_name'].replace('generic_', '').replace('_', ' ').title()
                
                # Create an expander for each blob type
                with st.expander(f"🖥️ {display_name}", expanded=False):
                    st.caption(f"Last updated: {blob['timestamp']}")
                    
                    # Display the content in a code block
                    # The content should already be decoded from base64 by the sink
                    st.code(blob['metric_text'], language="bash")
                    
                    # Add a download button
                    st.download_button(
                        label="📥 Download",
                        data=blob['metric_text'],
                        file_name=f"{blob['metric_name']}_{blob['timestamp'].replace(' ', '_').replace(':', '-')}.txt",
                        mime="text/plain",
                        key=f"download_{blob['metric_name']}"
                    )
    else:
        st.info("No system snapshots available yet. Waiting for blob collectors (top, processes)...")
    
    st.markdown("---")
    
    # Show the raw data
    st.subheader("Latest Metrics")
    if not df.empty:
        st.dataframe(df, height=400)  # Fixed height with scrollbar
        
        # Simple line chart of all numeric values
        numeric_df = df[df['metric_value'].notna()].copy()
        if not numeric_df.empty:
            numeric_df['timestamp'] = pd.to_datetime(numeric_df['timestamp'])
            chart_data = numeric_df.pivot_table(
                index='timestamp', 
                columns='metric_name', 
                values='metric_value'
            )
            st.subheader("All Metrics Over Time")
            st.line_chart(chart_data)
    else:
        st.warning("No metrics in database")
    
    conn.close()
    
except Exception as e:
    st.error(f"Database Error: {e}")
    st.info(f"Looking for database at: {DB_PATH}")

# Refresh button
if st.button("🔄 Refresh"):
    st.rerun()

# Auto refresh
st.markdown("---")
st.caption(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Auto-refresh: 5s")

import time
time.sleep(5)
st.rerun()