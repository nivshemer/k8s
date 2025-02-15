#!/bin/bash
# Add the Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update the package list and install the Cloud SDK
apt update && apt install -y google-cloud-sdk


key_file="noluck-server.json"
gcloud auth activate-service-account --key-file $key_file;
# while true; do
#     read -p "Do you wish to activate service account? " yn
#     case $yn in
#         [Yy]* ) read -p "Key File: " key_file; gcloud auth activate-service-account --key-file $key_file; break;;
#         [Nn]* ) break;;
#         * ) echo "Please answer yes or no.";;
#     esac
# done

#gcloud auth configure-docker

gcloud auth configure-docker europe-west1-docker.pkg.dev

