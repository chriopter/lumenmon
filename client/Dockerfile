FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache \
    bash \
    openssh-client \
    procps \
    coreutils

# Create metrics user
RUN adduser -D -s /bin/bash metrics

# Set up SSH directory
USER metrics
WORKDIR /home/metrics
RUN mkdir -p .ssh && chmod 700 .ssh

# Copy collector script
COPY --chown=metrics:metrics collect.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/collect.sh

# Copy SSH key (will be generated and mounted at runtime)
CMD ["/usr/local/bin/collect.sh"]