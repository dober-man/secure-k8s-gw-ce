#!/bin/bash

# Set variables
DEPLOYMENT_NAME="echoserver-deployment"
SERVICE_NAME="echoserver-service"
REPLICAS=4
NODE_PORT=30080

# Create Deployment YAML
cat <<EOF > echoserver-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: echoserver
  template:
    metadata:
      labels:
        app: echoserver
    spec:
      containers:
      - name: echoserver
        image: k8s.gcr.io/echoserver:1.4
        ports:
        - containerPort: 8080
EOF

# Apply Deployment
kubectl apply -f echoserver-deployment.yaml

# Create Service YAML
cat <<EOF > echoserver-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
spec:
  selector:
    app: echoserver
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      nodePort: $NODE_PORT
  type: NodePort
EOF

# Apply Service
kubectl apply -f echoserver-service.yaml

# Output status
echo "Deployment and Service for echoserver have been created:"
kubectl get deployments $DEPLOYMENT_NAME
kubectl get svc $SERVICE_NAME
