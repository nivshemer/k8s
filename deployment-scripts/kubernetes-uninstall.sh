#!/bin/bash
function remove-kubernetes-services()
{
	servicename="${1}"
    if [ -f "$servicename" ]; then
        echo "File $servicename exists."
        kubectl delete -f ./$servicename || { echo "$servicename delete failed"; exit 1; }
    else
        echo "File $servicename does not exist."
    fi
}

#remove-kubernetes-services noluck-infra.yaml
#remove-kubernetes-services noluck-services.yaml
kubectl delete -f $NOLUCK/deployment-scripts/noluck-services.yaml
kubectl delete -f $NOLUCK/deployment-scripts/noluck-infra.yaml
kubectl delete -f $NOLUCK/deployment-scripts/configuration.yaml
#kubectl delete namespace default
#kubectl delete pods --all --namespace=default
kubectl delete secrets --all
cd $NOLUCK/grafana
kubectl delete -f manifests/
kubectl delete -f manifests/setup/
#kubectl delete namespace monitoring --force --grace-period=0
#kubectl delete all --all
rm -rfv $NOLUCK
rm -rfv /tmp/*
kubectl delete configmap --all
sudo sed -i '$NOLUCK/d' /etc/hosts




