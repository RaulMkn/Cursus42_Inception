#!/bin/bash

ADMINER_PATH="/var/www/html"

mkdir -p "$ADMINER_PATH"

if [ ! -f "$ADMINER_PATH/index.php" ]; then
    cat > "$ADMINER_PATH/index.php" <<'EOF'
<?php
$_GET['server'] = getenv('ADMINER_DEFAULT_SERVER') ?: 'db';
include '/usr/share/adminer/adminer.php';
EOF
fi

exec php -S 0.0.0.0:8080 -t "$ADMINER_PATH"