#!/bin/bash

cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 8443;
    server_name _;
    root /var/www/html/static;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Reverse proxy to cAdvisor API to avoid CORS issues
    # The dashboard JS calls /api/... which gets proxied to cadvisor:8181
    location /api/ {
        proxy_pass http://cadvisor:8181/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

exec nginx -g "daemon off;"
