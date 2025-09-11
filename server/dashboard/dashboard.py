#!/usr/bin/env python3
"""LUMENMON - Multi-Client Dashboard"""
import streamlit as st
import pandas as pd
import sqlite3
from datetime import datetime, timedelta

# Page config
st.set_page_config(page_title="LUMENMON", layout="wide", initial_sidebar_state="collapsed")

# Database connection
DB_PATH = '/app/data/lumenmon.db'

# Custom CSS for cyber theme
st.markdown("""
<style>
    .metric-card {
        background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
        padding: 20px;
        border-radius: 10px;
        margin: 10px 0;
        box-shadow: 0 4px 6px rgba(0,0,0,0.3);
    }
    .client-box {
        background: rgba(0,0,0,0.3);
        border: 1px solid #00ff00;
        border-radius: 5px;
        padding: 15px;
        margin: 10px 0;
        cursor: pointer;
        transition: all 0.3s;
    }
    .client-box:hover {
        background: rgba(0,255,0,0.1);
        transform: scale(1.02);
    }
    .cpu-bar {
        background: linear-gradient(90deg, #00ff00 0%, #ffff00 50%, #ff0000 100%);
        height: 30px;
        border-radius: 5px;
        transition: width 0.5s ease;
    }
    .stProgress > div > div > div > div {
        background: linear-gradient(90deg, #00ff00 0%, #ffff00 50%, #ff0000 100%);
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
    
    # Header
    st.markdown("# 🌐 LUMENMON FLEET MONITOR")
    st.markdown(f"### ⏰ {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    st.markdown("---")
    
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
            with st.expander(f"🔔 NEW Client Registrations ({len(pending_df)})", expanded=True):
                st.warning("New clients are waiting for approval! These are first-time registrations.")
                
                for _, reg in pending_df.iterrows():
                    col1, col2, col3, col4, col5 = st.columns([3, 3, 1, 1, 1])
                    with col1:
                        st.text(f"🖥️ {reg['hostname']}")
                    with col2:
                        st.text(f"🔑 {reg['fingerprint'][:20]}...")
                    with col3:
                        st.text(f"#{reg['attempt_count']}")
                    with col4:
                        if st.button("✅", key=f"approve_new_{reg['fingerprint'][:10]}", help="Approve"):
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
                    
                    with col5:
                        if st.button("❌", key=f"reject_new_{reg['fingerprint'][:10]}", help="Reject"):
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
        st.warning("⚠️ No approved clients found. Clients need to register and be approved.")
        return
    
    # Create grid layout for clients
    st.markdown("## 🖥️ Connected Clients")
    
    # Use columns for grid layout (3 clients per row)
    cols_per_row = 3
    for i in range(0, len(clients_df), cols_per_row):
        cols = st.columns(cols_per_row)
        
        for j, col in enumerate(cols):
            if i + j < len(clients_df):
                client = clients_df.iloc[i + j]
                
                with col:
                    # Create clickable client card
                    if st.button(f"📊 {client['hostname']}", key=f"client_{client['id']}", use_container_width=True):
                        st.session_state.selected_client = client['id']
                        st.session_state.selected_hostname = client['hostname']
                        st.rerun()
                    
                    # Check if online
                    is_online = get_client_status(conn, client['id'])
                    status_icon = "🟢" if is_online else "🔴"
                    
                    # Get CPU usage
                    cpu_usage = get_client_metrics(conn, client['id'], 'generic_cpu_usage')
                    
                    # Display metrics
                    st.markdown(f"**Status:** {status_icon} {'Online' if is_online else 'Offline'}")
                    
                    # CPU Usage bar
                    st.markdown("**CPU Usage:**")
                    cpu_pct = min(cpu_usage / 100, 1.0)  # Cap at 100%
                    st.progress(cpu_pct)
                    st.caption(f"{cpu_usage:.1f}%")
                    
                    # Get additional quick stats
                    memory_pct = get_client_metrics(conn, client['id'], 'generic_memory_percent')
                    load = get_client_metrics(conn, client['id'], 'generic_cpu_load')
                    
                    # Quick stats
                    col1, col2 = st.columns(2)
                    with col1:
                        st.metric("Memory", f"{memory_pct:.1f}%")
                    with col2:
                        st.metric("Load", f"{load:.2f}")
                    
                    # Last seen
                    if client['last_seen']:
                        last_seen = datetime.fromisoformat(client['last_seen'])
                        time_ago = datetime.now() - last_seen
                        if time_ago.total_seconds() < 60:
                            ago_str = f"{int(time_ago.total_seconds())}s ago"
                        elif time_ago.total_seconds() < 3600:
                            ago_str = f"{int(time_ago.total_seconds()/60)}m ago"
                        else:
                            ago_str = f"{int(time_ago.total_seconds()/3600)}h ago"
                        st.caption(f"Last seen: {ago_str}")
    
    # Summary statistics
    st.markdown("---")
    st.markdown("## 📈 Fleet Statistics")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_clients = len(clients_df)
        online_count = sum(1 for _, client in clients_df.iterrows() if get_client_status(conn, client['id']))
        st.metric("Total Clients", total_clients)
    
    with col2:
        st.metric("Online", online_count, delta=f"{online_count}/{total_clients}")
    
    with col3:
        # Average CPU across fleet
        avg_cpu = sum(get_client_metrics(conn, client['id'], 'generic_cpu_usage') 
                     for _, client in clients_df.iterrows()) / len(clients_df) if len(clients_df) > 0 else 0
        st.metric("Avg CPU", f"{avg_cpu:.1f}%")
    
    with col4:
        # Average Memory across fleet
        avg_mem = sum(get_client_metrics(conn, client['id'], 'generic_memory_percent') 
                     for _, client in clients_df.iterrows()) / len(clients_df) if len(clients_df) > 0 else 0
        st.metric("Avg Memory", f"{avg_mem:.1f}%")
    
    # Client Management Section
    st.markdown("---")
    with st.expander("🔧 Client Management"):
        # Get all clients
        all_clients_query = """
        SELECT id, hostname, fingerprint, status, created_at, last_seen
        FROM clients 
        ORDER BY created_at DESC
        """
        all_clients_df = pd.read_sql_query(all_clients_query, conn)
        
        if not all_clients_df.empty:
            for _, client in all_clients_df.iterrows():
                col1, col2, col3, col4, col5 = st.columns([2, 3, 2, 2, 2])
                with col1:
                    st.text(f"ID: {client['id']}")
                with col2:
                    st.text(f"🖥️ {client['hostname']}")
                with col3:
                    status_icon = {"approved": "✅", "pending": "⏳", "rejected": "❌"}.get(client['status'], "❓")
                    st.text(f"{status_icon} {client['status']}")
                with col4:
                    st.text(f"🔑 {client['fingerprint'][:15]}...")
                with col5:
                    if client['status'] != 'approved' and st.button("Approve", key=f"mgmt_approve_{client['id']}"):
                        conn.execute("UPDATE clients SET status='approved' WHERE id=?", (client['id'],))
                        conn.commit()
                        st.rerun()
                    elif client['status'] == 'approved' and st.button("Revoke", key=f"mgmt_revoke_{client['id']}"):
                        conn.execute("UPDATE clients SET status='rejected' WHERE id=?", (client['id'],))
                        conn.commit()
                        st.rerun()
    
    conn.close()

def show_client_detail(client_id, hostname):
    """Show detailed view for a specific client"""
    conn = sqlite3.connect(DB_PATH)
    
    # Back button
    if st.button("← Back to Overview"):
        del st.session_state.selected_client
        del st.session_state.selected_hostname
        st.rerun()
    
    # Header
    st.markdown(f"# 🖥️ {hostname}")
    st.markdown(f"### Client ID: {client_id}")
    st.markdown("---")
    
    # Check online status
    is_online = get_client_status(conn, client_id)
    status_icon = "🟢" if is_online else "🔴"
    st.markdown(f"## {status_icon} {'Online' if is_online else 'Offline'}")
    
    # Create tabs for different metric types
    tab1, tab2, tab3, tab4, tab5 = st.tabs(["📊 Overview", "💻 CPU", "🧠 Memory", "💾 Disk", "🌐 Network"])
    
    with tab1:
        # Overview metrics in grid
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            cpu = get_client_metrics(conn, client_id, 'generic_cpu_usage')
            st.metric("CPU Usage", f"{cpu:.1f}%", delta=f"{cpu-50:.1f}" if cpu > 50 else None)
        
        with col2:
            mem = get_client_metrics(conn, client_id, 'generic_memory_percent')
            st.metric("Memory", f"{mem:.1f}%", delta=f"{mem-50:.1f}" if mem > 50 else None)
        
        with col3:
            load = get_client_metrics(conn, client_id, 'generic_cpu_load')
            st.metric("Load Average", f"{load:.2f}")
        
        with col4:
            uptime = get_client_metrics(conn, client_id, 'generic_system_uptime_seconds')
            if uptime:
                days = int(uptime / 86400)
                hours = int((uptime % 86400) / 3600)
                st.metric("Uptime", f"{days}d {hours}h")
            else:
                st.metric("Uptime", "N/A")
    
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
        
        # CPU history graph
        try:
            cpu_query = f"""
            SELECT timestamp, metric_value 
            FROM metrics_{client_id}
            WHERE metric_name = 'generic_cpu_usage' 
            AND metric_value IS NOT NULL
            AND timestamp > datetime('now', '-1 hour')
            ORDER BY timestamp DESC
            """
            cpu_df = pd.read_sql_query(cpu_query, conn)
            
            if not cpu_df.empty:
                cpu_df['timestamp'] = pd.to_datetime(cpu_df['timestamp'])
                cpu_df = cpu_df.sort_values('timestamp')
                st.line_chart(cpu_df.set_index('timestamp')['metric_value'], height=400)
        except:
            st.info("No CPU history available")
    
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
            st.metric("Root Usage", f"{disk_usage:.1f}%")
        
        with col2:
            disk_total = get_client_metrics(conn, client_id, 'generic_disk_root_total')
            st.metric("Total Size", disk_total if disk_total else "N/A")
        
        with col3:
            disk_count = get_client_metrics(conn, client_id, 'generic_disk_count')
            st.metric("Disk Count", int(disk_count) if disk_count else "N/A")
    
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
    
    # Raw metrics table
    with st.expander("📋 Raw Metrics (Last 50)"):
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
    
    # Show appropriate view
    if st.session_state.selected_client:
        show_client_detail(st.session_state.selected_client, st.session_state.selected_hostname)
    else:
        show_client_overview()
    
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