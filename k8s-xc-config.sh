#!/bin/bash

# Variables
SERVICE_ACCOUNT_NAME=xc-service-account
NAMESPACE=default
ROLE_NAME=service-discovery-role
ROLE_BINDING_NAME=service-discovery-binding
KUBECONFIG_FILE=./kubeconfig

# Step 1: Create a Service Account
kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE

# Step 2: Create and Apply a Role with Service Discovery Permissions
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

# Step 3: Create and Apply the Role Binding
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

# Step 4: Manually create and Bind Secret
kubectl create secret generic ${SERVICE_ACCOUNT_NAME}-token --from-literal=token=$(openssl rand -hex 32) --from-file=ca.crt=/etc/kubernetes/pki/ca.crt -n $NAMESPACE
kubectl patch serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -p '{"secrets": [{"name": "'${SERVICE_ACCOUNT_NAME}-token'"}]}'


# Step 5: Extract the Service Account Token and CA Certificate with retry mechanism
SECRET_NAME=""
RETRIES=5
for i in $(seq 1 $RETRIES); do
    SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -o jsonpath='{.secrets[0].name}')
    if [ ! -z "$SECRET_NAME" ]; then
        break
    fi
    echo "Waiting for the secret to be created... ($i/$RETRIES)"
    sleep 5
done

if [ -z "$SECRET_NAME" ]; then
  echo "Error: Failed to retrieve the secret name after $RETRIES attempts."
  exit 1
fi

TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
CACRT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 --decode)

# Debugging: Check if the token was extracted correctly
if [ -z "$TOKEN" ]; then
  echo "Error: Token extraction failed. Token is empty."
  exit 1
else
  echo "Token extracted successfully."
fi

# Step 5: Get the API Server URL
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Step 6: Generate the kubeconfig File
cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: $(echo "$CACRT" | base64)
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
    token: $TOKEN
EOF

yq eval -P $KUBECONFIG_FILE -o yaml > cleaned_kubeconfig.yaml
mv cleaned_kubeconfig.yaml $KUBECONFIG_FILE

echo "kubeconfig file generated at: $KUBECONFIG_FILE"

yamllint kubeconfig
