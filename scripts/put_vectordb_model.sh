#!/bin/bash

#Function to install the vectorDB model
Put_model() {

response=$(curl -s -o /dev/null -w "%{http_code}" -kX PUT "$ES/_ml/trained_models/.elser_model_1?pretty" -H 'Content-Type: application/json' -d'
{
  "input": {
	"field_names": ["text_field"]
  }
}
')

# Check the HTTP status code
if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
  echo "Request sent successfully."
else
  echo "Failed to install the vectorDB model. HTTP status code: $response"
fi

}

Put_model
