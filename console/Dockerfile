FROM debian:bookworm-slim

# Install all system dependencies in one layer
RUN apt-get update && apt-get install -y \
    bash \
    bc \
    netcat-traditional \
    coreutils \
    openssl \
    curl \
    procps \
    gnupg \
    python3 \
    python3-pip \
    sqlite3 \
    mosquitto \
    ca-certificates \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y caddy docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir flask paho-mqtt --break-system-packages

# Setup directory structure
RUN mkdir -p /data && \
    chmod -R 755 /data

# Copy ultra-KISS console files (includes static CSS/JS from repo)
WORKDIR /app
COPY console.sh .
COPY core/ ./core/
COPY web/ ./web/
COPY config/ ./config/

# Copy Caddyfile from web config
COPY web/config/Caddyfile /etc/caddy/Caddyfile

# Make scripts executable
RUN chmod +x console.sh core/*.sh core/*/*.sh web/app/*.py

# Mount point for persistent data
VOLUME /data

EXPOSE 80 443

CMD ["./console.sh"]