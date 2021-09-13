#!/bin/bash
ingress_name=$1
acr_url=$2
namespace=$3
ingress_values_file=$4
ingress_manifest_file=$5



#REGISTRY_NAME=<yourregistryname>
#acr_url=$registry_name + '.azurecr.io'
CONTROLLER_REGISTRY=k8s.gcr.io
CONTROLLER_IMAGE=ingress-nginx
CONTROLLER_TAG=v0.48.1
PATCH_REGISTRY=docker.io
PATCH_IMAGE=jettech/kube-webhook-certgen
PATCH_TAG=v1.5.1
DEFAULTBACKEND_REGISTRY=k8s.gcr.io
DEFAULTBACKEND_IMAGE=defaultbackend-amd64
DEFAULTBACKEND_TAG=1.5
#ACR_URL=<yourregistryname>.azurecr.io

# create namespace if doesn't exists
kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

# Install ingress controller if doesn't exists
helm upgrade --install $ingress_name ingress-nginx/ingress-nginx --version 3.36.0 --namespace $namespace \
--set controller.replicaCount=2 \
--set controller.nodeSelector."kubernetes\.io/os"=linux \
--set controller.image.registry=$acr_url \
--set controller.image.image=$CONTROLLER_IMAGE \
--set controller.image.tag=$CONTROLLER_TAG  \
--set controller.image.digest="" \
--set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
--set controller.admissionWebhooks.patch.image.registry=$acr_url \
--set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
--set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
--set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
--set defaultBackend.image.registry=$acr_url \
--set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
--set defaultBackend.image.tag=$DEFAULTBACKEND_TAG -f $ingress_values_file

# Deploy manifest to AKS
kubectl apply -f $ingress_manifest_file    
