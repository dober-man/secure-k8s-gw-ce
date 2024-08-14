#!/bin/bash

# Prompt user for Service Account Name with a default value
read -p "Enter the Service Account Name [default: xc-sa]: " SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-xc-sa}

# Prompt user for Namespace with a default value
read -p "Enter the Namespace [default: default]: " NAMESPACE
NAMESPACE=${NAMESPACE:-default}

# Prompt user for the number of days with a default of 1 day
read -p "Enter the number of days for token validity [default: 1]: " DURATION_DAYS
DURATION_DAYS=${DURATION_DAYS:-1}

# Convert days to hours for the duration
DURATION_HOURS=$(($DURATION_DAYS * 24))"h"

# Variables (replace these with your actual values)
KUBECONFIG_FILE="/home/$SUDO_USER/.kube/config"
APISERVER_YAML="/etc/kubernetes/manifests/kube-apiserver.yaml"

# Ensure you have permissions to modify the API server manifest
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root to modify the API server manifest."
   exit 1
fi

# Step 1: Modify the kube-apiserver manifest to set the token expiration to the user-defined duration
echo "Modifying the API server configuration to allow a $DURATION_DAYS-day token expiration..."
sed -i '/--service-account-max-token-expiration=/d' $APISERVER_YAML
sed -i "/kube-apiserver/a \    - --service-account-max-token-expiration=$DURATION_HOURS" $APISERVER_YAML

# Restart the kube-apiserver to apply changes (only necessary if running in non-managed Kubernetes)
echo "Restarting the kube-apiserver..."
KUBE_API_CONTAINER_ID=$(docker ps | grep kube-apiserver | awk '{print $1}')
if [ -z "$KUBE_API_CONTAINER_ID" ]; then
  echo "Failed to find the kube-apiserver container. Ensure the container is running and the command is correct."
  exit 1
else
  docker restart $KUBE_API_CONTAINER_ID
fi

# Step 2: Generate the token with the user-defined duration
echo "Generating a token for the ServiceAccount '$SERVICE_ACCOUNT_NAME' in the namespace '$NAMESPACE' with a duration of $DURATION_DAYS days..."
TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE --duration=$DURATION_HOURS --kubeconfig=$KUBECONFIG_FILE)

if [ $? -eq 0 ]; then
  echo "Token generated successfully:"
  echo $TOKEN
else
  echo "Failed to generate the token."
  exit 1
fi
