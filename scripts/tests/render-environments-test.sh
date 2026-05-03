#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
DEFAULT_CONF="$ROOT_DIR/nginx/default.conf"
BACKUP_CONF=$(mktemp)
CERT_DIR="$ROOT_DIR/certbot/conf/live/uniamm.com"
CREATED_CERT_DIR=0
CREATED_FULLCHAIN=0
CREATED_PRIVKEY=0

cleanup() {
  if [ -f "$BACKUP_CONF" ]; then
    cp "$BACKUP_CONF" "$DEFAULT_CONF"
    rm -f "$BACKUP_CONF"
  fi
  if [ "$CREATED_FULLCHAIN" -eq 1 ]; then
    rm -f "$CERT_DIR/fullchain.pem"
  fi
  if [ "$CREATED_PRIVKEY" -eq 1 ]; then
    rm -f "$CERT_DIR/privkey.pem"
  fi
  if [ "$CREATED_CERT_DIR" -eq 1 ]; then
    rmdir "$CERT_DIR" 2>/dev/null || true
    rmdir "$ROOT_DIR/certbot/conf/live" 2>/dev/null || true
  fi
}

assert_contains() {
  file=$1
  expected=$2
  if ! grep -Fq "$expected" "$file"; then
    echo "expected $file to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  file=$1
  unexpected=$2
  if grep -Fq "$unexpected" "$file"; then
    echo "expected $file to not contain: $unexpected" >&2
    exit 1
  fi
}

cp "$DEFAULT_CONF" "$BACKUP_CONF"
trap cleanup EXIT

if [ ! -d "$CERT_DIR" ]; then
  mkdir -p "$CERT_DIR"
  CREATED_CERT_DIR=1
fi
if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
  : > "$CERT_DIR/fullchain.pem"
  CREATED_FULLCHAIN=1
fi
if [ ! -f "$CERT_DIR/privkey.pem" ]; then
  : > "$CERT_DIR/privkey.pem"
  CREATED_PRIVKEY=1
fi

APP_ENV=test "$ROOT_DIR/scripts/render-nginx-conf.sh"
assert_contains "$DEFAULT_CONF" "server_name uniamm.com;"
assert_contains "$DEFAULT_CONF" "listen 443 ssl http2;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/uniamm.com/fullchain.pem;"
assert_contains "$DEFAULT_CONF" "root /var/www/opencoin/test;"
assert_contains "$DEFAULT_CONF" 'try_files $uri $uri/ /index.html;'
assert_not_contains "$DEFAULT_CONF" "api.md-zgxt.com"
assert_not_contains "$DEFAULT_CONF" "debug-test.md-zgxt.com"

APP_ENV=prod "$ROOT_DIR/scripts/render-nginx-conf.sh"
assert_contains "$DEFAULT_CONF" "server_name uniamm.com;"
assert_contains "$DEFAULT_CONF" "listen 443 ssl http2;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/uniamm.com/fullchain.pem;"
assert_contains "$DEFAULT_CONF" "root /var/www/opencoin/prod;"
assert_contains "$DEFAULT_CONF" 'try_files $uri $uri/ /index.html;'
assert_not_contains "$DEFAULT_CONF" "api.md-zgxt.com"
assert_not_contains "$DEFAULT_CONF" "debug-test.md-zgxt.com"
