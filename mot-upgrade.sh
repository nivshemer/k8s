#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
fi

# Clean all zip files from /tmp
rm -f /tmp/*.zip

# Paths
ENV_FILE="$NOLUCK/deployment-scripts/.env"
DEST_DIR="/tmp"

# Create /tmp directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Items to move to /tmp
items=(
    "$(pwd)/utilities"
    "$(pwd)/images-otd"
    "$(pwd)/mot-install.sh"
    "$(pwd)/change-ip"
    "$(pwd)/mot-upgrade.sh"
)

# Move items to /tmp and log actions
for item in "${items[@]}"; do
    if [ -e "$item" ] || [ -d "$item" ]; then
        mv "$item" "$DEST_DIR"
        echo "Moved: $item -> $DEST_DIR"
    else
        echo "Skipped: $item (does not exist)"
    fi
done

# Move zip files to /tmp
zip_files=($(find "$(pwd)" -maxdepth 1 -name "*.zip"))
for zip in "${zip_files[@]}"; do
    mv "$zip" "$DEST_DIR"
    echo "Moved: $zip -> $DEST_DIR"
done

# Unzip noluck services if present
zip_file=($(find "$DEST_DIR" -maxdepth 1 -name "*.zip"))
if [ -f "$zip_file" ]; then
    echo "***** Extracting $zip_file *****"
    unzip "$zip_file" -d "$DEST_DIR"
else
    echo "No $zip_file found in $DEST_DIR"
fi

# Load Docker images if /tmp/images-otd exists
if [ -d "$DEST_DIR/images-otd" ]; then
    for file in "$DEST_DIR/images-otd"/*; do
        docker load -i "$file"
    done
else
    echo "Directory $DEST_DIR/images-otd does not exist."
fi

# Load BUILD_NUMBER from .env file
BUILD_NUMBER=$(head -n 1 "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')

# Check if BUILD_NUMBER is a valid integer
if [[ -n "$BUILD_NUMBER" && "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    if [[ "$BUILD_NUMBER" -le 810 ]]; then
        echo "The build is 810 and below"
        openssl aes-256-cbc -d -a -pbkdf2 -in "$NOLUCK/stores/.sec_enc.env" -out "$NOLUCK/deployment-scripts/.secrets.env" -pass pass:noluckSec!
        pwd_value=$(grep -oP 'Pwd=\K[^;]+' <(head -n 1 "$NOLUCK/deployment-scripts/.secrets.env"))
        first_line=$(head -n 1 "$NOLUCK/deployment-scripts/.secrets.env")
        pwd_admin_value=$(echo "$first_line" | grep -oP 'Pwd=\K[^;]+')        
        cp -vf /tmp/deployment-scripts/.secrets.env $NOLUCK/deployment-scripts
        sed -i -e s/POSTGRES_PW/"$pwd_value"/g "$NOLUCK/deployment-scripts/.secrets.env" || exit 1
        sed -i -e s/ADMIN_PW/"$pwd_admin_value"/g "$NOLUCK/deployment-scripts/.secrets.env" || exit 1
        openssl aes-256-cbc -a -salt -pbkdf2 -in /noluck/deployment-scripts/.secrets.env -out /noluck/stores/.sec_enc.env -pass pass:$nanop
        echo 'nanop=noluckSec!' >> /etc/environment 
    else
        echo "The build is Above 810"
        openssl aes-256-cbc -d -a -pbkdf2 -in "$NOLUCK/stores/.sec_enc.env" -out "$NOLUCK/deployment-scripts/.secrets.env" -pass pass:noluckSec!
    fi
else
    echo "BUILD_NUMBER is not valid: $BUILD_NUMBER"
fi


# Extract the value of API_URL from the .env file
API_URL=$(grep ^API_URL= $NOLUCK/deployment-scripts/.env | cut -d '=' -f2-)
echo "***** Backup configuration files *****"
cp -vf $NOLUCK/deployment-scripts/.env $NOLUCK/deployment-scripts/.env_backup
cp -vf /tmp/deployment-scripts/.env $NOLUCK/deployment-scripts/

# Insert or replace the API_URL value in the .env_new file
if grep -q ^API_URL= $NOLUCK/deployment-scripts/.env; then
    # If API_URL exists, replace it
    sed -i "s|^API_URL=.*|API_URL=${API_URL}|" $NOLUCK/deployment-scripts/.env
else
    # If API_URL does not exist, add it
    echo "API_URL=${API_URL}" >> $NOLUCK/deployment-scripts/.env
fi

sed -i 's|gcr.io/macro-kiln-247514|europe-west1-docker.pkg.dev/macro-kiln-247514/images|g' $NOLUCK/deployment-scripts/docker-compose.yml

OTD_FILE="$NOLUCK/service-configurations/otd.json"

# Check if "FeatureManagement" already exists
if ! grep -q '"FeatureManagement"' "$OTD_FILE"; then
    echo "Adding FeatureManagement section to otd.json..."
    
    # Insert "FeatureManagement" right before the last closing bracket }
    sed -i '$ s/}/,\n    "FeatureManagement": {\n        "ConfigurationIntegrity": false,\n        "ViewerRole": false\n    }\n}/' "$OTD_FILE"
else
    echo "FeatureManagement section already exists in otd.json. Skipping update."
fi


cd $NOLUCK/deployment-scripts
docker-compose up -d || { echo "docker-compose up failed"; exit 1; }
noluck-watch

# Clean secrets
rm -rf "$NOLUCK/deployment-scripts/.secrets.env"

# Clean /tmp directory
echo "Cleaning /tmp directory"
rm -rf "$DEST_DIR"/*


