FROM python:3.14-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    netcat-traditional \
    xclip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for TUI
RUN pip install --no-cache-dir rich textual plotext pyperclip

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
COPY core/ ./core/
COPY tui/ ./tui/

# Make scripts executable
RUN chmod +x console.sh core/*.sh core/*/*.sh tui/*.py

# Mount point for persistent data
VOLUME /data

EXPOSE 22

CMD ["./console.sh"]