#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

APP_ENV="${APP_ENV:-test}"
ENV_DIR="${ENV_DIR:-$ROOT_DIR/environments/$APP_ENV}"
ENV_FILE="$ENV_DIR/gateway.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "[nginx-gateway] missing environment file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

: "${APP_ENV:=test}"
: "${GATEWAY_CONTAINER_NAME:=gateway-nginx}"
: "${EDGE_NETWORK_NAME:=gateway_test}"
: "${OPENCOIN_WEB_ROOT:=/var/www/opencoin}"
: "${OPENCOIN_WEB_ENV:=$APP_ENV}"
: "${CERT_GROUP_KEYS:=OPENCOIN_CERT}"
: "${LETSENCRYPT_EMAIL:=}"

cert_name_for_key() {
  cert_key=$1
  eval "printf '%s' \"\${${cert_key}_NAME:-}\""
}

cert_domains_for_key() {
  cert_key=$1
  eval "printf '%s' \"\${${cert_key}_DOMAINS:-}\""
}

build_cert_group_names() {
  for cert_key in $CERT_GROUP_KEYS; do
    cert_name=$(cert_name_for_key "$cert_key")
    [ -n "$cert_name" ] || continue
    printf '%s\n' "$cert_name"
  done
}

CERT_GROUP_NAMES=$(build_cert_group_names | tr '\n' ' ')

cert_dir_for_group() {
  cert_name=$1
  printf '%s/certbot/conf/live/%s' "$ROOT_DIR" "$cert_name"
}

domains_for_group() {
  cert_name=$1
  for cert_key in $CERT_GROUP_KEYS; do
    candidate_name=$(cert_name_for_key "$cert_key")
    [ "$candidate_name" = "$cert_name" ] || continue
    cert_domains=$(cert_domains_for_key "$cert_key")
    [ -n "$cert_domains" ] || return 1
    printf '%s\n' "$cert_domains"
    return 0
  done
  return 1
}

group_cert_ready() {
  cert_name=$1
  cert_dir=$(cert_dir_for_group "$cert_name")
  [ -f "$cert_dir/fullchain.pem" ] && [ -f "$cert_dir/privkey.pem" ]
}

all_group_certs_ready() {
  for cert_name in $CERT_GROUP_NAMES; do
    [ -n "$cert_name" ] || continue
    cert_domains=$(domains_for_group "$cert_name" || true)
    [ -n "$cert_domains" ] || return 1
    if ! group_cert_ready "$cert_name"; then
      return 1
    fi
  done
  return 0
}

print_missing_group_certs() {
  for cert_name in $CERT_GROUP_NAMES; do
    [ -n "$cert_name" ] || continue
    cert_domains=$(domains_for_group "$cert_name" || true)
    [ -n "$cert_domains" ] || continue
    if ! group_cert_ready "$cert_name"; then
      printf '%s\n' "$cert_name"
    fi
  done
}

ensure_edge_network() {
  if docker network inspect "$EDGE_NETWORK_NAME" >/dev/null 2>&1; then
    return 0
  fi
  echo "[nginx-gateway] creating docker network: $EDGE_NETWORK_NAME"
  docker network create "$EDGE_NETWORK_NAME" >/dev/null
}

ensure_runtime_dirs() {
  mkdir -p "$ROOT_DIR/certbot/www" "$ROOT_DIR/certbot/conf" "$OPENCOIN_WEB_ROOT"
}

docker_compose() {
  compose_file="$ROOT_DIR/docker-compose.yml"
  if [ -f "$ENV_DIR/docker-compose.yml" ]; then
    docker compose --project-directory "$ROOT_DIR" -f "$compose_file" -f "$ENV_DIR/docker-compose.yml" "$@"
    return 0
  fi
  docker compose --project-directory "$ROOT_DIR" -f "$compose_file" "$@"
}

export SCRIPT_DIR ROOT_DIR APP_ENV ENV_DIR ENV_FILE
export GATEWAY_CONTAINER_NAME EDGE_NETWORK_NAME OPENCOIN_WEB_ROOT OPENCOIN_WEB_ENV
export OPENCOIN_DOMAIN OPENCOIN_CERT_NAME CERT_GROUP_KEYS CERT_GROUP_NAMES
export LETSENCRYPT_EMAIL
