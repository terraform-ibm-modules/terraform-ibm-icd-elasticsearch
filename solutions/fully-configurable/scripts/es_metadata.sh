#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin
INPUT_JSON="$(cat)"

# Extract fields using jq
URL="$(echo "$INPUT_JSON" | jq -r '.url')"
USERNAME="$(echo "$INPUT_JSON" | jq -r '.username')"
PASSWORD="$(echo "$INPUT_JSON" | jq -r '.password')"
CA_CERT_B64="$(echo "$INPUT_JSON" | jq -r '.ca_cert_b64')"

# Create a temporary directory for the CA cert
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

CA_PEM="$TMPDIR/ca.pem"
# Decode the base64 CA cert to a PEM file
echo "$CA_CERT_B64" | base64 -d > "$CA_PEM"

# Build Basic Auth header value
BASIC_AUTH="$(printf '%s:%s' "$USERNAME" "$PASSWORD" | base64)"

# Fetch ES root endpoint, which returns cluster metadata including version
# -s silent, -S show errors, --fail for HTTP errors
# --cacert to trust the provided CA
RESP="$(curl -sS --fail \
  -H "Authorization: Basic $BASIC_AUTH" \
  --cacert "$CA_PEM" \
  "$URL")"

# Parse version.number using jq
VERSION_NUMBER="$(echo "$RESP" | jq -r '.version.number // empty')"

# The external data source expects a flat JSON object on stdout.
# If version_number is empty, still return valid JSON but with null.
if [[ -z "$VERSION_NUMBER" ]]; then
  echo '{"version_number":null}'
else
  echo "{\"version_number\":\"$VERSION_NUMBER\"}"
fi