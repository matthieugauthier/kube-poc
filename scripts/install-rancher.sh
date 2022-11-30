#!/bin/bash

# https://docs.ranchermanager.rancher.io/v2.6/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set ingress.tls.source=rancher \
  --set hostname=$RANCHER_INSTALL_HOSTNAME \
  --set replicas=3 \
  --set bootstrapPassword$=RANCHER_INSTALL_PASSWORD
