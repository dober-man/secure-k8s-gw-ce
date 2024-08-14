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

## Setup K8s for Service Discovery from XC-CE
1. Copy xc-k8s-setup.sh script into $HOME directory.
2. Give script exe permissions (chmod +x xc-k8s-setup.sh)
3. Run xc-k8s-setup.sh

### Script Overview
The xc-config-k8s.sh script performs the following tasks:

* Validates and sets up the necessary Kubernetes ServiceAccounts, Roles, and RoleBindings.
* Generates and applies secure configurations for Kubernetes.
* Validates the generated YAML files to ensure they are well-formatted.
* Manages ServiceAccount tokens, including generating tokens with extended expiration (default token expiration is 1 hour)
Note: This timeout can be modified by updating the kubeapi manifest. There is a tool in the utils folder to perform this task. After updating the kube api manifest, uncomment lines in the xc-config-k8s.sh to generate a token with a user-defined expiration. 
   
## Extract kubeconfig file content for use in XC Console "Service Discovery" definition. 
1. In $HOME directory run: cat ./kubeconfig

Note: The file content will contain a "server" definition pointing to whatever server hostname you used when deplopying the script initially. (This may need to be changed to an ip address when importing the kubeconfig to XC service discovery definition if the CE is not able to resolve the address configured)

2. Copy the contents of the file to your clipboard and make sure to not grab any trailing whitespaces or extras. 

Note: This is highly sensitive data and should be secured as such. 
You will soon paste this output into XC Console Service Discovery as a blindfolded secret. 

## XC Console
(You will need owner level admin access to tenant)
Login to tenant – get site token

Console or Site UI into XC-CE
admin/Volterra123 – change passwd
configure now 
enter 
voltstack-combo

In XC Console - Register – Accept
Create Service Discovery 
 
<img width="210" alt="image" src="https://github.com/user-attachments/assets/bbafcf13-b282-4e5b-8a20-ecfc84f283b2">

For access credentials: 
 
<img width="300" alt="image" src="https://github.com/user-attachments/assets/1e7f05e8-4cf0-49a4-8b15-c6554ff26ba0">


