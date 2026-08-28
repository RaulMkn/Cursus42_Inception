FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    curl -L https://github.com/google/cadvisor/releases/download/v0.47.2/cadvisor-v0.47.2-linux-${ARCH} \
    -o /usr/local/bin/cadvisor \
    && chmod +x /usr/local/bin/cadvisor

COPY ./tools/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8181

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
