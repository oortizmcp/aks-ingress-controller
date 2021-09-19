# aks-ingress-controller
How to deploy nginx-ingress controller in a private Azure Kubernetes & Private ACR
Not for production (testing phase)  

# Pre-requisites
1. VNET with 2-3 subnets 
2. Private AKS with RBAC enabled (Attach AKS cluster to registry)
3. Private Azure Container Registry (networking blade should be on Disabled)
4. Linux Jumpbox with Azure CLI, Docker, Helm (v 3.7.0), Kubernetes CLI installed

# Getting Started
A. Create your variables 
 
RESOURCE_GROUP=oo-demoresources-rg
LOCATION=centralus
VNET_NAME=aks-vnt-cus
VM_NAME=dockervm-jb
VM_SUBNET=mgmt-snet
REGISTRY_NAME=ooaksacrprivdemo
REGISTRY_LOCATION=centralus
MGMT_SNET=mgmt-snet
AKS_CLUSTER=aksdemo-private
AKS_SUBNET=aks-snet


az group create --name $RESOURCE_GROUP --location $LOCATION

az network vnet create \
-g $RESOURCE_GROUP \
-n $VNET_NAME \
--address-prefix 10.100.0.0/16 \
--subnet-name $MGMT_SNET \
--subnet-prefixes 10.100.1.0/24 

az network vnet subnet create \
-g $RESOURCE_GROUP \
--vnet-name $VNET_NAME \
-n aks-snet \
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
az account set -s b41216a4-a3f7-4165-b575-c594944d46d1
# Enable Service Endpoint on VM
az network vnet subnet update \
--name $VM_SUBNET \
--vnet-name $VNET_NAME \
-g $RESOURCE_GROUP \
--service-endpoints Microsoft.ContainerRegistry


B. Create Private Azure Container Registry

az acr create \
-g $RESOURCE_GROUP \
-n ooaksacrprivdemo \
--location $LOCATION \
--sku Premium \
--public-network-enabled false

## Set up private endpoint for Registry
C. Set up private endpoint for Registry


az network vnet subnet update \
 --name $MGMT_SNET \
 --vnet-name $VNET_NAME \
 --resource-group $RESOURCE_GROUP \
 --disable-private-endpoint-network-policies

 
# Configure Private DNS Zone
az network private-dns zone create \
  --resource-group $RESOURCE_GROUP \
  --name "privatelink.azurecr.io"

# Create Association link
az network private-dns link vnet create \
  --resource-group $RESOURCE_GROUP \
  --zone-name "privatelink.azurecr.io" \
  --name acrdnslink \
  --virtual-network $VNET_NAME \
  --registration-enabled false

REGISTRY_ID=$(az acr show --name REGISTRY_NAME --query "id" --output tsv)

az network private-endpoint create \
-n ooaksacr-privend-mgmt \
-g $RESOURCE_GROUP \
--vnet-name $VNET_NAME \
--subnet $MGMT_SUBNET \
--private-connection-resource-id "$REGISTRY_ID" \
--group-id registry \
--connection-name ooaksacrprivlinkconn-mgmtsnet



C. Create Private AKS

AKS_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP -n aks-snet --vnet-name $VNET_NAME --query "id" -o tsv)

az aks create \
-g $RESOURCE_GROUP \
-n $AKS_CLUSTER \
--kubernetes-version 1.21.2 \
--node-count 2 \
--node-vm-size Standard_B4ms \
--attach-acr $REGISTRY_NAME \
--enable-rbac \
--outbound-type loadBalancer \
--enable-private-cluster \
--generate-ssh-keys \
--max-pods 30 \
--os-sku Ubuntu \
--network-plugin azure \
--vnet-subnet-id "$AKS_SUBNET_ID" \
--zones 1

# Attach cluster to ACR and check access
az aks update -n $AKS_CLUSTER -g $RESOURCE_GROUP --attach-acr $REGISTRY_NAME
az aks check-acr -n $AKS_CLUSTER -g $RESOURCE_GROUP --acr $REGISTRY_NAME



