#!/bin/bash

REGISTRY_NAME=<yourregistryname>
ACR_URL=<yourregistryname>.azurecr.io
CONTROLLER_REGISTRY=k8s.gcr.io
CONTROLLER_IMAGE=ingress-nginx/controller
CONTROLLER_TAG=v1.0.0
PATCH_REGISTRY=docker.io
PATCH_IMAGE=jettech/kube-webhook-certgen
PATCH_TAG=v1.5.1
DEFAULTBACKEND_REGISTRY=k8s.gcr.io
DEFAULTBACKEND_IMAGE=defaultbackend-amd64
DEFAULTBACKEND_TAG=1.5
NAMESPACE=<yournamespace>
INGRESS_NAME=<youringressname>
AKS_CLUSTER=<yourclustername>
RESOURCE_GROUP=<yourresourcegroup>

kubectl get namespaces
kubectl get services -A
kubectl get pods
az acr repository list --name $REGISTRY_NAME


az acr login -n $REGISTRY_NAME
az acr import --name $REGISTRY_NAME --source $CONTROLLER_REGISTRY/$CONTROLLER_IMAGE:$CONTROLLER_TAG --image $CONTROLLER_IMAGE:$CONTROLLER_TAG
az acr import --name $REGISTRY_NAME --source $PATCH_REGISTRY/$PATCH_IMAGE:$PATCH_TAG --image $PATCH_IMAGE:$PATCH_TAG
az acr import --name $REGISTRY_NAME --source $DEFAULTBACKEND_REGISTRY/$DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG --image $DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG

# Get helm-chart nginx-ingress version 3.36.0
mkdir chart-yaml
https://github.com/kubernetes/ingress-nginx/releases/tag/helm-chart-3.36.0/ingress-nginx-3.36.0.tgz 

tar -xvzf ingress-nginx-3.36.0.tgz
# Go at the Chart level folder and run helm package . it will create .tgz file again



# Authenticate with ACR with --expose-token
export HELM_EXPERIMENTAL_OCI=1
TOKEN=$(az acr login --name $REGISTRY_NAME.azurecr.io --expose-token --output tsv --query accessToken)
echo $TOKEN | helm registry login $REGISTRY_NAME.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password-stdin

helm push ingress-nginx/ingress-nginx-3.36.0.tgz oci://$ACR_URL/helm/ingress/ingress-nginx-3.36.0
helm pull oci://$ACR_URL/helm/ingress/ingress-nginx-3.36.0/ingress-nginx --version 3.36.0 --untar

# Check repositories and validate 
az acr repository list --name $REGISTRY_NAME
az acr repository show --name $REGISTRY_NAME --repository helm/ingress/ingress-nginx-3.36.0/ingress-nginx

# Create namespace
az aks get-credentials -n $AKS_CLUSTER -g $RESOURCE_GROUP --admin
kubectl create namespace ingress-basic

helm upgrade --install $INGRESS_NAME ingress-nginx --version 3.36.0 --namespace $NAMESPACE \
--set controller.replicaCount=2 \
--set controller.nodeSelector."kubernetes\.io/os"=linux \
--set controller.image.registry=$ACR_URL \
--set controller.image.image=$CONTROLLER_IMAGE \
--set controller.image.tag=$CONTROLLER_TAG  \
--set controller.image.digest="" \
--set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
--set controller.admissionWebhooks.patch.image.registry=$ACR_URL \
--set controller.admissionWebhooks.patch.image.digest="" \
--set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
--set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
--set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
--set defaultBackend.image.registry=$ACR_URL \
--set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
--set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
--set defaultBackend.image.digest="" \
-f internal-ingress.yaml

kubectl apply -f aks-helloworld.yaml  --namespace $NAMESPACE
kubectl apply -f ingress-demo.yaml  --namespace $NAMESPACE

kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations <output from previous command>

kubectl apply -f hello-world-ingress.yaml  --namespace $NAMESPACE

# Test and validate
kubectl run -it --rm aks-ingress-test --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11 --namespace $NAMESPACE
apt-get update && apt-get install -y curl
curl -L http://<yourloadbalancerip>
curl -L -k http://<yourloadbalancerip>/hello-world-two