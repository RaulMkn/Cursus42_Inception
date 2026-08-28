FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y mariadb-server && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/lib/mysql/*

RUN mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld

COPY ./conf/mariadb.conf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY ./tools/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]