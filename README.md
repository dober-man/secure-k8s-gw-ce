# Overview and Goals 
1.  Build and configure a ubuntu server with k8's running simple nginx web server listening on NodePort. 
2.  Configure XC virtual CE for Service Discovery
3.  Publish and secure service to public

## Prerequisite    
#### CPU/RAM/DISK               
XC virtual CE (RHEL) - 8/32/200

Ubuntu K8s (Vanilla Install of Ubuntu 22.04) 4/16/100

XC Console - (You will need owner/admin access to a tenant)
   Permissions Needed: 
   * Perm1
   * Perm2

## Install K8s
ssh into ubuntu-k8s server
Run k8s-install.sh (https://github.com/dober-man/udf-ubuntu-k8s/tree/main)


## Setup K8s for Service Discovery from XC-CE
Run xc-k8s-setup.sh (https://github.com/dober-man/udf-ubuntu-k8s/tree/main)



Run: cat ./kubeconfig
Note – you will most likely need to change the server name to an IP if the CE cannot resolve the server name 

Note - This is highly sensitive data and should be secured as such. 
You will soon paste this output into XC Console Service Discovery as a blindfolded secret. 

XC Console
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


