FROM rastasheep/ubuntu-sshd:20.04

COPY client/run.sh /usr/local/bin/run.sh
COPY keys/id_demo /opt/keys/id_demo

RUN chmod 700 /usr/local/bin/run.sh \
    && chmod 600 /opt/keys/id_demo

CMD ["/usr/local/bin/run.sh"]
