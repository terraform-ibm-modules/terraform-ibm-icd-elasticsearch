#!/bin/bash
set -e

#Function to install the vectorDB model
Put_model() {

response=$(curl -s -w "%{http_code}" -kX PUT "$ES/_ml/trained_models/.elser_model_1?pretty" -H 'Content-Type: application/json' -d'
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
else
  echo "Failed to install the vectorDB model. HTTP status code: $http_code"
  echo "Reponse: $content"
  exit 1
fi

}

Put_model
