FROM alpine:3.20

# Install minimal dependencies
RUN apk add --no-cache \
    bash \
    openssh-client \
    procps \
    coreutils \
    iproute2

# Create metrics user
RUN adduser -D -s /bin/bash metrics

# Set up SSH directory
USER metrics
WORKDIR /home/metrics
RUN mkdir -p .ssh && chmod 700 .ssh

# Copy ultra-simple agent and collectors
COPY --chown=metrics:metrics agent.sh /app/
COPY --chown=metrics:metrics app/ /app/app/
COPY --chown=metrics:metrics collectors /app/collectors/

# Make everything executable
RUN chmod +x /app/agent.sh /app/app/*.sh /app/collectors/*/*.sh

WORKDIR /app

# Default environment
ENV CONSOLE_HOST=console \
    CONSOLE_PORT=22 \
    CONSOLE_USER=collector

CMD ["./agent.sh"]