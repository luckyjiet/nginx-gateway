#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

assert_contains() {
  text=$1
  expected=$2
  if ! printf '%s\n' "$text" | grep -Fq "$expected"; then
    echo "expected compose config to contain: $expected" >&2
    exit 1
  fi
}

assert_not_contains() {
  text=$1
  unexpected=$2
  if printf '%s\n' "$text" | grep -Fq "$unexpected"; then
    echo "expected compose config to not contain: $unexpected" >&2
    exit 1
  fi
}

test_config=$(APP_ENV=test "$ROOT_DIR/scripts/compose.sh" config)
assert_contains "$test_config" "name: gateway_test"
assert_contains "$test_config" "source: /var/www/opencoin"
assert_contains "$test_config" "target: /var/www/opencoin"
assert_not_contains "$test_config" "source: /var/www/opencoin/test"

prod_config=$(APP_ENV=prod "$ROOT_DIR/scripts/compose.sh" config)
assert_contains "$prod_config" "name: gateway_prod"
assert_contains "$prod_config" "source: /var/www/opencoin"
assert_contains "$prod_config" "target: /var/www/opencoin"
assert_not_contains "$prod_config" "source: /var/www/opencoin/prod"
