#!/bin/bash

set -euo pipefail

# Read JSON from stdin
INPUT_JSON="$(cat)"

# Extract fields using jq
URL="$(echo "$INPUT_JSON" | jq -r '.url')"
USERNAME="$(echo "$INPUT_JSON" | jq -r '.username')"
PASSWORD="$(echo "$INPUT_JSON" | jq -r '.password')" # pragma: allowlist secret
CA_CERT_B64="$(echo "$INPUT_JSON" | jq -r '.ca_cert_b64')"

# Extract host for .netrc "machine" entry
HOST="$(echo "$URL" | sed -E 's#^https?://([^/:]+).*#\1#')"

RESP="$(
  curl -sS --fail \
    --netrc-file <(printf 'machine %s login %s password %s\n' \
      "$HOST" "$USERNAME" "$PASSWORD") \
    --cacert <(echo "$CA_CERT_B64" | base64 -d) \
    "$URL"
)"


VERSION_NUMBER="$(echo "$RESP" | jq -r '.version.number // empty')"


if [[ -z "$VERSION_NUMBER" ]]; then
  echo '{"version_number":null}'
else

  SAFE_VERSION_NUMBER="${VERSION_NUMBER//\"/\\\"}"
  echo "{\"version_number\":\"$SAFE_VERSION_NUMBER\"}"
fi
