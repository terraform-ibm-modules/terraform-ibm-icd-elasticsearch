#!/bin/bash
set -e

#Function to start the vectorDB model
Start_model() {

response=$(curl --connect-timeout 300 -s -w "%{http_code}" -kX POST "$ES/_ml/trained_models/.elser_model_1/deployment/_start?deployment_id=for_search&pretty")

http_code=$(tail -n1 <<< "$response")
content=$(sed '$ d' <<< "$response")

# Check the HTTP status code
if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
  echo "Request sent successfully."
else
  echo "Failed to start the vectorDB model. HTTP status code: $http_code"
  echo "Reponse: $content"
  exit 1
fi

}

Start_model
