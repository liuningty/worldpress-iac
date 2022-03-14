# worldpress-iac
This demo is using terraform to deploy a two-tier application using WorldPress as frontend and MySQL as backend DB on a local native K8S environment.
Both application and database will use persistent volumes to store data and an isilon simulator will be used to provide persistent NAS file sharing.
For MySQL, the PV and PVC will be created to claim persistent storage from a NFS export which is provisioned by Ansible isilon module.
For WorldPress, the persistent volume will be automatically provisioned by leveraging isilon CSI plugin. 

The whole environment contains a single node native K8S cluster based on CentOS and a sinlge node isilon simulator cluster with Ansible isilon module, isilon CSI plugin and terraform pre-configured.   

