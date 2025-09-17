FROM python:3.13-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for TUI
RUN pip install --no-cache-dir rich

# Create collector user for SSH
RUN useradd -m -s /bin/bash collector && \
    mkdir -p /home/collector/.ssh && \
    chmod 700 /home/collector/.ssh

# Setup SSH config - INSECURE FOR TESTING
RUN mkdir -p /var/run/sshd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config && \
    echo "StrictModes no" >> /etc/ssh/sshd_config && \
    passwd -d collector

# Setup directory structure
RUN mkdir -p /var/lib/lumenmon/hot/{latest,ring} && \
    chmod -R 777 /var/lib/lumenmon

# Copy ultra-KISS console files
WORKDIR /app
COPY console.sh .
COPY ssh/ ./ssh/
COPY tui/ ./tui/

# Make scripts executable
RUN chmod +x console.sh ssh/*.sh tui/*.py

# Mount point for tmpfs
VOLUME /var/lib/lumenmon/hot

EXPOSE 22

CMD ["./console.sh"]