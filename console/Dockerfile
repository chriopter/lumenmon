FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    bash \
    bc \
    openssh-server \
    netcat-traditional \
    coreutils \
    openssl \
    curl \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Caddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install -y caddy \
    && rm -rf /var/lib/apt/lists/*

# Create groups for agent and registration users
RUN groupadd agents && \
    groupadd registration

# Create collector user for SSH
RUN useradd -m -s /bin/bash collector && \
    mkdir -p /home/collector/.ssh && \
    chmod 700 /home/collector/.ssh

# Setup SSH config - Uses custom config at /app/core/ingress/ssh_config
RUN mkdir -p /var/run/sshd && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "StrictModes no" >> /etc/ssh/sshd_config

# Setup directory structure
RUN mkdir -p /data/agents && \
    chmod -R 755 /data

# Copy ultra-KISS console files
WORKDIR /app
COPY console.sh .
COPY tui.sh .
COPY core/ ./core/
COPY tui/ ./tui/
COPY web/ ./web/

# Copy Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# Make scripts executable
RUN chmod +x console.sh tui.sh core/*.sh core/*/*.sh tui/*/*.sh

# Mount point for persistent data
VOLUME /data

EXPOSE 22 80 443

CMD ["./console.sh"]