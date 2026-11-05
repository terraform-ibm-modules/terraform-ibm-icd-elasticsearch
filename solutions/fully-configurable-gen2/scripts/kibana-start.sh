#!/bin/bash

# Startup command of the Kibana Code Engine app. Gen2 Elasticsearch is reached over a Private Path connection,
# whose endpoint has its own hostname, but the instance only accepts TLS connections whose SNI is its own
# hostname. So the real hostname is mapped to the Private Path endpoint: for curl with --resolve, and for Kibana with
# a Node.js preload script (es-dns-override.js). TLS is still fully verified against the real hostname.

set -euo pipefail

log() { echo "[kibana-start] $*"; }

PP_IP=""
for i in $(seq 1 60); do
  PP_IP="$(getent hosts "$PRIVATE_PATH_ENDPOINT" | awk '{print $1; exit}' || true)"
  [ -n "$PP_IP" ] && break
  log "Waiting for the Private Path endpoint ${PRIVATE_PATH_ENDPOINT} to resolve (${i}/60)"
  sleep 5
done
if [ -z "$PP_IP" ]; then
  log "ERROR: the Private Path endpoint ${PRIVATE_PATH_ENDPOINT} did not resolve. Check that the Code Engine Private Path connection is permitted."
  exit 1
fi

ES_URL="https://${ES_HOSTNAME}:${ES_PORT}"
# Retried, since a new credential's IAM access can lag behind its Terraform resource reporting as created.
# --fail turns HTTP errors (for example a transient 401) into failures so they are retried too.
CURL=(curl -sS --fail --retry 30 --retry-delay 10 --retry-all-errors --connect-timeout 10 --resolve "${ES_HOSTNAME}:${ES_PORT}:${PP_IP}")

# Kibana must run the same major.minor version as Elasticsearch.
ES_VERSION="$("${CURL[@]}" -u "${ES_ADMIN_USERNAME}:${ES_ADMIN_PASSWORD}" "${ES_URL}/" | sed -n 's/.*"number" *: *"\([^"]*\)".*/\1/p')"
KIBANA_VERSION="$(sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' /usr/share/kibana/package.json | head -1)"
log "Elasticsearch version ${ES_VERSION}, Kibana version ${KIBANA_VERSION}"
if [ "$(echo "$ES_VERSION" | cut -d. -f1-2)" != "$(echo "$KIBANA_VERSION" | cut -d. -f1-2)" ]; then
  log "ERROR: Kibana ${KIBANA_VERSION} is not compatible with Elasticsearch ${ES_VERSION}. Set kibana_version to a ${ES_VERSION%.*}.x release."
  exit 1
fi

# The Manager credential maps to ibm_admin_role, which cannot manage the restricted .kibana* indices Kibana's own
# backend needs. So Kibana authenticates as the reserved kibana_system user, whose password is set here.
"${CURL[@]}" -o /dev/null -u "${ES_ADMIN_USERNAME}:${ES_ADMIN_PASSWORD}" -X PUT "${ES_URL}/_security/user/kibana_system/_password" \
  -H 'Content-Type: application/json' -d "{\"password\":\"${ELASTICSEARCH_PASSWORD}\"}"
log "kibana_system password set"

export ELASTICSEARCH_HOSTS="$ES_URL"
export ELASTICSEARCH_USERNAME="kibana_system"
export NODE_OPTIONS="--require ${KIBANA_SCRIPTS_DIR}/es-dns-override.js"
log "Starting Kibana"
exec /usr/local/bin/kibana-docker
