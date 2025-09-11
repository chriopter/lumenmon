FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app/sink.py .
COPY app/dashboard.py .

# Create startup script that runs both services
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'echo "Starting Lumenmon Server Components..."' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start sink in background' >> /start.sh && \
    echo 'python3 sink.py &' >> /start.sh && \
    echo 'SINK_PID=$!' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Wait a bit for sink to initialize database' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '' >> /start.sh && \
    echo '# Start Streamlit dashboard' >> /start.sh && \
    echo 'streamlit run dashboard.py --server.port=8501 --server.address=0.0.0.0' >> /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 8080 8501

# Disable Streamlit telemetry
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
ENV STREAMLIT_SERVER_HEADLESS=true

# Run both services
CMD ["/start.sh"]