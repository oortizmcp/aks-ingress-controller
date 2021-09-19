#!/bin/bash

#Variables
RESOURCE_GROUP=oo-demoresources-rg
REGISTRY_NAME=ooaksacrprivdemo
AKS_CLUSTER=aksdemo-private
AKS_SUBNET=aks-snet

AKS_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP -n $AKS_SUBNET --vnet-name $VNET_NAME --query "id" -o tsv)

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