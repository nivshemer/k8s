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

remove-kubernetes-services noluck-infra.yaml
remove-kubernetes-services noluck-services.yaml
kubectl delete all --all
rm -rfv $NOLUCK

sudo sed -i '/noluck/d' /etc/hosts
