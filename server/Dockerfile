FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Install SSH server and client (for ssh-keygen)
RUN apt-get update && apt-get install -y \
    openssh-server \
    openssh-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create metrics user with no shell (for SSH tunneling only)
RUN useradd -m -d /home/metrics -s /bin/false metrics && \
    mkdir -p /home/metrics/.ssh && \
    touch /home/metrics/.ssh/authorized_keys && \
    touch /home/metrics/pending_keys.txt && \
    chown -R metrics:metrics /home/metrics && \
    chmod 700 /home/metrics/.ssh && \
    chmod 600 /home/metrics/.ssh/authorized_keys

# Configure SSH for port forwarding only (no shell access)
RUN mkdir -p /run/sshd && \
    echo "Port 2222" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "AllowUsers metrics" >> /etc/ssh/sshd_config && \
    echo "X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "PermitTunnel no" >> /etc/ssh/sshd_config && \
    echo "ForceCommand /bin/false" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config

# Copy and install dashboard dependencies (sink has none)
COPY dashboard/requirements.txt ./dashboard/
RUN pip install --no-cache-dir -r dashboard/requirements.txt && \
    pip install sqlite-web

# Copy service folders and configuration
COPY sink/ ./sink/
COPY dashboard/ ./dashboard/
COPY .streamlit/ ./.streamlit/

# Create startup script that runs all services
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Starting Lumenmon Server Components..."' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start sink service first to ensure database exists' >> /start.sh && \
    echo 'python3 /app/sink/sink.py &' >> /start.sh && \
    echo 'SINK_PID=$!' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for sink to initialize database' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Sync authorized_keys from database' >> /start.sh && \
    echo 'echo "Syncing SSH authorized_keys from database..."' >> /start.sh && \
    echo 'python3 -c "import sys; sys.path.insert(0, \"/app/sink\"); from sink import sync_authorized_keys; sync_authorized_keys()"' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start SSH server for client tunnels' >> /start.sh && \
    echo 'echo "Starting SSH server on port 2222 for client tunnels..."' >> /start.sh && \
    echo '/usr/sbin/sshd -D &' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start SQLite Web if SQL_DEBUG is enabled' >> /start.sh && \
    echo 'if [ "$SQL_DEBUG" = "1" ]; then' >> /start.sh && \
    echo '    echo "Starting SQLite Web Interface on port 8090..."' >> /start.sh && \
    echo '    sqlite_web /app/data/lumenmon.db --host 0.0.0.0 --port 8090 --read-only &' >> /start.sh && \
    echo '    echo "SQLite Web Interface: http://localhost:8090"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '    echo "SQLite Web Interface disabled (set SQL_DEBUG=1 to enable)"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start dashboard service' >> /start.sh && \
    echo 'streamlit run /app/dashboard/dashboard.py --server.port=8501 --server.address=0.0.0.0' >> /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 8080 8501 8090 2222

# Disable Streamlit telemetry
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ENV STREAMLIT_SERVER_HEADLESS=true

# Run both services
CMD ["/start.sh"]