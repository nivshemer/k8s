#!/bin/bash

set -e  # Exit script on errors
set -u  # Treat unset variables as an error
set -o pipefail  # Fail if any command in a pipeline fails

LOG_PATH="$NOLUCK/log.log"

# Ensure log directory and file exist
mkdir -p "$(dirname "$LOG_PATH")"
touch "$LOG_PATH"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_PATH"
}

# Function to disable swap (Required for Kubernetes)
disable_swap() {
    log "Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
}

# Function to install required dependencies
install_dependencies() {
    log "Installing essential dependencies..."
    sudo apt-get update || { log "Failed to update packages"; exit 1; }
    sudo apt-get install -y python3-pip unzip apt-transport-https ca-certificates curl software-properties-common || { log "Failed to install dependencies"; exit 1; }
}

# Function to install Docker
install_docker() {
    log "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | sudo apt-key add - || { log "Failed to add Docker GPG key"; exit 1; }
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" || { log "Failed to add Docker repository"; exit 1; }
    sudo apt-get update || { log "Failed to update package lists"; exit 1; }
    sudo apt-get install -y docker-ce || { log "Failed to install Docker"; exit 1; }
    sudo systemctl enable docker
    sudo systemctl start docker
    log "Docker installed and started successfully."
}

# Function to install Kubernetes components
install_kubernetes() {
    log "Installing Kubernetes (kubelet, kubeadm, kubectl)..."
    sudo apt-get install -y apt-transport-https curl || { log "Failed to install transport-https and curl"; exit 1; }
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - || { log "Failed to add Kubernetes GPG key"; exit 1; }
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update || { log "Failed to update package lists"; exit 1; }
    sudo apt-get install -y kubelet kubeadm kubectl || { log "Failed to install Kubernetes components"; exit 1; }
    sudo apt-mark hold kubelet kubeadm kubectl  # Prevent auto-updates
    log "Kubernetes components installed successfully."
}

# Function to initialize the Kubernetes cluster
initialize_cluster() {
    log "Initializing Kubernetes cluster..."
    sudo kubeadm init || { log "Failed to initialize Kubernetes cluster"; exit 1; }
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' | sudo tee -a /root/.bashrc /tmp/$USER/.bashrc > /dev/null
    log "Kubernetes cluster initialized successfully."
}

# Function to install Calico Network Plugin
install_calico() {
    log "Installing Calico networking plugin..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml || { log "Failed to apply Calico YAML"; exit 1; }
}

# Function to allow master node scheduling (if needed)
allow_master_scheduling() {
    log "Removing NoSchedule taint from control plane..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- || log "No taint to remove."
}

# Function to install Google Cloud CLI (if script is available)
install_google_cloud() {
    log "Installing Google Cloud CLI..."
    local script_path="./install-google-cloud.sh"
    if [[ -f "$script_path" ]]; then
        chmod +x "$script_path"
        "$script_path" || { log "Failed to install Google Cloud CLI"; exit 1; }
        log "Google Cloud CLI installed successfully."
    else
        log "Warning: install-google-cloud.sh not found. Skipping Google Cloud CLI installation."
    fi
}

# Execute all functions in order
log "Starting Kubernetes setup..."
disable_swap
install_dependencies
install_docker
install_kubernetes
initialize_cluster
install_calico
allow_master_scheduling
install_google_cloud
log "Kubernetes setup completed successfully!"
