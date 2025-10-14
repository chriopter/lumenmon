FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    bash \
    bc \
    openssh-server \
    netcat-traditional \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

# Create groups for agent and registration users
RUN groupadd agents && \
    groupadd registration

# Create collector user for SSH
RUN useradd -m -s /bin/bash collector && \
    mkdir -p /home/collector/.ssh && \
    chmod 700 /home/collector/.ssh

# Setup SSH config - Key-based auth only, no strict modes
RUN mkdir -p /var/run/sshd && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
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

# Make scripts executable
RUN chmod +x console.sh tui.sh core/*.sh core/*/*.sh tui/*/*.sh

# Mount point for persistent data
VOLUME /data

EXPOSE 22

CMD ["./console.sh"]