#!/bin/bash

# Variables
DEBUG_MODE=$1 # "on" to enable debugging, "off" to disable debugging
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
AUDIT_POLICY_FILE="/etc/kubernetes/audit-policy.yaml"
AUDIT_LOG_FILE="/var/log/kubernetes/audit.log"
NAMESPACE=default
SERVICE_ACCOUNT_NAME=xc-service-account
SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)


# Function to enable debugging and apply audit policy
enable_debugging() {
    echo "Enabling kube-apiserver debugging and audit policy..."

    # Ensure the audit log directory exists
    sudo mkdir -p /var/log/kubernetes/
    sudo chmod 755 /var/log/kubernetes/
    sudo chown root:root /var/log/kubernetes/
    sudo aa-status
    sudo aa-teardown

    # Update kube-apiserver.yaml for debugging
    sudo sed -i 's/--v=[0-9]*/--v=8/' $APISERVER_MANIFEST

    # Create an audit policy file
    sudo tee $AUDIT_POLICY_FILE > /dev/null <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods", "services"]
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
  - level: None
    users: ["system:kube-proxy"]
  - level: Request
    resources:
      - group: "rbac.authorization.k8s.io"
EOF

    # Add audit policy to kube-apiserver.yaml
    sudo sed -i "/--v=/a \    - --audit-policy-file=$AUDIT_POLICY_FILE\n    - --audit-log-path=$AUDIT_LOG_FILE\n    - --audit-log-maxage=30\n    - --audit-log-maxbackup=10\n    - --audit-log-maxsize=100" $APISERVER_MANIFEST

    echo "kube-apiserver debugging and audit policy enabled."
}

# Function to disable debugging and remove audit policy
disable_debugging() {
    echo "Disabling kube-apiserver debugging and audit policy..."

    # Update kube-apiserver.yaml to remove debug and audit configurations
    sudo sed -i 's/--v=[0-9]*/--v=2/' $APISERVER_MANIFEST
    sudo sed -i "/--audit-policy-file=/d" $APISERVER_MANIFEST
    sudo sed -i "/--audit-log-path=/d" $APISERVER_MANIFEST
    sudo sed -i "/--audit-log-maxage=/d" $APISERVER_MANIFEST
    sudo sed -i "/--audit-log-maxbackup=/d" $APISERVER_MANIFEST
    sudo sed -i "/--audit-log-maxsize=/d" $APISERVER_MANIFEST

    echo "kube-apiserver debugging and audit policy disabled."
}

# Main logic to toggle debugging and audit policy
if [ "$DEBUG_MODE" == "on" ]; then
    enable_debugging
elif [ "$DEBUG_MODE" == "off" ]; then
    disable_debugging
else
    echo "Usage: $0 {on|off}"
    exit 1
fi

echo "Running Test"
curl -k --cacert /etc/kubernetes/pki/ca.crt --header "Authorization: Bearer $TOKEN" https://10.1.1.6:6443/api/v1/namespaces/default/pods

echo "Check Log: ls -l /var/log/kubernetes/audit.log"