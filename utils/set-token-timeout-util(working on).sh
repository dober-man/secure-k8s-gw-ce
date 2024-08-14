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

# Ensure valid positive integer for DURATION_DAYS
while ! [[ "$DURATION_DAYS" =~ ^[0-9]+$ ]] || [ "$DURATION_DAYS" -le 0 ]; do
    echo "Please enter a valid positive integer for the number of days."
    read -p "Enter the number of days for token validity [default: 1]: " DURATION_DAYS
    DURATION_DAYS=${DURATION_DAYS:-1}
done

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

# Backup the API server manifest
cp $APISERVER_YAML ${APISERVER_YAML}.bak

# Modify the kube-apiserver manifest to set the token expiration to the user-defined duration
echo "Modifying the API server configuration to allow a $DURATION_DAYS-day token expiration..."
sed -i '/--service-account-max-token-expiration=/d' $APISERVER_YAML
sed -i "/kube-apiserver/a \    - --service-account-max-token-expiration=$DURATION_HOURS" $APISERVER_YAML

# Restart the kube-apiserver to apply changes
echo "Restarting the kubelet service to apply changes..."
systemctl restart kubelet


#Check that the values were changed
echo "To verify run: sudo grep -- '--service-account-max-token-expiration=' /etc/kubernetes/manifests/kube-apiserver.yaml"
