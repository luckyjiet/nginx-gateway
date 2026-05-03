#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

if find "$ROOT_DIR/nginx" "$ROOT_DIR/environments" -name '*.tpl' | grep -q .; then
  echo "source nginx files should use .conf, not .tpl" >&2
  exit 1
fi

if [ -d "$ROOT_DIR/nginx/routes/common" ]; then
  echo "business routes should live under environments/<env>/routes, not nginx/routes/common" >&2
  exit 1
fi

if find "$ROOT_DIR/environments" -path '*/routes/*' -type f -name '[0-9]*.conf' | grep -q .; then
  echo "route files should use service names like api.conf, not numeric prefixes" >&2
  exit 1
fi

if grep -R -E 'SERVER_(HOST|PORT|USER|SSH_KEY)' "$ROOT_DIR/.github" "$ROOT_DIR/README.md" >/dev/null 2>&1; then
  echo "deploy workflows should use DEPLOY_* and SSH_PRIVATE_KEY only, not legacy SERVER_* names" >&2
  exit 1
fi

for file in \
  "$ROOT_DIR/environments/test/routes/http-only/opencoin.conf" \
  "$ROOT_DIR/environments/test/routes/https/opencoin.conf" \
  "$ROOT_DIR/environments/prod/routes/http-only/opencoin.conf" \
  "$ROOT_DIR/environments/prod/routes/https/opencoin.conf"
do
  if [ ! -f "$file" ]; then
    echo "missing expected route file: $file" >&2
    exit 1
  fi
done
