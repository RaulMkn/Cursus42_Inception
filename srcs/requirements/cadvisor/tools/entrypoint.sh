#!/bin/bash

exec /usr/local/bin/cadvisor \
    -port=8181 \
    -docker_only=true \
    -store_container_labels=false
