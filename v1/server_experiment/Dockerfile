FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    sqlite \
    bc \
    ncurses \
    curl \
    git \
    ca-certificates \
    libstdc++ \
    libgcc \
    util-linux \
    util-linux-misc

# Install gum for TUI
RUN cd /tmp && \
    curl -sSL https://github.com/charmbracelet/gum/releases/download/v0.14.5/gum_0.14.5_Linux_x86_64.tar.gz -o gum.tar.gz && \
    tar xzf gum.tar.gz && \
    find . -name "gum" -type f -exec mv {} /usr/local/bin/gum \; && \
    chmod +x /usr/local/bin/gum && \
    rm -rf /tmp/*

# Install ttyd for web terminal
RUN cd /tmp && \
    TTYD_VERSION="1.7.4" && \
    curl -sSL https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64 -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd && \
    rm -rf /tmp/*

# Create app directory
WORKDIR /app

# Copy scripts
COPY scripts/ /app/scripts/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Verify scripts are in place
RUN ls -la /app/scripts/

# Set environment variables
ENV DB_PATH=/app/data/lumenmon.db
ENV REFRESH_RATE=5
ENV AUTO_REFRESH=true
ENV TERM=xterm-256color

# Create entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'echo "Starting Lumenmon..."' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Check if database exists and is readable' >> /entrypoint.sh && \
    echo 'if [ ! -f "$DB_PATH" ]; then' >> /entrypoint.sh && \
    echo '    echo "Error: Database not found at $DB_PATH"' >> /entrypoint.sh && \
    echo '    echo "Waiting for database to be available..."' >> /entrypoint.sh && \
    echo '    while [ ! -f "$DB_PATH" ]; do' >> /entrypoint.sh && \
    echo '        sleep 2' >> /entrypoint.sh && \
    echo '    done' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Check database permissions' >> /entrypoint.sh && \
    echo 'if [ ! -r "$DB_PATH" ]; then' >> /entrypoint.sh && \
    echo '    echo "Error: Database exists but is not readable"' >> /entrypoint.sh && \
    echo '    echo "Current user: $(id)"' >> /entrypoint.sh && \
    echo '    echo "Database permissions: $(ls -la $DB_PATH)"' >> /entrypoint.sh && \
    echo '    echo "Attempting to copy database locally..."' >> /entrypoint.sh && \
    echo '    cp "$DB_PATH" /tmp/lumenmon.db 2>/dev/null && DB_PATH=/tmp/lumenmon.db' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'echo "Using database: $DB_PATH"' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Decide which mode to run' >> /entrypoint.sh && \
    echo 'if [ "$TUI_MODE" = "web" ] || [ "$TUI_MODE" = "ttyd" ]; then' >> /entrypoint.sh && \
    echo '    echo "Starting in web terminal mode..."' >> /entrypoint.sh && \
    echo '    exec /app/scripts/start-ttyd.sh' >> /entrypoint.sh && \
    echo 'elif [ "$TUI_MODE" = "direct" ]; then' >> /entrypoint.sh && \
    echo '    echo "Starting in direct TUI mode..."' >> /entrypoint.sh && \
    echo '    exec /app/scripts/tui.sh' >> /entrypoint.sh && \
    echo 'else' >> /entrypoint.sh && \
    echo '    # Default to web mode' >> /entrypoint.sh && \
    echo '    echo "Starting in web terminal mode (default)..."' >> /entrypoint.sh && \
    echo '    exec /app/scripts/start-ttyd.sh' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Expose ttyd port
EXPOSE 7681

# Run the entrypoint
ENTRYPOINT ["/entrypoint.sh"]