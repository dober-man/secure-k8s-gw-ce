#!/bin/bash

# Variables
ROLE_NAME=service-discovery-role
ROLE_BINDING_NAME=service-discovery-binding
KUBECONFIG_FILE=./kubeconfig
read -p "Enter the IP Addr of the Kube API Server [default: 10.1.1.6]: " IP-ADDR
IP-ADDR=${IP-ADDR:-10.1.1.6}

# User Defined Variables with Default Values
read -p "Enter the Namespace [default: default]: " NAMESPACE
NAMESPACE=${NAMESPACE:-default}

read -p "Enter the Service Account Name [default: xc-sa]: " SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-xc-sa}

echo 'Creating Service Account real quick...'
kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE


# Generate Token 
# Note this token is good for the default of 1 hour. You can adjust this by running the 
# token-timeout-utility.sh and defining your timeout parameters. 
TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE)
echo 'Token Created'

# Warning Message
echo "###############################################"
echo "# WARNING: The generated token is sensitive!  #"
echo "# Keep this token private and do not share it! #"
echo "###############################################"

# Print the generated token
#echo "Generated Token: $TOKEN"

# Create a secret
kubectl create secret generic xc-sa-secret --from-literal=token=$TOKEN --from-file=ca.crt=/etc/kubernetes/pki/ca.crt -n $NAMESPACE

# Patch the ServiceAccount with the new secret
kubectl patch serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -p '{"secrets": [{"name": "xc-sa-secret"}]}'

# Get the secret name associated with the ServiceAccount (this will now include the newly created secret)
SECRET_NAME="xc-sa-secret"

# Extract the CA certificate (already created by us, so no need to extract it again)
#CACRT=$(cat /etc/kubernetes/pki/ca.crt | base64 --decode)
CACRT=$(cat /etc/kubernetes/pki/ca.crt | base64 | tr -d '\n')

# Create and Apply a Role with Service Discovery Permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $ROLE_NAME
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
EOF

# Create and Apply the Role Binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $ROLE_BINDING_NAME
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: $ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

# Get the API Server URL
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Generate the kubeconfig File
echo "---
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: $(echo "$CACRT" | sed 's/^/      /')
    server: $APISERVER
contexts:
- name: service-discovery-context
  context:
    cluster: kubernetes
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT_NAME
current-context: service-discovery-context
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: \"$TOKEN\"
" > $KUBECONFIG_FILE

# Install tools to finesse yaml on kubeconfig output file
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq

# Clean up the YAML with yq
yq eval -P $KUBECONFIG_FILE -o yaml > cleaned_kubeconfig.yaml


mv cleaned_kubeconfig.yaml $KUBECONFIG_FILE

echo "kubeconfig file generated at: $KUBECONFIG_FILE"
echo "The token in this kubeconfig file is good for the default of 1 hour. You can adjust this by running the 
token-timeout-utility.sh to update the duration in the kubeapi manifest and defining your timeout parameters. 
