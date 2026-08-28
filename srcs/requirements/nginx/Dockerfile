FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends nginx openssl gettext-base && rm -rf /var/lib/apt/lists/* && \
    rm -f /var/www/html/index.nginx-debian.html

COPY ./conf/nginx.conf /etc/nginx/nginx.conf.template

RUN mkdir -p /etc/nginx/ssl

COPY ./utils/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]