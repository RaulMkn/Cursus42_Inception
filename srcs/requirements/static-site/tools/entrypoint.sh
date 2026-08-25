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
}
EOF

exec nginx -g "daemon off;"
