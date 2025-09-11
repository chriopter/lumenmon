FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Copy and install dashboard dependencies (sink has none)
COPY dashboard/requirements.txt ./dashboard/
RUN pip install --no-cache-dir -r dashboard/requirements.txt

# Copy service folders and configuration
COPY sink/ ./sink/
COPY dashboard/ ./dashboard/
COPY .streamlit/ ./.streamlit/

# Create startup script that runs all services
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Starting Lumenmon Server Components..."' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start sink service in background' >> /start.sh && \
    echo 'python3 /app/sink/sink.py &' >> /start.sh && \
    echo 'SINK_PID=$!' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait for sink to initialize database' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
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
EXPOSE 8080 8501 8090

# Disable Streamlit telemetry
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ENV STREAMLIT_SERVER_HEADLESS=true

# Run both services
CMD ["/start.sh"]