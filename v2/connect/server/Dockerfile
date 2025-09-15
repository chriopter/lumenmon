FROM python:3.13-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       openssh-server \
       bash \
       coreutils \
       procps \
       ncurses-base \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd

COPY server/start.sh /usr/local/bin/start.sh
COPY server/handle_client.sh /usr/local/bin/handle_client.sh
COPY server/monitor.sh /usr/local/bin/monitor.sh
COPY keys/id_demo.pub /opt/keys/id_demo.pub

RUN chmod 755 /usr/local/bin/start.sh \
    /usr/local/bin/handle_client.sh \
    /usr/local/bin/monitor.sh \
    && chmod 600 /opt/keys/id_demo.pub

EXPOSE 22
CMD ["/usr/local/bin/start.sh"]
