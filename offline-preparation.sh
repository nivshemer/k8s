#!/bin/bash

set -e  # Exit immediately on errors
set -u  # Treat unset variables as an error
set -o pipefail  # Prevent silent failures in pipelines

LOG_PATH="$NOLUCK/log.log"

# Ensure log directory and file exist
mkdir -p "$(dirname "$LOG_PATH")"
touch "$LOG_PATH"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_PATH"
}

# Function to check if Kubernetes (kubelet) is installed and running
check_k8s() {
    if systemctl is-active --quiet kubelet.service; then
        log "Kubernetes (kubelet) service is running."
    else
        log "Kubernetes (kubelet) service is NOT running or installed."
    fi
}

# Function to remove systemd-timesyncd package
remove_timesyncd() {
    log "Removing systemd-timesyncd package..."
    dpkg --remove systemd-timesyncd || log "Warning: Failed to remove systemd-timesyncd."
}

# Function to install .deb packages from a directory
install_deb_packages() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log "Warning: Directory $dir not found. Skipping..."
        return
    fi

    log "Installing .deb packages from $dir"
    find "$dir" -name "*.deb" -print0 | while IFS= read -r -d '' file; do
        log "Installing: $file"
        dpkg -i "$file" || log "Error installing: $file"
    done
}

# Start execution
log "Starting installation process."

check_k8s
remove_timesyncd
install_deb_packages "utilities/utils"
install_deb_packages "utilities/docker"
install_docker_compose
load_k8s_images

log "Disabling swap and configuring system settings..."
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sysctl -w net.ipv4.ip_forward=1

log "Configuring containerd..."
sed -i '/disabled_plugins \= \[\"cri\"\]/s/^/#/' /etc/containerd/config.toml
systemctl stop containerd

sed -i 's|/usr/bin/containerd|/usr/local/bin/containerd|g' /usr/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl start containerd

# Install Kubernetes dependencies
if [[ -d "k8s-dependencies/deb" ]]; then
    log "Installing Kubernetes dependencies..."
    for file in k8s-dependencies/deb/*.deb; do
        [[ -f "$file" ]] || continue
        log "Installing: $file"
        dpkg -i "$file"
    done
else
    log "Kubernetes dependencies directory does not exist."
fi

# Import Kubernetes images
import_images() {
    local dir="$1"
    local label="$2"

    if [[ -d "$dir" ]]; then
        log "Importing Kubernetes images from $dir..."
        for file in "$dir"/*.tar "$dir"/*.tgz; do
            [[ -f "$file" ]] || continue
            log "Importing: $file"
            ctr -n k8s.io images import "$file"
        done
    else
        log "Directory $label does not exist."
    fi
}

import_images "k8s-dependencies/kube-images" "Kubernetes images"
import_images "k8s-dependencies/infra" "Infrastructure images"
import_images "k8s-dependencies/.net" ".NET images"
import_images "k8s-dependencies/noluck-services" "noluck services images"

log "Marking Kubernetes packages as held..."
sudo apt-mark hold kubelet kubeadm kubectl

log "Updating containerd configuration..."
cat <<EOF | sudo tee /etc/containerd/config.toml > /dev/null
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
EOF

log "Restarting containerd and Docker services..."
systemctl restart containerd
systemctl restart docker

log "Initializing Kubernetes cluster..."
sudo kubeadm init

log "Setting up KUBECONFIG..."
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' | sudo tee -a /root/.bashrc /tmp/$USER/.bashrc > /dev/null
source /tmp/$USER/.bashrc

log "Applying Calico network policy..."
kubectl apply -f ./k8s-dependencies/calico/calico.yaml

log "Removing taint from control-plane node..."
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule-

log "Installation process completed successfully."
