FROM python:3.13-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       openssh-client \
       bash \
    && rm -rf /var/lib/apt/lists/*

COPY client/run.sh /usr/local/bin/run.sh
COPY keys/id_demo /opt/keys/id_demo

RUN chmod 700 /usr/local/bin/run.sh \
    && chmod 600 /opt/keys/id_demo

CMD ["/usr/local/bin/run.sh"]
