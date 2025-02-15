#!/bin/bash

# Define the namespaces and secret names
namespace="default"
secrets=( "pg-credentials")

# Loop through the secret names and check/delete each one
for secret_name in "${secrets[@]}"; do
    if kubectl get secret "$secret_name" -n "$namespace" &> /dev/null; then
        # If it exists, delete it
        kubectl delete secret "$secret_name" -n "$namespace"
        echo "Secret $secret_name deleted in namespace $namespace."
    else
        # If it doesn't exist, print a message
        echo "Secret $secret_name does not exist in namespace $namespace."
    fi
done


kubectl create configmap nginx-domain-names-env-vars --from-env-file=$NOLUCK/deployment-scripts/domain-names.env

kubectl apply -f $NOLUCK/deployment-scripts/pg-credentials.yaml
