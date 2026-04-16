#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

mkdir -p "$ROOT_DIR/certbot/www" "$ROOT_DIR/certbot/conf"
ensure_edge_network

"$SCRIPT_DIR/render-nginx-conf.sh"
(
  cd "$ROOT_DIR"
  docker compose -f docker-compose.yml up -d nginx
)

for cert_name in $CERT_GROUP_NAMES; do
  [ -n "$cert_name" ] || continue
  cert_domains=$(domains_for_group "$cert_name" || true)
  [ -n "$cert_domains" ] || continue

  set --
  for domain in $cert_domains; do
    set -- "$@" -d "$domain"
  done

  echo "[nginx-gateway] renewing certificate set: $cert_name ($cert_domains)"
  if [ -n "$LETSENCRYPT_EMAIL" ]; then
    docker run --rm \
      -v "$ROOT_DIR/certbot/www:/var/www/certbot" \
      -v "$ROOT_DIR/certbot/conf:/etc/letsencrypt" \
      certbot/certbot certonly \
      --webroot \
      -w /var/www/certbot \
      --non-interactive \
      --cert-name "$cert_name" \
      "$@" \
      --email "$LETSENCRYPT_EMAIL" \
      --agree-tos \
      --no-eff-email \
      --keep-until-expiring
  else
    docker run --rm \
      -v "$ROOT_DIR/certbot/www:/var/www/certbot" \
      -v "$ROOT_DIR/certbot/conf:/etc/letsencrypt" \
      certbot/certbot certonly \
      --webroot \
      -w /var/www/certbot \
      --non-interactive \
      --cert-name "$cert_name" \
      "$@" \
      --register-unsafely-without-email \
      --agree-tos \
      --keep-until-expiring
  fi
done

"$SCRIPT_DIR/render-nginx-conf.sh"
(
  cd "$ROOT_DIR"
  docker compose -f docker-compose.yml restart nginx
)

echo "[nginx-gateway] certificate renew complete"
