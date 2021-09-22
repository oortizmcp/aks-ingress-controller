#!/bin/bash
INGRESS_NAME=$1
ACR_URL=$2
NAMESPACE=$3
INGRESS_VALUES_FILE=$4
AKS_HELLO=$5
INGRESS_DEMO=$6
INGRESS_MANIFEST=$7



#REGISTRY_NAME=<yourregistryname>
CONTROLLER_REGISTRY=k8s.gcr.io
CONTROLLER_IMAGE=ingress-nginx
CONTROLLER_TAG=v0.48.1
PATCH_REGISTRY=docker.io
PATCH_IMAGE=jettech/kube-webhook-certgen
PATCH_TAG=v1.5.1
DEFAULTBACKEND_REGISTRY=k8s.gcr.io
DEFAULTBACKEND_IMAGE=defaultbackend-amd64
DEFAULTBACKEND_TAG=1.5


# create namespace if doesn't exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Authenticate with ACR with --expose-token
export HELM_EXPERIMENTAL_OCI=1
TOKEN=$(az acr login --name $ACR_URL --expose-token --output tsv --query accessToken)
echo $TOKEN | helm registry login $ACR_URL --username 00000000-0000-0000-0000-000000000000 --password-stdin

# Pull Helm Chart from Azure Container Registry & extract files
helm pull oci://$ACR_URL/<pathofregistry> --version 3.36.0 --untar

#validate chart is desired version
helm show chart ingress-nginx

# Deploy nginx-ingress chart with helm to AKS Cluster and install ingress controller if doesn't exists
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
-f $INGRESS_VALUES_FILE

# Create aks-helloworld and ingress-demo
kubectl apply -f $AKS_HELLO --namespace $NAMESPACE
kubectl apply -f $INGRESS_DEMO --namespace $NAMESPACE

# Delete validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations nginx-ingress-ingress-nginx-admission

# Deploy manifest to AKS
kubectl apply -f $INGRESS_MANIFEST    
