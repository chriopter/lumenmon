FROM rastasheep/ubuntu-sshd:20.04

COPY server/start.sh /usr/local/bin/start.sh
COPY keys/id_demo.pub /opt/keys/id_demo.pub

RUN chmod 700 /usr/local/bin/start.sh \
    && chmod 600 /opt/keys/id_demo.pub

EXPOSE 22
CMD ["/usr/local/bin/start.sh"]
