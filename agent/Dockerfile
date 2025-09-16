FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache \
    bash \
    openssh-client \
    procps \
    coreutils \
    iproute2 \
    iputils \
    bc \
    util-linux

# Create metrics user
RUN adduser -D -s /bin/bash metrics

# Set up SSH directory
USER metrics
WORKDIR /home/metrics
RUN mkdir -p .ssh && chmod 700 .ssh

# Copy coordinator and collector scripts
COPY --chown=metrics:metrics coordinator.sh /usr/local/bin/
COPY --chown=metrics:metrics collectors/*.sh /usr/local/bin/collectors/
RUN chmod +x /usr/local/bin/coordinator.sh && \
    chmod +x /usr/local/bin/collectors/*.sh

# Default environment
ENV CONSOLE_HOST=console \
    CONSOLE_PORT=22 \
    CONSOLE_USER=collector

CMD ["/usr/local/bin/coordinator.sh"]