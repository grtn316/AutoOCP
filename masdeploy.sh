#!/bin/bash

USERNAME="admin"
PASSWORD=$(openssl rand -base64 32)
ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

#oc apply -f ../machinesets/db2.yaml
#oc apply -f ../machinesets/ocs.yaml

# Set up Azure Files
#oc apply -f ../storageclasses/azurefiles.yaml

# Set up cert manager

oc create namespace cert-manager
oc apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

# Install catalogs
oc apply -f ../operatorcatalogs/

# Set up all the operators
oc apply -f ../servicebinding/service-binding-operator.yaml
# Wait
sleep 10
installplan=$(oc get installplan -n openshift-operators | grep -i service-binding-operator.v0.8.0 | awk '{print $1}'); echo "installplan: $installplan"
oc patch installplan ${installplan} -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'

oc apply -f ../ocs/ocs-operator.yaml

oc create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp --docker-password=$ENTITLEMENT_KEY -n ibm-sls

oc apply -f ../sls/sls-operator.yaml
oc apply -f ../bas/bas-operator.yaml
oc apply -f ../mas/mas-operator.yaml
oc apply -f ../strimzi/strimzi-operator.yaml

oc create secret generic database-credentials --from-literal=db_username=${USERNAME} --from-literal=db_password=${PASSWORD} -n ibm-bas
oc create secret generic grafana-credentials --from-literal=grafana_username=${USERNAME} --from-literal=grafana_password=${PASSWORD} -n ibm-bas

oc create secret generic sls-mongo-credentials --from-literal=username=admin --from-literal=password=${PASSWORD} -n ibm-sls

echo "Taking a nap for the operators to come online..."

sleep 3m

### Basics done .. wait a bit

# Deploying


oc apply -f ../bas/bas-service.yaml
oc apply -f ../sls/sls-service.yaml
oc apply -f ../mas/mas-service.yaml


### Wait after services came up

sleep 3m

oc apply -f ../bas/bas-api-key.yaml

### Info dump:

echo "================ BAS ================"
#openssl s_client -servername bas-endpoint-ibm-bas.${CLUSTER_URL} -connect bas-endpoint-ibm-bas.${CLUSTER_URL}:443 -showcerts