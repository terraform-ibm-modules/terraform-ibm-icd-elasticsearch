#!/bin/bash

export ES="http://admin:${PASSWORD}@${HOSTNAME}:${PORT}"

#Function to put the vectorDB model
Start_model() {

response=$(curl -s -o /dev/null -w "%{http_code}" -kX POST "$ES/_ml/trained_models/.elser_model_1/deployment/_start?deployment_id=for_search&pretty")

# Check the HTTP status code
if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
  echo "Request sent successfully."
else
  echo "Failed to send request. HTTP status code: $response"
fi

}

Start_model
