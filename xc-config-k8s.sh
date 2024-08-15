#!/bin/bash
#8/14 this script is not functional yet as the service account does not seem to have the necessary perms. ticket opened to clarify. 

# Variables
ROLE_NAME=service-discovery-role
ROLE_BINDING_NAME=service-discovery-binding
KUBECONFIG_FILE=./kubeconfig
KUBE_SYSTEM_NAMESPACE="kube-system"


# User Defined Variables with Default Values
read -p "Enter the Namespace [Default= default]: " NAMESPACE
NAMESPACE=${NAMESPACE:-default}

read -p "Enter the IP Addr of the Kube API Server [Default= 10.1.1.6]: " IP_ADDR
IP_ADDR=${IP_ADDR:-10.1.1.6}

read -p "Enter the Service Account Name [Default= xc-sa]: " SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-xc-sa}

echo 'Creating Service Account real quick...'
kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE

if [ $? -ne 0 ]; then
  echo "Error: Failed to create Service Account"
  exit 1
fi

# Set Token Duration 
echo "You are about so set the SA token timemout value. You should have already run the set-token-timeout-util to adjust the kube-apiserver manifest file which had a default value timeout of 1 hour"
echo "#####################################################"
read -p "How many hours would you like the service account token to be valid for (up to 720 hours - 30 days) [Default= 24]: " DURATION
DURATION=${DURATION:-24}

# Generate 1 Hour Token 
# Note this token is good for the default of 1 hour. You can adjust this by running the 
# token-timeout-utility.sh and defining your timeout parameters in days. 
#TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE)
#echo 'Token Created'

# Generate token with duration. Uncomment below two lines after running the set-token-timeout-util. Set duration in hours.

TOKEN=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE --duration=$DURATION\h)

if [ $? -ne 0 ]; then
  echo "Error: Failed to create token"
  exit 1
fi

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

if [ $? -ne 0 ]; then
  echo "Error: Failed to create secret"
  exit 1
fi

# Patch the ServiceAccount with the new secret
kubectl patch serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -p '{"secrets": [{"name": "xc-sa-secret"}]}'

if [ $? -ne 0 ]; then
  echo "Error: Failed to patch Service Account"
  exit 1
fi

# Extract the CA certificate (already created by us, so no need to extract it again)
#CACRT=$(cat /etc/kubernetes/pki/ca.crt | base64 --decode)
CACRT=$(cat /etc/kubernetes/pki/ca.crt | base64 | tr -d '\n')

# Apply ClusterRole and ClusterRoleBinding with Service Discovery Permissions
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

if [ $? -ne 0 ]; then
  echo "Error: Failed to apply ClusterRole"
  exit 1
fi

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ROLE_NAME}-binding
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: $ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

if [ $? -ne 0 ]; then
  echo "Error: Failed to apply ClusterRoleBinding"
  exit 1
fi

# Get the API Server URL
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Add ClusterRoleBinding for Cluster Admin privileges (for testing need to remove after support verifies)
kubectl create clusterrolebinding debug-binding --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:${SERVICE_ACCOUNT_NAME}

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

if [ $? -ne 0 ]; then
  echo "Error: Failed to apply generate kubeconfig file"
  exit 1
fi

# Install tools to finesse yaml on kubeconfig output file
if ! command -v yq &>/dev/null; then
  echo "yq not found, installing..."

  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download yq"
    exit 1
  fi

  sudo chmod +x /usr/bin/yq

  if [ $? -ne 0 ]; then
    echo "Error: Failed to set executable permission on yq"
    exit 1
  fi
fi  # <--- This 'fi' was missing to close the yq installation block

# Clean up the YAML with yq
yq eval -P $KUBECONFIG_FILE -o yaml > cleaned_kubeconfig.yaml

mv cleaned_kubeconfig.yaml $KUBECONFIG_FILE

echo "kubeconfig file generated at: $KUBECONFIG_FILE"
echo "The token in this kubeconfig file is good for $DURATION hours. View the Readme.md for more info."
echo "You can test the token by running the following command: kubectl --kubeconfig=/home/ubuntu/kubeconfig get namespaces -n kube-system"