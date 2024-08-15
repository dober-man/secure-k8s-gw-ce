# Why Service Discovery with a CE? 
The F5 Distributed Cloud (XC) Virtual Edition (VE) Customer Edge (CE) platform can be deployed within your data center or cloud environment and perform service discovery for services in your Kubernetes (K8s) clusters. The CE uses the kube-apiserver to query for services as they come online. Admins can then reference these discovered services in their XC origin pool definitions and publish them locally through a proxy (http load balancer) on the CE itself or via our Global Application Delivery Network (Regional Edge Deployment). The http load balancer can offer a suite of security services providing an easy to consume layered security model with global redundancy while serving content from private k8's cluster. 

# Overview and Goals 
1.  Build and configure a Ubuntu server with K8's running simple NGINX web server exposed on NodePort. 
2.  Configure XC virtual CE for Service Discovery
3.  Publish and secure service to public

# Features
* Automated Installation: The script installs a Kubernetes cluster with minimal user intervention.
* Security Enhancements: Includes configurations to enhance the security of your Kubernetes setup.
* Customizable Options: Users can define custom settings for the installation, ensuring the setup meets their specific requirements.

## Prerequisite

### CPU/RAM/DISK               
XC virtual CE (RHEL) - 8/32/200

Ubuntu K8s (Vanilla Install of Ubuntu 22.04) 4/16/100

XC Console - (You will need owner/admin access to a tenant)
   Permissions Needed: 
   * Perm1
   * Perm2

## Install K8s
1. ssh into ubuntu-k8s server
2. Copy k8s-install.sh script into $HOME directory.
3. Give script exe permissions (chmod +x k8s-install.sh)
4. Run ./k8s-install.sh

### Script Overview
The k8s-install.sh script performs the following tasks:

* Installs required packages and dependencies
* Sets up Kubernetes components (e.g., kubeadm, kubelet, kubectl)
* Configures networking and security settings
* Initializes the Kubernetes cluster
* Applies security best practices to the cluster configuration

## Service Account Token Timeout Considerations. 
By default k8s will generate tokens that have a max-life of 1 hour. You can adjust this default behavior by modifying the kube-apiserver manifest. 
The set-token-timeout-util.sh script in the utils folder of this repo can do this for you. To use the script, download it to your $HOME directory and give it permissions to execute (chmod +x set-token-timeout-util.sh)

The script will ask how many days you would like the max token timeout to be. You are not generating a token yet....just configuring the mainfest to allow for lengthier token expiration dates for future tokens. In the next step when you run the xc-config-k8s.sh script, a token will ge generated for you and this will ultimately be in the kubeconfig file that is used between the CE and the kube-apiserver for service discovery. This token should be rotated periodically. 

## Setup K8s for Service Discovery from XC-CE
1. Copy xc-k8s-setup.sh script into $HOME directory.
2. Modify the section under "###Set Token Duration###" per your configuration. You can choose 1hr (default) or user defined. 
3. Give script exe permissions (chmod +x xc-k8s-setup.sh)
4. Run ./xc-k8s-setup.sh

### Script Overview
The xc-config-k8s.sh script performs the following tasks:

* WARNING - currently the SA needs a roll of cluster-admin to perform the service discovery. (ticket open to clarify minimum permissions for SA) - currently using: kubectl create clusterrolebinding debug-binding --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:${SERVICE_ACCOUNT_NAME} which is overly permissive for the service discovery.
 
* Validates and sets up the necessary Kubernetes ServiceAccounts, Roles, and RoleBindings.
* Generates and applies secure configurations for Kubernetes.
* Validates the generated YAML files to ensure they are well-formatted.
* Manages ServiceAccount tokens, including generating tokens with extended expiration (default token expiration is 1 hour)
 
## Extract kubeconfig file content for use in XC Console "Service Discovery" definition. 
1. In $HOME directory run: cat kubeconfig

Note: The file content will contain a "server" definition pointing to whatever server hostname you used when deploying the script initially. (This may need to be changed to an ip address when importing the kubeconfig to XC service discovery definition if the CE is not able to resolve the server name configured)

Note: This is highly sensitive data and should be secured as such. 
You will soon copy/paste this output into XC Console Service Discovery as a blindfolded secret. More info about blindfold here: https://docs.cloud.f5.com/docs/ves-concepts/security#secrets-management-and-blindfold

## XC Console Prereqs
(You will need owner level admin access to tenant)
or Permissions Needed: 
   * Perm1
   * Perm2

Step 1: Login to XC tenant – create site token: 

#### Multicloud Network Connect -> Manage -> Site Management -> Site Tokens -> Create

Step 2: Console or Site UI into XC-CE

admin/Volterra123 – change passwd

configure now...

enter Site Token from previous step

voltstack-combo

### XC Console 
#### Multicloud Network Connect -> Manage -> Site Management -> Registrations
Accept
#### Multicloud App Connect -> Manage -> Service Discovery -> Add Discovery

Name: my-sd

Virtual-Site or Site or Network: Site

Reference: - [choose your CE site]

Network Type: Site Local Network

Discovery Method: K8s Discovery Configuration
 
<img width="1164" alt="image" src="https://github.com/user-attachments/assets/ad8ddbe6-8360-4228-97ed-ee0511074dc3">

Click on "Configure" under K8S Discovery Configuration

#### Access credentials: 

Select Kubernetes Credentials: Kubeconfig

Click "Configure" under Kubeconfig

Secret Type: Blindfolded

Action: Blindfold New Secret

Policy Type: Built-in

Secret to Blindfold: [this is the content of the $HOME/kubeconfig file that was generated on the host that you ran the xc-config-k8s.sh script.] Copy the contents of the #HOME/kubeconfig file to your clipboard and make sure to not grab any trailing whitespaces or extras. 

Note - make sure to change the server name to IP if the CE can't resolve the hostname in the server definition within the file. 

File: 

<img width="607" alt="image" src="https://github.com/user-attachments/assets/54bb85bd-42ea-4d35-ae2b-dd83fd597977">

Secret in XC Console

<img width="624" alt="image" src="https://github.com/user-attachments/assets/1e3fdd04-9f29-4a83-b256-56be288c0b6e">

Click "Apply"

<img width="1088" alt="image" src="https://github.com/user-attachments/assets/8eee82dc-08d5-469e-986e-fccfeb08fc9b">

todo: add further description of options

## Publish the Service

Create Origin Pool: 

#### Multicloud App Connect -> Manage -> Load Balancers -> Origin Pools

<img width="1175" alt="image" src="https://github.com/user-attachments/assets/7d997917-fae5-486b-bc23-a7d47fc0fdf1">

<img width="1159" alt="image" src="https://github.com/user-attachments/assets/56b82090-a620-4415-8786-63ad4d214cc7">

Note: You must specify port 80 for the origin pool (even though it is technically dynamic at the Node/pod level)

Create http load balancer: 

#### Multicloud App Connect -> Manage -> Load Balancers -> http load balancer
...add creating LB and testing
