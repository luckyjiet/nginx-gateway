#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

mkdir -p "$ROOT_DIR/certbot/www" "$ROOT_DIR/certbot/conf"

"$SCRIPT_DIR/render-nginx-conf.sh"
(
  cd "$ROOT_DIR"
  docker compose -f docker-compose.yml up -d nginx
)

if ! all_group_certs_ready; then
  if [ -n "$LETSENCRYPT_EMAIL" ]; then
    "$SCRIPT_DIR/request-cert.sh"
  else
    MISSING_GROUPS=$(print_missing_group_certs | tr '\n' ' ')
    echo "[nginx-gateway] missing cert groups: $MISSING_GROUPS"
    echo "[nginx-gateway] running in HTTP mode"
  fi
fi
