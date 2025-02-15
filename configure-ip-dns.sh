#!/bin/bash

# Get the current machine's IP address
myip=$(hostname -I | cut -d' ' -f1)

# Prompt for subdomain and domain name
while true; do
    read -p "Please insert your subdomain name and domain name (e.g., otd.nolucksecurity.nl): " input
    
    if [[ -z "$input" ]]; then
        echo "Input cannot be empty. Please try again."
        continue
    fi

    # Extract subdomain and domain parts
    if [[ "$input" =~ ^([^.]+)\.([^.]+\.[^.]+)$ ]]; then
        varaddress="${BASH_REMATCH[1]}"
        vardomain="${BASH_REMATCH[2]}"
        
        echo "Subdomain: $varaddress"
        echo "Domain: $vardomain"
        break
    else
        echo "Invalid format. Please enter a subdomain and domain (e.g., otd.nolucksecurity.nl)."
    fi
done

# Replace "envvar" with the subdomain in multiple configuration files
files=(
    "deployment-scripts/domain-names.env"
    "nginx/nginx.conf"
    "deployment-scripts/service-config.json"
    "deployment-scripts/.env"
    "deployment-scripts/configuration.env"
    "deployment-scripts/noluck-deployment-otd-template.yaml"
    "grafana/grafana.ini"
    "init-secrets.sh"
    "service-configurations/device-key-store.json"
    "service-configurations/otd.json"
    "service-configurations/coredns-cm"
    "02-install-server.sh"
)

for file in "${files[@]}"; do
    sed -i -e "s/envvar/$varaddress/g" "$file" || exit 1
done

# Replace MOT_SITE_VAR and MOT_SITE_ID_VAR in configuration.env
sed -i -e "s/MOT_SITE_VAR/$varaddress/g" "deployment-scripts/configuration.env"
sed -i -e "s/MOT_SITE_ID_VAR/$(uuidgen)/g" "deployment-scripts/configuration.env"

# Append entries to /etc/hosts
sudo -- sh -c -e "echo '$myip  $varaddress-api.$vardomain' >> /etc/hosts"
sudo -- sh -c -e "echo '$myip  $varaddress-gb.$vardomain' >> /etc/hosts"
sudo -- sh -c -e "echo '$myip  $varaddress.$vardomain' >> /etc/hosts"

# Replace "domain" with actual domain in 02-install-server.sh
sed -i -e "s/domain/$vardomain/g" "02-install-server.sh"
