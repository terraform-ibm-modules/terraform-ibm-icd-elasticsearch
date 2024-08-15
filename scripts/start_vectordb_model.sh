#!/bin/bash
set -e

#Function to start the vectorDB model
Start_model() {

# It takes few minute for the model to finish installing before we can start trained model deployment, therefore we sleep for 180 seconds (3m).
sleep 180
# Learn more https://www.elastic.co/guide/en/elasticsearch/reference/current/start-trained-model-deployment.html
response=$(curl -s -w "%{http_code}" -kX POST "$ES/_ml/trained_models/$ELSER_MODEL_TYPE/deployment/_start?wait_for=started&timeout=3m&deployment_id=for_search&pretty")

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
