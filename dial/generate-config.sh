#!/usr/bin/env sh
# Substitute REMOTE_DIAL_URL / REMOTE_DIAL_API_KEY from .env into core/config.json.
set -eu

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Missing .env - copy .env.example to .env and set REMOTE_DIAL_URL / REMOTE_DIAL_API_KEY" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
. ./.env
set +a

if [ -z "${REMOTE_DIAL_URL:-}" ] || [ -z "${REMOTE_DIAL_API_KEY:-}" ]; then
  echo "REMOTE_DIAL_URL and REMOTE_DIAL_API_KEY must be set in .env" >&2
  exit 1
fi

# Trim trailing slash from remote URL
REMOTE_DIAL_URL="${REMOTE_DIAL_URL%/}"

if command -v envsubst >/dev/null 2>&1; then
  export REMOTE_DIAL_URL REMOTE_DIAL_API_KEY
  envsubst '${REMOTE_DIAL_URL} ${REMOTE_DIAL_API_KEY}' < ./core/config.json.example > ./core/config.json
else
  # Portable fallback without gettext
  sed -e "s|\${REMOTE_DIAL_URL}|${REMOTE_DIAL_URL}|g" \
      -e "s|\${REMOTE_DIAL_API_KEY}|${REMOTE_DIAL_API_KEY}|g" \
      ./core/config.json.example > ./core/config.json
fi

echo "Wrote ./core/config.json"
