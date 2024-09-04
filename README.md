# Why Service Discovery with a CE? 
The F5 Distributed Cloud (XC) Virtual Edition (VE) Customer Edge (CE) platform can be deployed within your data center or cloud environment and perform service discovery for services in your Kubernetes (K8s) clusters. 

The CE can use the native kube-apiserver, or Consul, to query for services as they come online. Admins can then reference these discovered services in their XC origin pool definitions and publish them locally through a proxy (http load balancer) on the CE itself or via our Global Application Delivery Network (Regional Edge Deployment). 

The F5 XC Load Balancer offers an entire suite of security services providing an easy to consume and globally redundant layered security model while serving content from private K8's clusters. 

# Overview and Goals 
1.  Build a simple consistent lab environment for PoC or self-education. 
2.  Configure a Ubuntu 22.04 server with vanilla install of K8s running an example NGINX web service exposed on NodePort. 
3.  Configure XC Virtual CE for Service Discovery. 
4.  Secure and publish service globally. 

# Features
* Automated Installations: The k8s-install.sh script installs a single node Kubernetes cluster with minimal user intervention.
* Option to Auto-install a worker node. Deploy a second Ubuntu server and in the $HOME directory run the k8s-install-worker.sh script (in utils folder)
* Customizable Options: Users can define custom settings for the installations and configurations, ensuring the setup meets their specific requirements.

## Prerequisite

### CPU/RAM/DISK               
1 - XC virtual CE (RHEL) - 8/32/200

1 - Ubuntu K8s master (Vanilla Install of Ubuntu 22.04) 4/16/100
<br>
(optional) 1 - Ubuntu K8s worker (Vanilla Install of Ubuntu 22.04) 4/16/100


XC Console - (You will need owner/admin access to a tenant)
If you are not owner/admin, a role with these minimum permissions is required: 
   * Perm1 (clarifying)
   * Perm2 (clarifying)

# Getting Started

## Install K8s
1. ssh into ubuntu-k8s server
2. Copy k8s-install.sh script into $HOME directory.
3. Give script exe permissions (chmod +x k8s-install.sh)
4. Run ./k8s-install.sh
5. Optionally deploy a worker node and in the $HOME directory run the k8s-install-worker.sh script (in utils folder), then join it to the cluster. 

### Script Overview
The k8s-install.sh script performs the following tasks:

* Installs required packages and dependencies
* Sets up Kubernetes components (e.g., kubeadm, kubelet, kubectl)
* Configures networking and security settings
* Initializes the Kubernetes cluster

**_NOTE:_**  Service discovery supports two types of auth; User or Service Account. This lab is built using Service Account Auth.

<img width="424" alt="image" src="https://github.com/user-attachments/assets/a46b2d33-6a24-411e-8217-b5cd15e8e12e">
<br>

User Auth (3rd party) is also supported but not covered in this lab. More info here: https://community.f5.com/kb/technicalarticles/using-a-kubernetes-serviceaccount-for-service-discovery-with-f5-distributed-clou/300225

<img width="433" alt="image" src="https://github.com/user-attachments/assets/855efbdb-e62b-45ff-8baf-05d6a15b5990">

## Service Account Token Timeout Considerations. 
By default K8s will generate tokens that have a max-life of 1 hour which should be enough to get through the end of this lab. If you are setting this lab up to persist more than 1 hour you may want a lengthier token timeout. You can adjust this default behavior by modifying the kube-apiserver manifest. 

The set-token-timeout-util.sh script in the utils folder of this repo can do this for you. To use the script, download it to your $HOME directory and give it permissions to execute (chmod +x set-token-timeout-util.sh)

The script will ask how many days you would like the max token timeout to be. You are not generating a token yet....just configuring the mainfest to allow for lengthier token expiration dates for future tokens. In the next step, when you run the xc-config-k8s.sh script, a token will be generated for you. This token will ultimately be part of the authentication in the kubeconfig file used between the CE and the kube-apiserver for Service Discovery. 

This token should be rotated periodically. If you do choose the 1 hour and it times out, you can run the remove-k8s-xc-config.sh script in the utils folder of this repo from the $HOME directory and re-run the xc-k8s-setup.sh as shown below: 

## Setup K8s for Service Discovery from XC-CE
1. Copy xc-k8s-setup.sh script into $HOME directory.
2. Modify the section under "###Set Token Duration###" per your configuration. You can choose 1hr (default) or user defined. 
3. Give script exe permissions (chmod +x xc-k8s-setup.sh)
4. Run ./xc-k8s-setup.sh

### Script Overview
The xc-config-k8s.sh script performs the following tasks:

###  WARNING - currently 8/15/24 - the Service Account needs a role of cluster-admin to perform the service discovery. (ticket open to clarify minimum permissions for SA) - currently using: kubectl create clusterrolebinding debug-binding --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:${SERVICE_ACCOUNT_NAME} which is overly permissive for the service discovery.
 
* Validates and sets up the necessary Kubernetes ServiceAccounts, Roles, and RoleBindings.
* Validates the generated YAML files to ensure they are well-formatted.
* Manages ServiceAccount tokens, including generating tokens with extended expiration (default token expiration is 1 hour)
 
## Extract kubeconfig file content for use in XC Console "Service Discovery" definition. 
1. In $HOME directory run: cat kubeconfig

**_NOTE:_** The file content will contain a "server" definition pointing to whatever server hostname you used when deploying the script initially. (This may need to be changed to an ip address when importing the kubeconfig to XC service discovery definition if the CE is not able to resolve the server name configured)

**_NOTE:_** This is highly sensitive data and should be secured as such. 
You will soon copy/paste this output into XC Console Service Discovery as a blindfolded secret. More info about blindfold here: https://docs.cloud.f5.com/docs/ves-concepts/security#secrets-management-and-blindfold

## XC Console Prereqs
You will need owner/admin access to a tenant
If you are not owner/admin, a role with these minimum permissions is required: 
   * Perm1 (clarifying)
   * Perm2 (clarifying)

Step 1: Login to XC tenant – create site token: 

#### Multicloud Network Connect -> Manage -> Site Management -> Site Tokens -> Create

Step 2: On your VE CE, use the local Console (cli) or Site UI to configure and register with the XC cloud platform. 

Default Login: 

admin/Volterra123 – change passwd

Configure now...

enter Site Token from previous step

voltstack-combo

Give coordinates as appropriate and apply settings. 

### XC Console 

Step 1: Login in to XC Cloud Console and accept the CE registration request. 

#### Multicloud Network Connect -> Manage -> Site Management -> Registrations

Click Accept on the CE registration request. 

Step 2: Create a Service Discovery.

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

Secret to Blindfold: [this is the content of the $HOME/kubeconfig file that was generated on the host that you ran the xc-config-k8s.sh script.] Copy the contents of the $HOME/kubeconfig file to your clipboard and make sure to not grab any trailing whitespaces or extras. 
<br>
<br>
**_NOTE:_** make sure to change the server name to IP if the CE can't resolve the hostname in the server definition within the file. In a lab environment without proper dns configured, it most likely can not use the hostname and there is not hostfile configuration capability on the CE itself.

File: 

<img width="607" alt="image" src="https://github.com/user-attachments/assets/54bb85bd-42ea-4d35-ae2b-dd83fd597977">

Secret in XC Console

<img width="624" alt="image" src="https://github.com/user-attachments/assets/1e3fdd04-9f29-4a83-b256-56be288c0b6e">

Click "Apply"

<img width="1088" alt="image" src="https://github.com/user-attachments/assets/8eee82dc-08d5-469e-986e-fccfeb08fc9b">

Click "Services" to see the full service name. You will need this for your origin pool definition in the next section. 

<img width="983" alt="image" src="https://github.com/user-attachments/assets/90273572-c944-43a1-83cf-0054a9b26771">

Step 3: 

## Create Origin Objects

Create Origin Servers and Pool with Discovered Service: 

#### Multicloud App Connect -> Manage -> Load Balancers -> Origin Pools -> Add Origin Pool 

Define the Origin Servers (click Add Item) and use the screenshot to fill in the config. 
<img width="1206" alt="image" src="https://github.com/user-attachments/assets/8010b034-f8b9-44c3-b6f8-8de6353b6c8b">

Define the Pool Definitions as shown in the screenshot. 
<img width="885" alt="image" src="https://github.com/user-attachments/assets/e9bfc1ed-2f3c-4e0a-9018-daa19b338122">
<img width="900" alt="image" src="https://github.com/user-attachments/assets/02710b3b-80cf-4c64-8de3-edb82997b6b4">


**_**_NOTE:_**:_**: You must specify port 80 for the origin pool (even though it is technically dynamic at the Node/pod level). Remember all traffic being sent between the XC cloud and CE is natively encrypted so this is all tunneled until the last hop to the pod. In our test scenario it will look like this: User-->80-->VIP-->443-->CE-->80--Origin Pool --> (Nodeport).  

Step 4: 

## Publish the Service

Create http load balancer:

#### Multicloud App Connect -> Manage -> Load Balancers -> http load balancer

Use the screenshot to configure the load balancer: 

<img width="886" alt="image" src="https://github.com/user-attachments/assets/da37c504-5f87-40ee-8725-1ec4024457c0">


For the WAF policy - Create a new policy called "blocking-policy", put it in blocking mode and take all defaults

<img width="889" alt="image" src="https://github.com/user-attachments/assets/aca0998a-78ce-40e6-b9de-f9981e3189c3">

For everything below the WAF policy, take all the defaults but **_NOTE:_**all of the other layered security features can be added.

Click "Save and Exit" 

Click the "Actions buttons" under load balancer name and go to "Manage Configuration".
<img width="1088" alt="image" src="https://github.com/user-attachments/assets/341f5cd7-29a7-48b0-80a3-21eb77681ee4">

Click the JSON tab and **_NOTE:_** your IP address. 
<img width="874" alt="image" src="https://github.com/user-attachments/assets/6c883512-8225-48b0-8cd3-6f4f02c04e8c">

On your local/test machine create a host file entry pointing nginx.example.com to that IP address and test your access to http://nginx.example.com.

<img width="776" alt="image" src="https://github.com/user-attachments/assets/bcfa83a9-0308-4921-9fa8-3e66924c9d73">

## Verify the WAF
run http://nginx.example.com/<script>

<img width="673" alt="image" src="https://github.com/user-attachments/assets/c6fad06f-be4e-4bd2-8742-b45cb989130f">

## More Info on Traffic Routing in a Kubernetes-Aware Load Balancer:

### Service Resolution:

The CE queries the Kubernetes API to resolve the nginx.default service. The service maps to a set of pod IPs (the backend pods that are part of the nginx deployment).

### Load Balancer Traffic Distribution:

The load balancer points to the CE which sends traffic directly to the nodes where the nginx pods are running. The CE will send traffic directly to the worker nodes that are running the nginx pods.
<br>
The NodePort service type means that each node in the cluster will expose the nginx service on a specific port (e.g., 32174). The CE uses this information to send traffic to the correct port on the correct nodes.

### Direct Node Access:

The CE distributes traffic across all nodes in the cluster that have the nginx pods running. It balances traffic between these nodes based on the IP addresses and the specific NodePort.

## Adding a second service

On the master K8s server, create and run the script found in the utils folder called: k8s-add-2nd-service.sh. This will create a scaled deployment with the   echoserver image. 
<br>
After deploying you will see these services instantly available in XC Console under "Service Discovery".

<img width="1064" alt="image" src="https://github.com/user-attachments/assets/6c721dbe-009a-4a13-8a87-fb3b3b5fd2a5">

You can now configure an origin pool and load balancer to use the new service which could all be automated via the XC API. 

## Other Enhancements

Service Discovery is meant to "discover" objects and not "create" objects for further consumption. Once services are discovered, it is up to the admin to create an origin pool with reference to the discovered services and ultimately a load balancer in front of the origin pool. This could all be part of a CI/CD pipeline. 
colleague
My colleague developed a solution called "originsync" that could enhance any service discovery architecture by automatically creating the origin pools in XC based on the services discovered. Cool stuff! https://github.com/Mikej81/originsynchttps://github.com/Mikej81/originsync


