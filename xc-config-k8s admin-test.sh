#!/bin/bash
#8/14 This script works but is just a PoC...it is overly permissive. 

# Variables
ROLE_NAME=service-discovery-role
ROLE_BINDING_NAME=service-discovery-binding
KUBECONFIG_FILE=./kubeconfig

# User Defined Variables with Default Values
read -p "Enter the Namespace [Default= default]: " NAMESPACE
NAMESPACE=${NAMESPACE:-default}

read -p "Enter the IP Addr of the Kube API Server [Default= 10.1.1.6]: " IP_ADDR
IP_ADDR=${IP_ADDR:-10.1.1.6}

read -p "Enter the Service Account Name [Default= xc-sa]: " SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-xc-sa}

echo 'Creating Service Account real quick...'
kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE

# Generate 1 Hour Token 
# Note this token is good for the default of 1 hour. You can adjust this by running the 
# token-timeout-utility.sh and defining your timeout parameters. 
TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE)
echo 'Token Created'

# Generate token with duration. Uncomment below two lines after running the set-token-timeout-util. Set duration in hours
#DURATION=24
#TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE --duration=$DURATION)

# Warning Message
echo "###############################################"
echo "# WARNING: The generated token is sensitive!  #"
echo "# Keep this token private and do not share it! #"
echo "###############################################"

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
kind: ClusterRole
metadata:
  name: $ROLE_NAME
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "namespaces"]
  verbs: ["get", "list", "watch"]
EOF

# Create and Apply the Role Binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ROLE_NAME}-binding
subjects:
- kind: ServiceAccount
  name: xc-sa
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: $ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

# Create and Apply a Role with Namespace Access Permissions specifically for the kube-system namespace
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${ROLE_NAME}-kube-system
  namespace: $KUBE_SYSTEM_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
EOF

# Create and Apply the Role Binding in the kube-system namespace
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ROLE_BINDING_NAME}-kube-system
  namespace: $KUBE_SYSTEM_NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: ${ROLE_NAME}-kube-system
  apiGroup: rbac.authorization.k8s.io
EOF

# Add ClusterRoleBinding for Cluster Admin privileges (for testing)
kubectl create clusterrolebinding ${SERVICE_ACCOUNT_NAME}-cluster-admin-binding --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:${SERVICE_ACCOUNT_NAME}

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
echo "The token in this kubeconfig file is good for the k8s default of 1 hour. View the Readme.md for more info."
echo "You can test the token by running the following command: kubectl --kubeconfig=/home/ubuntu/kubeconfig get namespaces -n kube-system"
