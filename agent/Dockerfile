FROM alpine:3.22

# Install minimal dependencies
RUN apk add --no-cache \
    bash \
    mosquitto-clients \
    procps \
    coreutils \
    iproute2 \
    openssl \
    socat \
    python3 \
    py3-paho-mqtt

# Create metrics user and data directory
RUN adduser -D -s /bin/bash metrics && \
    mkdir -p /data && \
    chown metrics:metrics /data

USER metrics
WORKDIR /home/metrics

# Copy ultra-simple agent and collectors
COPY --chown=metrics:metrics agent.sh /app/
COPY --chown=metrics:metrics core/ /app/core/
COPY --chown=metrics:metrics collectors /app/collectors/

# Make everything executable
RUN chmod +x /app/agent.sh /app/core/*.sh /app/core/*/*.sh /app/core/*/*.py /app/collectors/*/*.sh

WORKDIR /app

# Default environment
ENV CONSOLE_HOST=lumenmon-mqtt-test \
    MQTT_PORT=1883

CMD ["./agent.sh"]