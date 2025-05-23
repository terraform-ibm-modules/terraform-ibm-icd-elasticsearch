#!/bin/bash
set -e

# Parse arguments
REGION="$1"
DEPLOYMENT_ID="$2"
PASSWORD="$3"
KIBANA_APP_USER="$4"
KIBANA_APP_PWD="$5"

[[ -z "$REGION" ]] && { echo "ERROR: Elasticsearch region is required as first argument"; exit 1; }
[[ -z "$DEPLOYMENT_ID" ]] && { echo "ERROR: Elasticsearch deployment ID is required as second argument"; exit 1; }
[[ -z "$PASSWORD" ]] && { echo "ERROR: Elasticsearch built-in kibana_system user's password required as third argument"; exit 1; }
[[ -z "$KIBANA_APP_USER" ]] && { echo "ERROR: Kibana app user required as fourth argument"; exit 1; }
[[ -z "$KIBANA_APP_PWD" ]] && { echo "ERROR: Kibana app password required as fifth argument"; exit 1; }

# Base ICD API URL
BASE_URL="https://api.${REGION}.databases.cloud.ibm.com/v5/ibm/deployments/${DEPLOYMENT_ID}/users/database"
HEADERS=(-H "Authorization: $IAM_TOKEN" -H "Content-Type: application/json")

# Handle API responses
handle_response() {
     response="$1"
     action="$2"
    
     http_status=$(echo "$response" | tail -n1 | sed 's/HTTP_STATUS://')
     response_body=$(echo "$response" | sed '$d')
    
    case "$http_status" in
        202)
            echo "SUCCESS: $action task created successfully"
            [[ -n "$response_body" ]] && echo "Response: $response_body"
            return 0
            ;;
        403)
            echo "ERROR: Authentication failed (403 - Invalid token)"
            [[ -n "$response_body" ]] && echo "Response: $response_body"
            return 1
            ;;
        422)
            echo "ERROR: Invalid request (422 - Validation error)"
            [[ -n "$response_body" ]] && echo "Response: $response_body"
            return 1
            ;;
        *)
            echo "ERROR: Unexpected status code: $http_status"
            [[ -n "$response_body" ]] && echo "Response: $response_body"
            return 1
            ;;
    esac
}

# API call function to call ICD APIs
make_api_call() {
     method="$1"
     url="$2"
     payload="$3"
    
    curl -s -w "\nHTTP_STATUS:%{http_code}" -X "$method" "$url" "${HEADERS[@]}" -d "$payload"
}

echo "Setting password for built-in `kibana_system` user"

# Update Elasticsearch built-in `kibana_system` password for the Code Engine Kibana to access Elasticsearch instance as a limited access
response=$(make_api_call "PATCH" "${BASE_URL}/kibana_system" "{\"user\": {\"password\": \"$PASSWORD\"}}")
if ! handle_response "$response" "Password update"; then
    exit 1
fi

echo "Creating Kibana dashboard user: $KIBANA_APP_USER"

# Create Kibana app dashboard login user and setup password
response=$(make_api_call "POST" "${BASE_URL}" "{\"user\": {\"username\": \"$KIBANA_APP_USER\", \"password\": \"$KIBANA_APP_PWD\"}}")
if ! handle_response "$response" "Kibana dashboard user creation"; then
    exit 1
fi
