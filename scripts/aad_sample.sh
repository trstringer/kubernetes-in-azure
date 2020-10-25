#!/bin/bash

NAME=k8saad
az group create -l eastus -n "$NAME"
az aks create \
    -g "$NAME" -n "$NAME" \
    --node-count 1 --node-vm-size "Standard_B2s" \
    --load-balancer-sku basic \
    --enable-aad --enable-azure-rbac
az role assignment create \
    --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --assignee $(az ad user show \
        --id admin@trstringermsftoutlookcom.onmicrosoft.com \
        --query objectId -o tsv) \
    --scope $(az aks show -g "$NAME" -n "$NAME" --query id -o tsv)

az aks get-credentials -g "$NAME" -n "$NAME" --overwrite-existing

APP_NAMESPACE="testapp"
kubectl create ns "$APP_NAMESPACE"

APP_ADMIN_GROUP="TestAppAdmins"
az ad group create \
    --mail-nickname "$APP_ADMIN_GROUP" \
    --display-name "$APP_ADMIN_GROUP"

az role assignment create \
    --role "Azure Kubernetes Service RBAC Writer" \
    --assignee $(az ad group show \
        --group "$APP_ADMIN_GROUP" \
        --query objectId -o tsv) \
    --scope "$(az aks show -g "$NAME" -n "$NAME" --query id -o tsv)/namespaces/${APP_NAMESPACE}"

APP_ADMIN_NAME="App Admin 1"
APP_ADMIN_UPN="appadmin1@trstringermsftoutlookcom.onmicrosoft.com"
read -p "App admin password: " APP_ADMIN_PASSWORD
az ad user create \
    --display-name "$APP_ADMIN_NAME" \
    --user-principal-name "$APP_ADMIN_UPN" \
    --password "$APP_ADMIN_PASSWORD"

az ad group member add \
    --group "$APP_ADMIN_GROUP" \
    --member-id $(az ad user show \
        --id "$APP_ADMIN_UPN" \
        --query objectId -o tsv)

az role assignment create \
    --role "Azure Kubernetes Service Cluster User Role" \
    --assignee $(az ad group show \
        --group "$APP_ADMIN_GROUP" \
        --query objectId -o tsv) \
    --scope "$(az aks show -g "$NAME" -n "$NAME" --query id -o tsv)"

# 1. Login as the new user.
# 2. Run `az aks get-credentials`.
# 3. Show you can retrieve only from testapp namespace:
#      $ kubectl get po -n testapp
#      No resources found in testapp namespace.
#      $ kubectl get po -n default
#      Error from server (Forbidden): pods is forbidden: User "appadmin1@trstringermsftoutlookcom.onmicrosoft.com" cannot list resource "pods" in API group "" in the namespace "default": User does not have access to the resource in Azure. Update role assignment to allow access.
