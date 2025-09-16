FROM python:3.13-slim

# Install SSH server and dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Create collector user for SSH
RUN useradd -m -s /bin/bash collector && \
    mkdir -p /home/collector/.ssh && \
    chmod 700 /home/collector/.ssh && \
    mkdir -p /var/lib/lumenmon/hot/latest /var/lib/lumenmon/hot/ring && \
    chmod -R 777 /var/lib/lumenmon

# Set up SSH
RUN mkdir -p /var/run/sshd && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Install Python packages for TUI
RUN pip install --no-cache-dir rich textual pandas

# Copy console scripts
COPY lumenmon-append /usr/local/bin/
COPY tui.py /usr/local/bin/
COPY tui_enhanced.py /usr/local/bin/
COPY boot_animation.py /usr/local/bin/
COPY start.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/lumenmon-append \
    /usr/local/bin/tui.py \
    /usr/local/bin/tui_enhanced.py \
    /usr/local/bin/boot_animation.py \
    /usr/local/bin/start.sh && \
    chmod 755 /usr/local/bin/lumenmon-append

# Mount point for tmpfs
VOLUME /var/lib/lumenmon/hot

EXPOSE 22

CMD ["/usr/local/bin/start.sh"]