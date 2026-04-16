#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

API_DOMAIN="api.md-zgxt.com"
ADMIN_DOMAIN="admin.md-zgxt.com"
SWAP_DOMAIN="swap.md-zgxt.com"

# 按主域名维度组织证书：一张证书可覆盖多个子域名（SAN）。
# 需要第二套主域名时，在 CERT_GROUP_NAMES 追加，并在
# domains_for_group() 增加对应分支。
CERT_GROUP_NAMES="md-zgxt.com"
: "${LETSENCRYPT_EMAIL:=}"

cert_dir_for_group() {
  cert_name=$1
  printf '%s/certbot/conf/live/%s' "$ROOT_DIR" "$cert_name"
}

domains_for_group() {
  cert_name=$1
  case "$cert_name" in
    md-zgxt.com)
      printf '%s\n' "$API_DOMAIN $ADMIN_DOMAIN $SWAP_DOMAIN"
      ;;
    *)
      return 1
      ;;
  esac
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

export SCRIPT_DIR ROOT_DIR API_DOMAIN ADMIN_DOMAIN SWAP_DOMAIN CERT_GROUP_NAMES
export LETSENCRYPT_EMAIL
