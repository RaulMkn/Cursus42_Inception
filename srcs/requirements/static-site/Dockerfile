FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends nginx && rm -rf /var/lib/apt/lists/*

COPY ./site /var/www/html/static

COPY ./tools/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
