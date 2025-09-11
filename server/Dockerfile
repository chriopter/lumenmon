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

# Create startup script that runs both services independently
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
    echo '# Start dashboard service' >> /start.sh && \
    echo 'streamlit run /app/dashboard/dashboard.py --server.port=8501 --server.address=0.0.0.0' >> /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 8080 8501

# Disable Streamlit telemetry
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ENV STREAMLIT_SERVER_HEADLESS=true

# Run both services
CMD ["/start.sh"]