FROM debian:bookworm

RUN apt-get update && apt-get install -y adminer php8.2-cli php8.2-mysql && rm -rf /var/lib/apt/lists/*

COPY ./tools/entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]