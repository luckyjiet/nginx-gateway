#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

TEMPLATE="$ROOT_DIR/nginx/templates/http-only.conf"

if all_group_certs_ready; then
  TEMPLATE="$ROOT_DIR/nginx/templates/https.conf"
else
  MISSING_GROUPS=$(print_missing_group_certs | tr '\n' ' ')
  echo "[nginx-gateway] missing cert groups, fallback to HTTP: $MISSING_GROUPS"
fi

cp "$TEMPLATE" "$ROOT_DIR/nginx/default.conf"
echo "[nginx-gateway] active template: $TEMPLATE"
