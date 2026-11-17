#!/bin/bash

exec /usr/local/bin/cadvisor \
    -port=8181 \
    -url_base_prefix=/cadvisor \
    -docker_only=true \
    -store_container_labels=false
