#!/bin/bash
set -e

INSTALL_NEW_MODEL=true

# get trained models from elasticsearch
sleep=2
for i in $(seq 1 4); do
    sleep=$((sleep*2))

    sleep $sleep
    result=$(curl -s -w "%{http_code}" -kX GET "$ES/_ml/trained_models?pretty")

    http_code=$(tail -n1 <<< "$result")
    content=$(sed '$ d' <<< "$result")
    # Check the result
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "Trained models successfully pulled from elasticsearch."
        break
    else
        echo "Failed to get the trained models from elasticsearch. HTTP status code: $http_code"
        echo "Reponse: $content"
        if [ "$i" -eq 4 ]; then
          exit 1
        fi
    fi
done

# fetch all model_ids created by customer (api_user) from the result
model_ids=$(echo "$content" | jq ".trained_model_configs[] | select(.model_id and .created_by == \"api_user\") | .model_id")

# loop through result and delete unwanted models

for model_id in $model_ids
do
    # need to remove double quotes
    model=${model_id//"\""/""}
    echo "Check if model '$model' should be deleted from elasticsearch."
    if [ "$ELSER_MODEL_TYPE" != "$model" ]; then
        # deleting trained model
        echo "Delete: $model from elasticsearch"
        sleep=2
        for i in $(seq 1 4); do
          sleep=$((sleep*2))

          sleep $sleep
          result=$(curl -s -w "%{http_code}" -kX DELETE "$ES/_ml/trained_models/$model?pretty")
          http_code=$(tail -n1 <<< "$result")
          content=$(sed '$ d' <<< "$result")
          # Check the result
          if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
              echo "Trained model '$model' successfully deleted from elasticsearch."
              break
          else
              echo "Failed to delete the trained model '$model' from elasticsearch. HTTP status code: $http_code"
              echo "Reponse: $content"
              if [ "$i" -eq 4 ]; then
                exit 1
              fi
          fi
        done
    else
        INSTALL_NEW_MODEL=false
        echo "Do not delete model '$model' from elasticsearch."
    fi
done

# deploy a new trained model using retry
if [ "$INSTALL_NEW_MODEL" = true ] ; then
    sleep=2
    for i in $(seq 1 4); do
        sleep=$((sleep*2))

        sleep $sleep
        # learn more https://www.elastic.co/docs/api/doc/elasticsearch-serverless/operation/operation-ml-put-trained-model#operation-ml-put-trained-model-wait_for_completion
        response=$(curl -s -w "%{http_code}" -kX PUT "$ES/_ml/trained_models/$ELSER_MODEL_TYPE?wait_for_completion=true&pretty" -H 'Content-Type: application/json' -d'
        {
            "input": {
            "field_names": ["text_field"]
            }
        }
        ')

        http_code=$(tail -n1 <<< "$response")
        content=$(sed '$ d' <<< "$response")

        # Check the result
        if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
            echo "Trained model '$ELSER_MODEL_TYPE' installed successfully."
            break
        else
            echo "Failed to install the model '$ELSER_MODEL_TYPE'. HTTP status code: $http_code"
            echo "Reponse: $content"
            if [ "$i" -eq 4 ]; then
                exit 1
            fi
        fi
    done
else
    echo "Model '$ELSER_MODEL_TYPE' already installed. Do not install it."
fi
