#!/bin/sh
set -e

if [ -f /opt/ops-env/.env ] && [ ! -f /opt/OpenPagingServer/.env ]; then
    cp /opt/ops-env/.env /opt/OpenPagingServer/.env
    echo "Loaded .env from database initialization"
fi

if [ -f /opt/ops-env/.oobe ] && [ ! -f /opt/OpenPagingServer/.oobe ]; then
    cp /opt/ops-env/.oobe /opt/OpenPagingServer/.oobe
fi

if [ -f /opt/OpenPagingServer/.env ]; then
    . /opt/OpenPagingServer/.env
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-3306}"
    echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
    attempts=0
    max_attempts=60
    while [ $attempts -lt $max_attempts ]; do
        if python -c "
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect(('${DB_HOST}', ${DB_PORT}))
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
            echo "Database is ready."
            break
        fi
        attempts=$((attempts + 1))
        sleep 1
    done
    if [ $attempts -ge $max_attempts ]; then
        echo "WARNING: Database not reachable after ${max_attempts}s, starting anyway..."
    fi
fi

exec "$@"
