#!/usr/bin/env python3
"""LUMENMON - Multi-Client Dashboard"""
import streamlit as st
import pandas as pd
import sqlite3
from datetime import datetime, timedelta

# Page config
st.set_page_config(
    page_title="LUMENMON Terminal", 
    layout="wide", 
    initial_sidebar_state="collapsed",
    page_icon="🖥️"
)

# Database connection
DB_PATH = '/app/data/lumenmon.db'

# Terminal UI Helper Functions
def create_progress_bar(value, max_value=100, width=20, style='blocks'):
    """Create a terminal-style progress bar"""
    if max_value == 0:
        return "[" + "░" * width + "]"
    
    percentage = min(100, (value / max_value) * 100)
    filled = int((percentage / 100) * width)
    
    if style == 'blocks':
        # Use different block characters for gradient effect
        if percentage < 25:
            bar = "█" * filled + "░" * (width - filled)
        elif percentage < 50:
            bar = "█" * filled + "▒" * min(2, width - filled) + "░" * max(0, width - filled - 2)
        elif percentage < 75:
            bar = "█" * filled + "▓" * min(3, width - filled) + "▒" * max(0, width - filled - 3)
        else:
            bar = "█" * filled + "░" * (width - filled)
    elif style == 'ascii':
        bar = "=" * filled + "-" * (width - filled)
    elif style == 'dots':
        bar = "●" * filled + "○" * (width - filled)
    else:
        bar = "#" * filled + " " * (width - filled)
    
    return f"[{bar}]"

def create_gauge(value, max_value=100, width=10):
    """Create a vertical or horizontal gauge"""
    if max_value == 0:
        return "│" + " " * width + "│"
    
    percentage = min(100, (value / max_value) * 100)
    filled = int((percentage / 100) * width)
    
    return "│" + "█" * filled + "░" * (width - filled) + "│"

def format_bytes(bytes_value):
    """Format bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f}{unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f}PB"

# Custom CSS for 80s Terminal Theme
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;700&display=swap');
    
    /* Global Terminal Styling */
    .stApp {
        background: #000000;
        background-image: 
            repeating-linear-gradient(
                0deg,
                rgba(0, 255, 0, 0.03),
                rgba(0, 255, 0, 0.03) 1px,
                transparent 1px,
                transparent 2px
            );
        animation: scanlines 8s linear infinite;
    }
    
    @keyframes scanlines {
        0% { background-position: 0 0; }
        100% { background-position: 0 10px; }
    }
    
    /* Terminal Font - Compact */
    * {
        font-family: 'Fira Code', 'Courier New', monospace !important;
        font-size: 12px !important;
        line-height: 1.3 !important;
    }
    
    /* Green Phosphor Text */
    p, span, div, h1, h2, h3, h4, h5, h6, label {
        color: #00ff00 !important;
        text-shadow: 
            0 0 5px rgba(0, 255, 0, 0.5),
            0 0 10px rgba(0, 255, 0, 0.3),
            0 0 15px rgba(0, 255, 0, 0.1);
    }
    
    /* Metrics Cards */
    .stMetric {
        background: rgba(0, 0, 0, 0.8);
        border: 1px solid #00ff00;
        padding: 10px;
        border-radius: 0;
        box-shadow: 
            inset 0 0 20px rgba(0, 255, 0, 0.1),
            0 0 20px rgba(0, 255, 0, 0.2);
    }
    
    [data-testid="metric-container"] {
        background: rgba(0, 0, 0, 0.9);
        border: 1px solid #00ff00;
        padding: 10px;
        margin: 5px;
        box-shadow: inset 0 0 10px rgba(0, 255, 0, 0.1);
    }
    
    /* Terminal Boxes */
    .terminal-box {
        background: #000000;
        border: 1px solid #00ff00;
        padding: 5px;
        margin: 5px 0;
        font-family: 'Fira Code', monospace;
        font-size: 11px;
        color: #00ff00;
        box-shadow: 
            inset 0 0 20px rgba(0, 255, 0, 0.05),
            0 0 10px rgba(0, 255, 0, 0.2);
        position: relative;
        overflow: hidden;
    }
    
    .terminal-box::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 1px;
        background: linear-gradient(90deg, transparent, #00ff00, transparent);
        animation: scan 4s linear infinite;
    }
    
    @keyframes scan {
        0% { transform: translateY(0); }
        100% { transform: translateY(100vh); }
    }
    
    /* Progress Bars */
    .stProgress > div > div > div > div {
        background: #00ff00;
        box-shadow: 0 0 10px #00ff00;
    }
    
    /* Buttons */
    .stButton > button {
        background: #000000;
        color: #00ff00;
        border: 1px solid #00ff00;
        border-radius: 0;
        text-transform: uppercase;
        font-weight: bold;
        letter-spacing: 2px;
        transition: all 0.3s;
        box-shadow: 
            inset 0 0 0 0 #00ff00,
            0 0 10px rgba(0, 255, 0, 0.2);
    }
    
    .stButton > button:hover {
        background: #00ff00;
        color: #000000;
        box-shadow: 
            inset 0 0 10px #000000,
            0 0 20px #00ff00;
        text-shadow: none;
    }
    
    /* CRT Monitor Effect */
    .crt-effect {
        animation: flicker 0.15s infinite;
    }
    
    @keyframes flicker {
        0% { opacity: 0.98; }
        50% { opacity: 1; }
        100% { opacity: 0.98; }
    }
    
    /* Tabs */
    .stTabs [data-baseweb="tab-list"] {
        background: #000000;
        border-bottom: 1px solid #00ff00;
    }
    
    .stTabs [data-baseweb="tab"] {
        color: #00ff00 !important;
        background: #000000;
        border: 1px solid #00ff00;
        border-bottom: none;
        margin-right: 5px;
    }
    
    .stTabs [aria-selected="true"] {
        background: #00ff00 !important;
        color: #000000 !important;
    }
    
    /* Expanders */
    .streamlit-expanderHeader {
        background: #000000;
        border: 1px solid #00ff00;
        color: #00ff00 !important;
    }
    
    /* DataFrames */
    .dataframe {
        background: #000000 !important;
        color: #00ff00 !important;
        border: 1px solid #00ff00 !important;
    }
    
    .dataframe th {
        background: #003300 !important;
        color: #00ff00 !important;
        border: 1px solid #00ff00 !important;
    }
    
    .dataframe td {
        background: #000000 !important;
        color: #00ff00 !important;
        border: 1px solid #003300 !important;
    }
    
    /* ASCII Header */
    .ascii-header {
        color: #00ff00;
        font-family: 'Courier New', monospace;
        text-align: center;
        white-space: pre;
        line-height: 1;
        text-shadow: 
            0 0 10px #00ff00,
            0 0 20px #00ff00,
            0 0 30px #00ff00;
        animation: pulse 2s ease-in-out infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.8; }
    }
    
    /* Terminal Cursor */
    .cursor {
        display: inline-block;
        width: 10px;
        height: 20px;
        background: #00ff00;
        animation: blink 1s infinite;
    }
    
    @keyframes blink {
        0%, 49% { opacity: 1; }
        50%, 100% { opacity: 0; }
    }
    
    /* Hide Streamlit Branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    .stDeployButton {display: none;}
    
    /* Custom Scrollbar */
    ::-webkit-scrollbar {
        width: 10px;
        background: #000000;
    }
    
    ::-webkit-scrollbar-thumb {
        background: #00ff00;
        border: 1px solid #003300;
    }
    
    ::-webkit-scrollbar-track {
        background: #001100;
        border: 1px solid #003300;
    }
</style>
""", unsafe_allow_html=True)

def get_client_metrics(conn, client_id, metric_name):
    """Get latest metric value for a client"""
    try:
        query = f"""
        SELECT metric_value 
        FROM metrics_{client_id}
        WHERE metric_name = ?
        AND metric_value IS NOT NULL
        ORDER BY timestamp DESC
        LIMIT 1
        """
        result = conn.execute(query, (metric_name,)).fetchone()
        return result[0] if result else 0
    except:
        return 0

def get_client_status(conn, client_id):
    """Check if client is online (data in last 30 seconds)"""
    try:
        query = f"""
        SELECT COUNT(*) 
        FROM metrics_{client_id}
        WHERE timestamp > datetime('now', '-30 seconds')
        """
        count = conn.execute(query).fetchone()[0]
        return count > 0
    except:
        return False

def show_client_overview():
    """Show all clients with CPU bars"""
    conn = sqlite3.connect(DB_PATH)
    
    # ASCII Art Header - Compact Version
    st.markdown("""
<div class="ascii-header" style="text-align: center; margin: 5px 0;">
<pre style="color: #00ff00; font-size: 8px; line-height: 0.8; margin: 0;">
╔═══════════════════════════════════════════════════════════════════════════════╗
║  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗║
║  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║║
║  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║║
║  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║║
║  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║║
║  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝║
║                    [ SYSTEM MONITORING TERMINAL v4.2.0 ]                       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
</pre>
</div>
""", unsafe_allow_html=True)
    
    # Compact Status Bar
    col1, col2, col3, col4 = st.columns([2, 2, 3, 3])
    with col1:
        st.markdown(f"""<div class="terminal-box" style="font-size: 11px; padding: 3px;">📡 ONLINE</div>""", unsafe_allow_html=True)
    with col2:
        st.markdown(f"""<div class="terminal-box" style="font-size: 11px; padding: 3px;">⏱️ {datetime.now().strftime('%H:%M:%S')}</div>""", unsafe_allow_html=True)
    with col3:
        st.markdown(f"""<div class="terminal-box" style="font-size: 11px; padding: 3px;">📅 {datetime.now().strftime('%Y-%m-%d')}</div>""", unsafe_allow_html=True)
    with col4:
        st.markdown(f"""<div class="terminal-box" style="font-size: 11px; padding: 3px;">🔄 AUTO-REFRESH: 5s</div>""", unsafe_allow_html=True)
    
    # Check for pending registrations (directly from database)
    pending_query = """
    SELECT fingerprint, hostname, pubkey, first_seen, attempt_count
    FROM pending_registrations
    ORDER BY first_seen DESC
    """
    try:
        print(f"[DASHBOARD] Checking for pending registrations...")
        pending_df = pd.read_sql_query(pending_query, conn)
        print(f"[DASHBOARD] Found {len(pending_df)} pending registrations")
        
        if not pending_df.empty:
            with st.expander(f"[⚠️ PENDING REGISTRATIONS: {len(pending_df)}]", expanded=True):
                st.markdown("""
<div style="color: #ffff00; border: 1px solid #ffff00; padding: 10px; margin: 10px 0; 
            background: rgba(255, 255, 0, 0.05); animation: blink 2s infinite;">
⚠️ NEW CLIENTS AWAITING AUTHORIZATION ⚠️
</div>
""", unsafe_allow_html=True)
                
                for _, reg in pending_df.iterrows():
                    st.markdown(f"""
<div style="border: 1px solid #00ff00; padding: 5px; margin: 5px 0; font-family: monospace;">
┌─ HOST: {reg['hostname']}<br/>
├─ FINGERPRINT: {reg['fingerprint'][:30]}...<br/>
└─ ATTEMPTS: {reg['attempt_count']}
</div>
""", unsafe_allow_html=True)
                    
                    col1, col2, col3 = st.columns([1, 1, 6])
                    with col1:
                        if st.button("[APPROVE]", key=f"approve_new_{reg['fingerprint'][:10]}"):
                            print(f"[DASHBOARD] Approve button clicked for {reg['hostname']}")
                            print(f"[DASHBOARD] Fingerprint: {reg['fingerprint']}")
                            print(f"[DASHBOARD] Pubkey length: {len(reg['pubkey']) if reg['pubkey'] else 'None'}")
                            
                            # Use a separate connection for write operations
                            import time
                            max_retries = 5
                            retry_count = 0
                            
                            while retry_count < max_retries:
                                try:
                                    print(f"[DASHBOARD] Attempt {retry_count + 1} - Connecting to database...")
                                    write_conn = sqlite3.connect(DB_PATH, timeout=30.0)
                                    write_conn.execute("PRAGMA journal_mode=WAL")
                                    write_conn.execute("PRAGMA busy_timeout=30000")
                                    
                                    print(f"[DASHBOARD] Inserting into clients table...")
                                    # Move from pending to clients table
                                    write_conn.execute("""
                                        INSERT OR REPLACE INTO clients (hostname, pubkey, fingerprint, status, created_at, last_seen)
                                        VALUES (?, ?, ?, 'approved', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                                    """, (reg['hostname'], reg['pubkey'], reg['fingerprint']))
                                    
                                    print(f"[DASHBOARD] Removing from pending_registrations...")
                                    # Remove from pending
                                    write_conn.execute("DELETE FROM pending_registrations WHERE fingerprint = ?", (reg['fingerprint'],))
                                    
                                    print(f"[DASHBOARD] Committing transaction...")
                                    write_conn.commit()
                                    write_conn.close()
                                    
                                    print(f"[DASHBOARD] Syncing SSH authorized_keys...")
                                    # Sync authorized_keys to allow SSH access
                                    try:
                                        sync_conn = sqlite3.connect(DB_PATH)
                                        c = sync_conn.cursor()
                                        c.execute("SELECT pubkey FROM clients WHERE status = 'approved'")
                                        approved_keys = c.fetchall()
                                        sync_conn.close()
                                        
                                        # Write authorized_keys file
                                        import os
                                        ssh_dir = '/home/metrics/.ssh'
                                        os.makedirs(ssh_dir, exist_ok=True)
                                        auth_file = os.path.join(ssh_dir, 'authorized_keys')
                                        
                                        print(f"[DASHBOARD] Writing {len(approved_keys)} SSH keys to {auth_file}")
                                        with open(auth_file, 'w') as f:
                                            for i, key_row in enumerate(approved_keys):
                                                key = key_row[0].strip()
                                                f.write(f"{key}\n")
                                                print(f"[DASHBOARD] Key {i+1}: {key[:50]}...")
                                        
                                        # Set correct permissions
                                        os.chmod(auth_file, 0o600)
                                        os.system(f"chown metrics:metrics {auth_file}")
                                        
                                        # Verify write and show debug info
                                        with open(auth_file, 'r') as f:
                                            lines = f.readlines()
                                            print(f"[DASHBOARD] ✅ Authorized_keys updated with {len(lines)} keys")
                                        
                                        # Debug: Show file permissions and contents
                                        import subprocess
                                        print("[DASHBOARD] === SSH DEBUG INFO ===")
                                        result = subprocess.run(['ls', '-la', '/home/metrics/.ssh/'], capture_output=True, text=True)
                                        print(f"[DASHBOARD] Directory listing:\n{result.stdout}")
                                        
                                        result = subprocess.run(['cat', auth_file], capture_output=True, text=True)
                                        print(f"[DASHBOARD] authorized_keys contents:\n{result.stdout}")
                                        
                                        result = subprocess.run(['id', 'metrics'], capture_output=True, text=True)
                                        print(f"[DASHBOARD] metrics user info: {result.stdout.strip()}")
                                        
                                        # Reload SSH daemon to pick up new keys
                                        print("[DASHBOARD] Reloading SSH daemon to pick up new authorized_keys...")
                                        result = subprocess.run(['killall', '-HUP', 'sshd'], capture_output=True, text=True)
                                        if result.returncode == 0:
                                            print("[DASHBOARD] ✅ SSH daemon reloaded successfully")
                                        else:
                                            print(f"[DASHBOARD] ⚠️ Could not reload SSH daemon: {result.stderr}")
                                        
                                        print("[DASHBOARD] === END DEBUG INFO ===")
                                    except Exception as sync_error:
                                        print(f"[DASHBOARD] Warning: Could not sync SSH keys: {sync_error}")
                                    
                                    print(f"[DASHBOARD] SUCCESS - Client approved!")
                                    st.success("✅ Client approved and SSH access granted!")
                                    time.sleep(0.5)  # Brief pause before rerun
                                    st.rerun()
                                    break
                                except sqlite3.OperationalError as e:
                                    print(f"[DASHBOARD] SQLite Operational Error: {e}")
                                    if "locked" in str(e) and retry_count < max_retries - 1:
                                        retry_count += 1
                                        print(f"[DASHBOARD] Database locked, retry {retry_count}/{max_retries}")
                                        time.sleep(0.5)  # Wait before retry
                                        continue
                                    else:
                                        st.error(f"Database error: {str(e)}")
                                        print(f"[DASHBOARD] FAILED after {retry_count + 1} attempts: {e}")
                                        break
                                except Exception as e:
                                    st.error(f"Failed to approve: {str(e)}")
                                    print(f"[DASHBOARD] EXCEPTION: {type(e).__name__}: {e}")
                                    import traceback
                                    print(f"[DASHBOARD] Traceback:\n{traceback.format_exc()}")
                                    break
                    
                    with col2:
                        if st.button("[REJECT]", key=f"reject_new_{reg['fingerprint'][:10]}"):
                            # Use separate connection with retries
                            max_retries = 5
                            retry_count = 0
                            
                            while retry_count < max_retries:
                                try:
                                    write_conn = sqlite3.connect(DB_PATH, timeout=30.0)
                                    write_conn.execute("PRAGMA journal_mode=WAL")
                                    write_conn.execute("PRAGMA busy_timeout=30000")
                                    
                                    # Just remove from pending
                                    write_conn.execute("DELETE FROM pending_registrations WHERE fingerprint = ?", (reg['fingerprint'],))
                                    write_conn.commit()
                                    write_conn.close()
                                    
                                    st.info("Client rejected")
                                    time.sleep(0.5)
                                    st.rerun()
                                    break
                                except sqlite3.OperationalError as e:
                                    if "locked" in str(e) and retry_count < max_retries - 1:
                                        retry_count += 1
                                        time.sleep(0.5)
                                        continue
                                    else:
                                        st.error(f"Database error: {str(e)}")
                                        break
                                except Exception as e:
                                    st.error(f"Failed to reject: {str(e)}")
                                    break
    except Exception as e:
        # Table might not exist yet
        pass
    
    # Get all approved clients
    clients_query = """
    SELECT id, hostname, last_seen, fingerprint
    FROM clients 
    WHERE status = 'approved'
    ORDER BY hostname
    """
    clients_df = pd.read_sql_query(clients_query, conn)
    
    if clients_df.empty:
        st.markdown("""
<div style="color: #ffff00; border: 2px solid #ffff00; padding: 20px; margin: 20px 0; text-align: center;">
⚠️ NO APPROVED CLIENTS DETECTED ⚠️<br/>
Awaiting client registration and authorization...
</div>
""", unsafe_allow_html=True)
        return
    
    # Fleet Statistics Section FIRST
    st.markdown("""
<div class="terminal-section" style="margin-top: 10px;">
    <div class="terminal-header" style="text-align: center;">
        <pre style="color: #00ff00; margin: 0; font-size: 12px; line-height: 1.1;">
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           FLEET STATISTICS                                    ║
╚═══════════════════════════════════════════════════════════════════════════════╝
        </pre>
    </div>
    <div class="terminal-content">
""", unsafe_allow_html=True)
    
    # Calculate statistics
    total_clients = len(clients_df)
    online_count = sum(1 for _, client in clients_df.iterrows() if get_client_status(conn, client['id']))
    avg_cpu = sum(get_client_metrics(conn, client['id'], 'generic_cpu_usage') 
                 for _, client in clients_df.iterrows()) / len(clients_df) if len(clients_df) > 0 else 0
    avg_mem = sum(get_client_metrics(conn, client['id'], 'generic_memory_percent') 
                 for _, client in clients_df.iterrows()) / len(clients_df) if len(clients_df) > 0 else 0
    
    # Display current stats with better spacing
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown(f"""
<div class="terminal-box" style="text-align: center; font-size: 11px; padding: 5px;">
TOTAL<br/>
<span style="font-size: 18px; font-weight: bold;">{total_clients}</span>
</div>
""", unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
<div class="terminal-box" style="text-align: center; font-size: 11px; padding: 5px;">
ONLINE<br/>
<span style="font-size: 18px; font-weight: bold; color: {'#00ff00' if online_count > 0 else '#ff0000'};">{online_count}/{total_clients}</span>
</div>
""", unsafe_allow_html=True)
    
    with col3:
        cpu_color = '#00ff00' if avg_cpu < 50 else '#ffff00' if avg_cpu < 80 else '#ff0000'
        st.markdown(f"""
<div class="terminal-box" style="text-align: center; font-size: 11px; padding: 5px;">
CPU<br/>
<span style="font-size: 18px; font-weight: bold; color: {cpu_color};">{avg_cpu:.1f}%</span>
</div>
""", unsafe_allow_html=True)
    
    with col4:
        mem_color = '#00ff00' if avg_mem < 50 else '#ffff00' if avg_mem < 80 else '#ff0000'
        st.markdown(f"""
<div class="terminal-box" style="text-align: center; font-size: 11px; padding: 5px;">
MEM<br/>
<span style="font-size: 18px; font-weight: bold; color: {mem_color};">{avg_mem:.1f}%</span>
</div>
""", unsafe_allow_html=True)
    
    # Add real-time history graphs (last 60 seconds)
    st.markdown("""
<div style="margin-top: 10px; padding: 8px; border: 1px solid #00ff00;">
    <h3 style="text-align: center; color: #00ff00; letter-spacing: 2px; font-size: 12px; margin: 0;">REAL-TIME METRICS (60s)</h3>
</div>
""", unsafe_allow_html=True)
    
    # Create two columns for CPU and Memory graphs
    graph_col1, graph_col2 = st.columns(2)
    
    with graph_col1:
        st.markdown("""
<div style="border: 1px solid #00ff00; padding: 5px; margin: 5px 0;">
<h4 style="color: #00ff00; text-align: center; font-size: 12px; margin: 0;">CPU USAGE HISTORY</h4>
</div>
""", unsafe_allow_html=True)
        
        # Get historical CPU data for all clients (last 60 seconds)
        try:
            cpu_data_frames = []
            for _, client in clients_df.iterrows():
                query = f"""
                SELECT timestamp, metric_value as cpu_usage
                FROM metrics_{client['id']}
                WHERE metric_name = 'generic_cpu_usage' 
                AND metric_value IS NOT NULL
                AND timestamp > datetime('now', '-60 seconds')
                ORDER BY timestamp ASC
                """
                try:
                    df = pd.read_sql_query(query, conn)
                    if not df.empty:
                        df['timestamp'] = pd.to_datetime(df['timestamp'])
                        df['client'] = client['hostname']
                        cpu_data_frames.append(df)
                except:
                    pass
            
            if cpu_data_frames:
                # Combine all client data
                combined_cpu_df = pd.concat(cpu_data_frames, ignore_index=True)
                
                # Create average CPU across all clients
                avg_cpu_df = combined_cpu_df.groupby('timestamp')['cpu_usage'].mean().reset_index()
                avg_cpu_df.columns = ['timestamp', 'Average CPU %']
                
                # Create Streamlit line chart with green theme
                if not avg_cpu_df.empty:
                    # Style the chart with custom configuration
                    st.line_chart(
                        avg_cpu_df.set_index('timestamp'),
                        use_container_width=True,
                        height=150,
                        color='#00ff00'
                    )
                    
                    # Show statistics
                    avg_val = avg_cpu_df['Average CPU %'].mean()
                    max_val = avg_cpu_df['Average CPU %'].max()
                    st.markdown(f"""
<div style="text-align: center; color: #00ff00; font-size: 14px;">
Avg: {avg_val:.1f}% | Max: {max_val:.1f}%
</div>
""", unsafe_allow_html=True)
                else:
                    st.info("No CPU data to display")
            else:
                st.info("No CPU history available")
        except Exception as e:
            st.info(f"CPU history unavailable: {str(e)}")
    
    with graph_col2:
        st.markdown("""
<div style="border: 1px solid #00ff00; padding: 5px; margin: 5px 0;">
<h4 style="color: #00ff00; text-align: center; font-size: 12px; margin: 0;">MEMORY USAGE HISTORY</h4>
</div>
""", unsafe_allow_html=True)
        
        # Get historical Memory data for all clients (last 60 seconds)
        try:
            mem_data_frames = []
            for _, client in clients_df.iterrows():
                query = f"""
                SELECT timestamp, metric_value as memory_usage
                FROM metrics_{client['id']}
                WHERE metric_name = 'generic_memory_percent' 
                AND metric_value IS NOT NULL
                AND timestamp > datetime('now', '-60 seconds')
                ORDER BY timestamp ASC
                """
                try:
                    df = pd.read_sql_query(query, conn)
                    if not df.empty:
                        df['timestamp'] = pd.to_datetime(df['timestamp'])
                        df['client'] = client['hostname']
                        mem_data_frames.append(df)
                except:
                    pass
            
            if mem_data_frames:
                # Combine all client data
                combined_mem_df = pd.concat(mem_data_frames, ignore_index=True)
                
                # Create average Memory across all clients
                avg_mem_df = combined_mem_df.groupby('timestamp')['memory_usage'].mean().reset_index()
                avg_mem_df.columns = ['timestamp', 'Average Memory %']
                
                # Create Streamlit line chart with green theme
                if not avg_mem_df.empty:
                    # Style the chart
                    st.line_chart(
                        avg_mem_df.set_index('timestamp'),
                        use_container_width=True,
                        height=150,
                        color='#00ff00'
                    )
                    
                    # Show statistics
                    avg_val = avg_mem_df['Average Memory %'].mean()
                    max_val = avg_mem_df['Average Memory %'].max()
                    st.markdown(f"""
<div style="text-align: center; color: #00ff00; font-size: 14px;">
Avg: {avg_val:.1f}% | Max: {max_val:.1f}%
</div>
""", unsafe_allow_html=True)
                else:
                    st.info("No memory data to display")
            else:
                st.info("No memory history available")
        except Exception as e:
            st.info(f"Memory history unavailable: {str(e)}")
    
    # Close the fleet statistics section
    st.markdown("</div></div>", unsafe_allow_html=True)
    
    # Connected Clients Section
    st.markdown("""
<div class="terminal-section" style="margin-top: 10px;">
    <div class="terminal-header" style="text-align: center;">
        <pre style="color: #00ff00; margin: 0; font-size: 12px; line-height: 1.1;">
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           CONNECTED CLIENTS                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
        </pre>
    </div>
    <div class="terminal-content">
""", unsafe_allow_html=True)
    
    # Create compact list
    for _, client in clients_df.iterrows():
        # Get metrics
        is_online = get_client_status(conn, client['id'])
        cpu_usage = get_client_metrics(conn, client['id'], 'generic_cpu_usage')
        memory_pct = get_client_metrics(conn, client['id'], 'generic_memory_percent')
        load = get_client_metrics(conn, client['id'], 'generic_cpu_load')
        
        # Calculate heartbeat symbol
        if client['last_seen']:
            last_seen = datetime.fromisoformat(client['last_seen'])
            time_ago = (datetime.now() - last_seen).total_seconds()
            if time_ago < 10:
                beat = "💚"  # Fresh heartbeat
            elif time_ago < 30:
                beat = "💛"  # Recent
            elif time_ago < 60:
                beat = "🧡"  # Aging
            else:
                beat = "❤️"  # Old
        else:
            beat = "🖤"  # No heartbeat
        
        # Create CPU bar (btop style) with gradient blocks
        cpu_blocks = int(cpu_usage / 5)  # 20 blocks total
        if cpu_usage < 25:
            cpu_bar = "█" * cpu_blocks + "░" * (20 - cpu_blocks)
        elif cpu_usage < 50:
            cpu_bar = "█" * cpu_blocks + "▒" * min(5, 20 - cpu_blocks) + "░" * max(0, 15 - cpu_blocks)
        elif cpu_usage < 75:
            cpu_bar = "█" * cpu_blocks + "▓" * min(5, 20 - cpu_blocks) + "▒" * max(0, 15 - cpu_blocks) + "░" * max(0, 10 - cpu_blocks)
        else:
            cpu_bar = "█" * min(20, cpu_blocks) + "░" * max(0, 20 - cpu_blocks)
        
        # Terminal-style status indicators
        if cpu_usage < 50:
            cpu_status = "[OK]"
        elif cpu_usage < 80:
            cpu_status = "[WARN]"
        else:
            cpu_status = "[CRIT]"
        
        # Terminal-style client display
        client_status = "ONLINE" if is_online else "OFFLINE"
        status_char = "●" if is_online else "○"
        
        # Format uptime
        if is_online and client['last_seen']:
            uptime_seconds = time_ago
            if uptime_seconds < 60:
                uptime_str = f"{int(uptime_seconds)}s"
            elif uptime_seconds < 3600:
                uptime_str = f"{int(uptime_seconds/60)}m"
            else:
                uptime_str = f"{int(uptime_seconds/3600)}h"
        else:
            uptime_str = "--"
        
        # Create clickable client line - entire line is a button
        client_text = f"{status_char} {client['hostname'][:15]:<15} │ CPU:[{cpu_bar}] {cpu_usage:3.0f}% │ MEM:{memory_pct:3.0f}% │ LOAD:{load:4.1f} │ UP:{uptime_str:>5} │ {client_status}"
        
        if st.button(
            client_text,
            key=f"client_{client['id']}", 
            use_container_width=True,
            help=f"Click to view detailed metrics for {client['hostname']}"
        ):
            st.session_state.selected_client = client['id']
            st.session_state.selected_hostname = client['hostname']
            st.rerun()
    
    # Close the connected clients section
    st.markdown("</div></div>", unsafe_allow_html=True)
    
    # Client Management Section with terminal styling
    st.markdown("""
<div class="terminal-section" style="margin-top: 20px;">
    <div class="terminal-header" style="text-align: center;">
        <pre style="color: #00ff00; margin: 0; font-size: 16px;">
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           CLIENT MANAGEMENT                                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
        </pre>
    </div>
</div>
""", unsafe_allow_html=True)
    
    with st.expander("[🔧 SYSTEM ADMINISTRATION]", expanded=False):
        # Get all clients
        all_clients_query = """
        SELECT id, hostname, fingerprint, status, created_at, last_seen
        FROM clients 
        ORDER BY created_at DESC
        """
        all_clients_df = pd.read_sql_query(all_clients_query, conn)
        
        if not all_clients_df.empty:
            for _, client in all_clients_df.iterrows():
                status_map = {"approved": "[ACTIVE]", "pending": "[PENDING]", "rejected": "[REVOKED]"}
                status_color = {"approved": "#00ff00", "pending": "#ffff00", "rejected": "#ff0000"}.get(client['status'], "#ffffff")
                
                st.markdown(f"""
<div style="border: 1px solid {status_color}; padding: 5px; margin: 5px 0; font-family: monospace;">
<span style="color: {status_color};">
ID:{client['id']:03d} │ HOST:{client['hostname']:<20} │ {status_map.get(client['status'], '[UNKNOWN]'):<10} │ FP:{client['fingerprint'][:20]}...
</span>
</div>
""", unsafe_allow_html=True)
                
                col1, col2, col3 = st.columns([1, 1, 8])
                with col1:
                    if client['status'] != 'approved' and st.button("[APPROVE]", key=f"mgmt_approve_{client['id']}"):
                        conn.execute("UPDATE clients SET status='approved' WHERE id=?", (client['id'],))
                        conn.commit()
                        st.rerun()
                with col2:
                    if client['status'] == 'approved' and st.button("[REVOKE]", key=f"mgmt_revoke_{client['id']}"):
                        conn.execute("UPDATE clients SET status='rejected' WHERE id=?", (client['id'],))
                        conn.commit()
                        st.rerun()
    
    conn.close()

def show_client_detail(client_id, hostname):
    """Show detailed view for a specific client"""
    conn = sqlite3.connect(DB_PATH)
    
    # Back button with terminal style
    if st.button("[← BACK TO OVERVIEW]"):
        del st.session_state.selected_client
        del st.session_state.selected_hostname
        st.rerun()
    
    # Terminal-style header
    st.markdown(f"""
<div style="color: #00ff00; font-family: 'Fira Code', monospace;">
┌──────────────────────────────────────────────────────────────────────────────┐
│ CLIENT: {hostname.upper():<69} │
│ ID: {client_id:<73} │
└──────────────────────────────────────────────────────────────────────────────┘
</div>
""", unsafe_allow_html=True)
    
    # Check online status with terminal style
    is_online = get_client_status(conn, client_id)
    status_text = "[ONLINE]" if is_online else "[OFFLINE]"
    status_color = "#00ff00" if is_online else "#ff0000"
    st.markdown(f"""
<div style="color: {status_color}; font-size: 20px; font-weight: bold; text-align: center; 
            border: 2px solid {status_color}; padding: 10px; margin: 10px 0;
            animation: {'pulse 2s infinite' if is_online else 'none'};
            box-shadow: 0 0 20px {status_color};">
    {status_text}
</div>
""", unsafe_allow_html=True)
    
    # Create tabs for different metric types with terminal style
    tab1, tab2, tab3, tab4, tab5 = st.tabs(["[OVERVIEW]", "[CPU]", "[MEMORY]", "[DISK]", "[NETWORK]"])
    
    with tab1:
        # Overview metrics with terminal gauge style
        st.markdown("""
<div style="color: #00ff00; border: 1px solid #00ff00; padding: 10px; margin: 10px 0;">
┌─────────────────────────── SYSTEM OVERVIEW ───────────────────────────┐
</div>
""", unsafe_allow_html=True)
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            cpu = get_client_metrics(conn, client_id, 'generic_cpu_usage')
            # Create terminal-style gauge
            cpu_gauge = int(cpu / 10)
            gauge = "[" + "█" * cpu_gauge + "░" * (10 - cpu_gauge) + "]"
            st.markdown(f"""
<div class="terminal-box">
CPU USAGE<br/>
{gauge}<br/>
{cpu:.1f}%
</div>
""", unsafe_allow_html=True)
        
        with col2:
            mem = get_client_metrics(conn, client_id, 'generic_memory_percent')
            mem_gauge = int(mem / 10)
            gauge = "[" + "█" * mem_gauge + "░" * (10 - mem_gauge) + "]"
            st.markdown(f"""
<div class="terminal-box">
MEMORY<br/>
{gauge}<br/>
{mem:.1f}%
</div>
""", unsafe_allow_html=True)
        
        with col3:
            load = get_client_metrics(conn, client_id, 'generic_cpu_load')
            st.markdown(f"""
<div class="terminal-box">
LOAD AVG<br/>
║ {load:.2f} ║
</div>
""", unsafe_allow_html=True)
        
        with col4:
            uptime = get_client_metrics(conn, client_id, 'generic_system_uptime_seconds')
            if uptime:
                days = int(uptime / 86400)
                hours = int((uptime % 86400) / 3600)
                uptime_str = f"{days}d {hours}h"
            else:
                uptime_str = "N/A"
            st.markdown(f"""
<div class="terminal-box">
UPTIME<br/>
║ {uptime_str} ║
</div>
""", unsafe_allow_html=True)
    
    with tab2:
        # CPU metrics and graph
        st.subheader("CPU Metrics")
        
        col1, col2, col3 = st.columns(3)
        with col1:
            cpu_usage = get_client_metrics(conn, client_id, 'generic_cpu_usage')
            st.metric("Current Usage", f"{cpu_usage:.1f}%")
        with col2:
            cpu_cores = get_client_metrics(conn, client_id, 'generic_cpu_cores')
            st.metric("CPU Cores", int(cpu_cores) if cpu_cores else "N/A")
        with col3:
            cpu_load = get_client_metrics(conn, client_id, 'generic_cpu_load')
            st.metric("Load Average", f"{cpu_load:.2f}")
        
        # CPU history graph with Streamlit chart
        st.markdown("""
<div style="color: #00ff00; border: 1px solid #00ff00; padding: 10px; margin: 10px 0;">
<h4 style="text-align: center;">CPU HISTORY (1 HOUR)</h4>
</div>
""", unsafe_allow_html=True)
        
        try:
            cpu_query = f"""
            SELECT timestamp, metric_value as cpu_usage
            FROM metrics_{client_id}
            WHERE metric_name = 'generic_cpu_usage' 
            AND metric_value IS NOT NULL
            AND timestamp > datetime('now', '-1 hour')
            ORDER BY timestamp ASC
            """
            cpu_df = pd.read_sql_query(cpu_query, conn)
            
            if not cpu_df.empty:
                cpu_df['timestamp'] = pd.to_datetime(cpu_df['timestamp'])
                cpu_df.columns = ['timestamp', 'CPU Usage %']
                cpu_df = cpu_df.set_index('timestamp')
                
                # Create Streamlit line chart
                st.line_chart(
                    cpu_df,
                    use_container_width=True,
                    height=300,
                    color='#00ff00'
                )
                
                # Show statistics
                avg_val = cpu_df['CPU Usage %'].mean()
                max_val = cpu_df['CPU Usage %'].max()
                min_val = cpu_df['CPU Usage %'].min()
                st.markdown(f"""
<div style="text-align: center; color: #00ff00; font-size: 14px;">
Min: {min_val:.1f}% | Avg: {avg_val:.1f}% | Max: {max_val:.1f}%
</div>
""", unsafe_allow_html=True)
            else:
                st.info("No CPU history available")
        except Exception as e:
            st.info(f"No CPU history available")
    
    with tab3:
        # Memory metrics
        st.subheader("Memory Metrics")
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            mem_total = get_client_metrics(conn, client_id, 'generic_memory_total_kb')
            if mem_total:
                st.metric("Total", f"{mem_total/1024/1024:.1f} GB")
        
        with col2:
            mem_available = get_client_metrics(conn, client_id, 'generic_memory_available_kb')
            if mem_available:
                st.metric("Available", f"{mem_available/1024/1024:.1f} GB")
        
        with col3:
            mem_percent = get_client_metrics(conn, client_id, 'generic_memory_percent')
            st.metric("Used", f"{mem_percent:.1f}%")
        
        with col4:
            swap_total = get_client_metrics(conn, client_id, 'generic_memory_swap_total_kb')
            if swap_total:
                st.metric("Swap", f"{swap_total/1024/1024:.1f} GB")
    
    with tab4:
        # Disk metrics
        st.subheader("Disk Metrics")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            disk_usage = get_client_metrics(conn, client_id, 'generic_disk_root_usage_percent')
            disk_bar = create_progress_bar(disk_usage, 100, 15, 'blocks')
            st.markdown(f"""
<div class="terminal-box">
ROOT USAGE<br/>
{disk_bar}<br/>
{disk_usage:.1f}%
</div>
""", unsafe_allow_html=True)
        
        with col2:
            disk_total = get_client_metrics(conn, client_id, 'generic_disk_root_total')
            st.markdown(f"""
<div class="terminal-box">
TOTAL SIZE<br/>
║ {disk_total if disk_total else 'N/A'} ║
</div>
""", unsafe_allow_html=True)
        
        with col3:
            disk_count = get_client_metrics(conn, client_id, 'generic_disk_count')
            st.markdown(f"""
<div class="terminal-box">
DISK COUNT<br/>
║ {int(disk_count) if disk_count else 'N/A'} ║
</div>
""", unsafe_allow_html=True)
    
    with tab5:
        # Network metrics
        st.subheader("Network Metrics")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            internet = get_client_metrics(conn, client_id, 'generic_network_internet')
            st.metric("Internet", "✅ Yes" if internet == "yes" else "❌ No")
        
        with col2:
            latency = get_client_metrics(conn, client_id, 'generic_network_latency_ms')
            st.metric("Latency", f"{latency:.1f} ms" if latency else "N/A")
        
        with col3:
            interfaces = get_client_metrics(conn, client_id, 'generic_network_interfaces')
            st.metric("Interfaces", int(interfaces) if interfaces else "N/A")
    
    # Raw metrics table with terminal style
    with st.expander("[📊 RAW METRICS - LAST 50 ENTRIES]"):
        try:
            query = f"""
            SELECT timestamp, metric_name, metric_value, metric_text, type
            FROM metrics_{client_id}
            ORDER BY timestamp DESC
            LIMIT 50
            """
            df = pd.read_sql_query(query, conn)
            st.dataframe(df, use_container_width=True)
        except:
            st.info("No data available")
    
    conn.close()

# Main app logic
def main():
    # Initialize session state
    if 'selected_client' not in st.session_state:
        st.session_state.selected_client = None
        st.session_state.selected_hostname = None
    
    # Add terminal cursor and command prompt at top
    st.markdown("""
<div style="color: #00ff00; font-family: 'Fira Code', monospace; padding: 10px; 
            background: #000000; border: 1px solid #00ff00; margin-bottom: 20px;">
lumenmon@terminal:~$ systemctl status monitoring.service<br/>
<span style="color: #00ff00;">● monitoring.service - LUMENMON System Monitor</span><br/>
   Loaded: <span style="color: #00ff00;">loaded</span> (/etc/systemd/system/monitoring.service; enabled)<br/>
   Active: <span style="color: #00ff00;">active (running)</span> since boot<br/>
   Status: "Monitoring all systems..."<span class="cursor"></span>
</div>
""", unsafe_allow_html=True)
    
    # Show appropriate view
    if st.session_state.selected_client:
        show_client_detail(st.session_state.selected_client, st.session_state.selected_hostname)
    else:
        show_client_overview()
    
    # Footer with terminal prompt
    st.markdown("""
<div style="color: #00ff00; font-family: 'Fira Code', monospace; padding: 10px; 
            margin-top: 50px; background: #000000; border-top: 1px solid #00ff00;">
lumenmon@terminal:~$ <span class="cursor">_</span>
</div>
""", unsafe_allow_html=True)
    
    # Auto-refresh every 5 seconds using JavaScript
    st.markdown(
        """
        <script>
            setTimeout(function(){
                window.location.reload();
            }, 5000);
        </script>
        """,
        unsafe_allow_html=True
    )

if __name__ == "__main__":
    main()