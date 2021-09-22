#!/bin/bash

# Variables
RESOURCE_GROUP=<yourresourcegroup>
LOCATION=centralus
VNET_NAME=<yourvnetname>
VM_NAME=<yourvmname>
VM_SUBNET=<yourvmsubnetname>
AKS_SUBNET=<yourakssubnetname>


az group create --name $RESOURCE_GROUP --location $LOCATION

az network vnet create \
-g $RESOURCE_GROUP \
-n $VNET_NAME \
--address-prefix 10.100.0.0/16 \
--subnet-name $VM_SUBNET \
--subnet-prefix 10.100.1.0/24 

az network vnet subnet create \
-g $RESOURCE_GROUP \
--vnet-name $VNET_NAME \
-n $AKS_SUBNET \
--address-prefixes 10.100.2.0/24 


C. Create your Linux Jump Box in mgmt-snet and install docker, helm, AKS-cli commands
Run the following Commands:
 

 az vm create \
 -g $RESOURCE_GROUP \
 -n $VM_NAME \
 --image Canonical:UbuntuServer:18.04-LTS:latest \
 --admin-username azureuser \
 --vnet-name $VNET_NAME \
 --subnet $VM_SUBNET \
 --generate-ssh-keys

# Get public IP and SSH to install all necessary commands
IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)
ssh azureuser@$IP

# Install Azure CLI
sudo su -
apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Docker
apt install docker.io -y
docker run -it hello-world

# Install Helm latest version
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version

# Install AKS CLI
az aks install-cli

az login 
az account set -s <your subscription> 

# Enable Service Endpoint on VM
az network vnet subnet update \
 --name $MGMT_SNET \
 --vnet-name $VNET_NAME \
 --resource-group $RESOURCE_GROUP \
 --disable-private-endpoint-network-policies
 
az network vnet subnet update \
--name $VM_SUBNET \
--vnet-name $VNET_NAME \
-g $RESOURCE_GROUP \
--service-endpoints Microsoft.ContainerRegistry
