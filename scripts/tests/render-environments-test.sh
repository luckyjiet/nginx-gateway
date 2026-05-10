#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
DEFAULT_CONF="$ROOT_DIR/nginx/default.conf"
BACKUP_CONF=$(mktemp)
CERT_ROOT="$ROOT_DIR/certbot/conf/live"
TEST_CERT_NAMES="uniamm.com wittgens.cloud"
CREATED_CERT_DIRS=""
CREATED_FULLCHAINS=""
CREATED_PRIVKEYS=""

cleanup() {
  if [ -f "$BACKUP_CONF" ]; then
    cp "$BACKUP_CONF" "$DEFAULT_CONF"
    rm -f "$BACKUP_CONF"
  fi
  for file in $CREATED_FULLCHAINS; do
    rm -f "$file"
  done
  for file in $CREATED_PRIVKEYS; do
    rm -f "$file"
  done
  for dir in $CREATED_CERT_DIRS; do
    rmdir "$dir" 2>/dev/null || true
  done
  rmdir "$CERT_ROOT" 2>/dev/null || true
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

for cert_name in $TEST_CERT_NAMES; do
  cert_dir="$CERT_ROOT/$cert_name"
  if [ ! -d "$cert_dir" ]; then
    mkdir -p "$cert_dir"
    CREATED_CERT_DIRS="$cert_dir $CREATED_CERT_DIRS"
  fi
  if [ ! -f "$cert_dir/fullchain.pem" ]; then
    : > "$cert_dir/fullchain.pem"
    CREATED_FULLCHAINS="$cert_dir/fullchain.pem $CREATED_FULLCHAINS"
  fi
  if [ ! -f "$cert_dir/privkey.pem" ]; then
    : > "$cert_dir/privkey.pem"
    CREATED_PRIVKEYS="$cert_dir/privkey.pem $CREATED_PRIVKEYS"
  fi
done

APP_ENV=test "$ROOT_DIR/scripts/render-nginx-conf.sh"
assert_contains "$DEFAULT_CONF" "server_name uniamm.com;"
assert_contains "$DEFAULT_CONF" "server_name wittgens.cloud;"
assert_contains "$DEFAULT_CONF" "server_name api.wittgens.cloud;"
assert_contains "$DEFAULT_CONF" "server_name admin.wittgens.cloud;"
assert_contains "$DEFAULT_CONF" "listen 443 ssl http2;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/uniamm.com/fullchain.pem;"
assert_contains "$DEFAULT_CONF" "ssl_certificate /etc/letsencrypt/live/wittgens.cloud/fullchain.pem;"
assert_contains "$DEFAULT_CONF" "root /var/www/opencoin/test;"
assert_contains "$DEFAULT_CONF" "root /var/www/wittgens/test;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-go-server:8000;"
assert_contains "$DEFAULT_CONF" "proxy_pass http://rwat-admin-ui:80;"
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
