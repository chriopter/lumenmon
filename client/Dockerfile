FROM alpine:latest

# Install required tools
# - curl: For sending metrics to server
# - procps: For 'top' and 'ps' commands (CPU/process monitoring)
# - lsblk: For disk/block device information
# - iputils: For 'ping' command (network connectivity checks)
# - iproute2: For 'ip' command (network interface info)
# - socat: For creating TCP listeners (webhook/SMTP forwarders)
# - busybox-extras: Additional networking tools (nc, telnet, etc.)
# - bash: For bash-specific scripts (arrays, regex matching)
RUN apk add --no-cache \
    curl \
    procps \
    lsblk \
    iputils \
    iproute2 \
    socat \
    busybox-extras \
    bash

# Copy collectors and forwarders
COPY collectors /collectors
COPY forwarders /forwarders
RUN chmod +x /collectors/*.sh /collectors/*/*.sh /forwarders/*.sh

# Create startup script
RUN echo '#!/bin/sh' > /start.sh && \
    echo '# Start forwarders in background' >> /start.sh && \
    echo '/forwarders/webhook.sh &' >> /start.sh && \
    echo '/forwarders/smtp.sh &' >> /start.sh && \
    echo '# Start collector loop' >> /start.sh && \
    echo 'cd /collectors' >> /start.sh && \
    echo 'while true; do ./collect.sh; sleep ${INTERVAL:-5}; done' >> /start.sh && \
    chmod +x /start.sh

# Set working directory
WORKDIR /

# Run everything
CMD ["/start.sh"]