#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
fi

# Clean all zip files from /tmp
rm -f /tmp/*.zip

# Log file path
log_path="/noluck/log.log"

# Extract the directory path from the log file
log_dir=$(dirname "$log_path")

# Ensure the directory exists
if [ ! -d "$log_dir" ]; then
  echo "Directory $log_dir does not exist. Creating it..."
  mkdir -p "$log_dir"
fi

# Ensure the log file exists
if [ ! -f "$log_path" ]; then
  echo "Log file $log_path does not exist. Creating it..."
  touch "$log_path"
fi

# Run delete-env.sh script if it exists
delete_script="/noluck/delete-env.sh"
if [ -f "$delete_script" ]; then
    echo "Running delete script: $delete_script" >> "$log_path" 2>&1
    bash "$delete_script" >> "$log_path" 2>&1
else
    echo "Delete script not found: $delete_script" >> "$log_path" 2>&1
fi

# Items to be moved to /tmp
items=(
    "$(pwd)/utilities"
    "$(pwd)/images-otd"
    "$(pwd)/mot-install.sh"
    "$(pwd)/change-ip"
    "$(pwd)/mot-upgrade.sh"
)

# Add *.zip files separately
zip_files=($(find "$(pwd)" -maxdepth 1 -name "*.zip"))

# Combine items and zip files into one array
items+=("${zip_files[@]}")

# Destination directory
destination="/tmp"

# Move items to /tmp
for item in "${items[@]}"; do
    if [ -e "$item" ] || [ -d "$item" ]; then
        mv "$item" "$destination" 2>/dev/null
        echo "Moved: $item -> $destination" 
    else
        echo "Skipped: $item (does not exist)" 
    fi
done

zip_files=($(find "$(pwd)" -maxdepth 1 -name "*.zip"))
mv "$zip_files" "$destination" 2>/dev/null

# Install zip/unzip package (offline or online)
offline_zip_package="/tmp/utilities/utils/unzip_6.0-26ubuntu3_amd64.deb"

if [ -f "$offline_zip_package" ]; then
    echo "*****Installing offline zip packages*****" >> "$log_path" 2>&1
    sudo dpkg -i "$offline_zip_package" >> "$log_path" 2>&1
else
    # Check for internet connectivity (ping 8.8.8.8)
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        if ! systemctl is-active --quiet docker; then
            echo "*****Installing online zip packages and Docker service is not running*****"
            sudo apt update -y
            sudo apt upgrade -y
            sudo apt-get update --fix-missing
            sudo apt install -y zip unzip
        else
            echo "Docker service is running. Skipping installation of zip/unzip packages."
        fi
    else
        echo "No internet connection. Unable to install zip/unzip packages."
    fi
fi

# Handle zip files in /tmp
cd /tmp || exit 1
if ls *.zip >/dev/null 2>&1; then
    mv *.zip noluck_services.zip
    unzip -q noluck_services.zip
    chmod +x *.sh
    sudo -E ./01-install-server.sh
else
    echo "No zip files found to process in /tmp" >> "$log_path" 2>&1
fi
