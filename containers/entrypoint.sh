#!/usr/bin/env bash
set -euo pipefail
cd /app/server

# Ensure dirs exist
mkdir -p "${LSB_LOG_DIR:-/logs}" /app/server/settings
chmod 0777 "${LSB_LOG_DIR:-/logs}" || true

# Always start from a clean, valid network.lua template (outside mounted path)
cp /app/server/settings.default/network.lua /app/server/settings/network.lua
nlua=/app/server/settings/network.lua
sed -i "s|^\(\s*SQL_HOST\s*=\s*\).*|\1\"${LSB_DB_HOST}\",|; \
        s|^\(\s*SQL_PORT\s*=\s*\).*|\1${LSB_DB_PORT},|; \
        s|^\(\s*SQL_LOGIN\s*=\s*\).*|\1\"${LSB_DB_USER}\",|; \
        s|^\(\s*SQL_PASSWORD\s*=\s*\).*|\1\"${LSB_DB_PASS}\",|; \
        s|^\(\s*SQL_DATABASE\s*=\s*\).*|\1\"${LSB_DB_NAME}\",|; \
        s|^\(\s*ZMQ_IP\s*=\s*\).*|\1\"${LSB_ZMQ_IP:-0.0.0.0}\",|; \
        s|^\(\s*MAP_PORT\s*=\s*\).*|\1${LSB_MAP_PORT:-54232},|; \
        s|^\(\s*LOGIN_DATA_IP\s*=\s*\).*|\1\"${LSB_LOGIN_DATA_IP:-0.0.0.0}\",|; \
        s|^\(\s*LOGIN_VIEW_IP\s*=\s*\).*|\1\"${LSB_LOGIN_VIEW_IP:-0.0.0.0}\",|; \
        s|^\(\s*LOGIN_AUTH_IP\s*=\s*\).*|\1\"${LSB_LOGIN_AUTH_IP:-0.0.0.0}\",|; \
        s|^\(\s*LOGIN_CONF_IP\s*=\s*\).*|\1\"${LSB_LOGIN_CONF_IP:-0.0.0.0}\",|; \
        s|^\(\s*TCP_ALLOW\s*=\s*\).*|\1\"${LSB_TCP_ALLOW:-all}\",|" "$nlua"

# ----- Wait for DB and (optionally) make sure user exists -----
echo "Waiting for MariaDB at ${LSB_DB_HOST}:${LSB_DB_PORT}..."
until mysql --connect-timeout=2 -h"${LSB_DB_HOST}" -P"${LSB_DB_PORT}" \
      -u"${LSB_DB_USER}" -p"${LSB_DB_PASS}" -e "SELECT 1" "${LSB_DB_NAME}" >/dev/null 2>&1; do
  sleep 2
done

# Auto DB update (uses tools/dbtool.py). Requires repo .git metadata in the image.
if [ "${LSB_DB_AUTOUPDATE:-0}" = "1" ]; then
  echo "Running dbtool ${LSB_DB_UPDATE_MODE:-update}..."
  (cd /app/server/tools && \
      python3 dbtool.py "${LSB_DB_UPDATE_MODE:-update}" || \
      python3 dbtool.py update full || true)
fi

# Optional: set zone IP
if [ -n "${LSB_ZONE_IP:-}" ]; then
  echo "Setting zoneip=${LSB_ZONE_IP}"
  mysql -h "${LSB_DB_HOST}" -P "${LSB_DB_PORT}" -u"${LSB_DB_USER}" -p"${LSB_DB_PASS}" "${LSB_DB_NAME}" \
    -e "UPDATE zone_settings SET zoneip='${LSB_ZONE_IP}'" || true
fi

# Launch all 4 daemons
set -m
./xi_connect --log "${LSB_LOG_DIR:-/logs}/connect.log" &
./xi_map     --log "${LSB_LOG_DIR:-/logs}/map.log" &
./xi_search  --log "${LSB_LOG_DIR:-/logs}/search.log" &
./xi_world   --log "${LSB_LOG_DIR:-/logs}/world.log" &
wait
