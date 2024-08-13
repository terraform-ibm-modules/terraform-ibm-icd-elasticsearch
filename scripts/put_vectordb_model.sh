#!/bin/bash
set -e

#Function to install the vectorDB model
Put_model() {

sleep=2
for i in $(seq 1 4); do
  sleep=$((sleep*2))

  sleep $sleep
  # learn more https://www.elastic.co/docs/api/doc/elasticsearch-serverless/operation/operation-ml-put-trained-model#operation-ml-put-trained-model-wait_for_completion
  response=$(curl -s -w "%{http_code}" -kX PUT "$ES/_ml/trained_models/.elser_model_2_linux-x86_64?wait_for_completion=true&pretty" -H 'Content-Type: application/json' -d'
  {
    "input": {
    "field_names": ["text_field"]
    }
  }
  ')

  http_code=$(tail -n1 <<< "$response")
  content=$(sed '$ d' <<< "$response")

  # Check the HTTP status code
  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    echo "Request sent successfully."
    break
  else
    echo "Failed to install the vectorDB model. HTTP status code: $http_code"
    echo "Reponse: $content"
    if [ "$i" -eq 4 ]; then
      exit 1
    fi
  fi
done

}

Put_model
