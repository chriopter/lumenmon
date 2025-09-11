#!/usr/bin/env python3
"""LUMENMON - Dead Simple Dashboard"""
import streamlit as st
import pandas as pd
import sqlite3
from datetime import datetime

# Page config
st.set_page_config(page_title="LUMENMON", layout="wide")

# Title
st.title("🟢 LUMENMON MONITOR")
st.markdown("---")

# Database connection
DB_PATH = '/app/data/lumenmon.db'

try:
    # Connect and get ALL data
    conn = sqlite3.connect(DB_PATH)
    
    # Show metrics count
    count = conn.execute("SELECT COUNT(*) FROM metrics").fetchone()[0]
    st.metric("Total Metrics in Database", count)
    
    # Get latest 100 metrics
    query = "SELECT * FROM metrics ORDER BY timestamp DESC LIMIT 100"
    df = pd.read_sql_query(query, conn)
    
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
            st.subheader("Metrics Over Time")
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