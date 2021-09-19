#!/bin/bash

# Variables
RESOURCE_GROUP=oo-demoresources-rg
VNET_NAME=aks-vnt-cus
REGISTRY_NAME=ooaksacrprivdemo
REGISTRY_LOCATION=centralus
MGMT_SNET=mgmt-snet
AKS_SUBNET=aks-snet

az acr create \
-g $RESOURCE_GROUP \
-n ooaksacrprivdemo \
--location $REGISTRY_LOCATION \
--sku Premium \
--public-network-enabled false

# Set up private endpoint for Registry
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

NETWORK_INTERFACE_ID=$(az network private-endpoint show \
  --name ooaksacr-privend-mgmt \
  --resource-group $RESOURCE_GROUP \
  --query 'networkInterfaces[0].id' \
  --output tsv)

REGISTRY_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIpAddress" \
  --output tsv)

DATA_ENDPOINT_PRIVATE_IP=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$REGISTRY_LOCATION'].privateIpAddress" \
  --output tsv)

# An FQDN is associated with each IP address in the IP configurations

REGISTRY_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateLinkConnectionProperties.fqdns" \
  --output tsv)

DATA_ENDPOINT_FQDN=$(az network nic show \
  --ids $NETWORK_INTERFACE_ID \
  --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$REGISTRY_LOCATION'].privateLinkConnectionProperties.fqdns" \
  --output tsv)

# Create DNS records in the private zone
az network private-dns record-set a create \
  --name $REGISTRY_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $RESOURCE_GROUP

# Specify registry region in data endpoint name
az network private-dns record-set a create \
  --name ${REGISTRY_NAME}.${REGISTRY_LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $RESOURCE_GROUP

  az network private-dns record-set a add-record \
  --record-set-name $REGISTRY_NAME \
  --zone-name privatelink.azurecr.io \
  --resource-group $RESOURCE_GROUP \
  --ipv4-address $REGISTRY_PRIVATE_IP

# Specify registry region in data endpoint name
az network private-dns record-set a add-record \
  --record-set-name ${REGISTRY_NAME}.${REGISTRY_LOCATION}.data \
  --zone-name privatelink.azurecr.io \
  --resource-group $RESOURCE_GROUP \
  --ipv4-address $DATA_ENDPOINT_PRIVATE_IP

dig $REGISTRY_NAME.azurecr.io