#!/bin/bash

# Function to create a folder if it doesn't exist
create_folder_if_not_exists() {
    local folder_path="$1"
    if [ ! -d "$folder_path" ]; then
        mkdir -p "$folder_path"
        echo "Folder created: $folder_path" >> $NOLUCK/log.log 2>&1
    fi
}

echo "noluck home: $NOLUCK" >> $NOLUCK/log.log 2>&1

# Add user to the Docker group
echo "Adding user $1 to Docker group."
usermod -aG docker "$1"

# Extract and copy necessary files
unzip -b -o /tmp/noluck_services.zip -d "$NOLUCK"
sudo cp -r /tmp/{deployment-scripts,service-configurations,nginx,postgres,grafana} "$NOLUCK"
sudo cp /tmp/{replication-setup.sh,02-install-server.sh,01-install-server.sh,replicaState.sh,init-secrets.sh,check_master_alive.sh,switch-master-slave.sh} "$NOLUCK"
sudo cp /tmp/support/help.component.html "$NOLUCK/support"

# Create required directories
create_folder_if_not_exists "$NOLUCK/postgres/archivedir"
create_folder_if_not_exists "$NOLUCK/grafana/plugins"
create_folder_if_not_exists "$NOLUCK/grafana/data"
create_folder_if_not_exists "$NOLUCK/prometheus"
create_folder_if_not_exists "$NOLUCK/prometheus/data"
create_folder_if_not_exists "$NOLUCK/assets/failsafe"
create_folder_if_not_exists "$NOLUCK/rabbit-mq/logs"

# Set ownership and permissions
chown -R "$1" "$NOLUCK"
chmod 777 "$NOLUCK/rabbit-mq/logs"
sudo chown -R "$1:$1" "$NOLUCK"/{grafana,prometheus,assets/failsafe}
chmod -R 777 "$NOLUCK"/{vault,grafana,prometheus,assets/failsafe}

# Configure NGINX certificates
chmod +x "$NOLUCK/nginx/"*.sh
"$NOLUCK/nginx/self_sign.sh" "domain"


# Copy and remove PostgreSQL initialization files
kubectl cp "$NOLUCK/postgres/auditfailedlogin.sql" postgres-pod:/etc/postgresql/auditfailedlogin.sql -n default
kubectl cp "$NOLUCK/postgres/init.sql" postgres-pod:/docker-entrypoint-initdb.d/init.sql -n default
rm -rf "$NOLUCK/postgres/"{init.sql,auditfailedlogin.sql,replica_users.sh}

# Wait for RabbitMQ to be accessible
until wget -O - --spider http://localhost:15672 >> $NOLUCK/log.log 2>&1; do
    echo "Waiting for RabbitMQ..."
    sleep 1
done

# Configure RabbitMQ users and permissions
NAMESPACE="default"  # Change this if RabbitMQ is in a different namespace
RABBITMQ_POD=$(kubectl get pods -n $NAMESPACE -l app=rabbitmq -o jsonpath="{.items[0].metadata.name}")

if [ -z "$RABBITMQ_POD" ]; then
  echo "❌ RabbitMQ pod not found in namespace $NAMESPACE"
  exit 1
fi

echo "🔍 Found RabbitMQ pod: $RABBITMQ_POD"

echo "🚀 Enabling MQTT plugin..."
kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmq-plugins enable --offline rabbitmq_mqtt

echo "🔑 Creating RabbitMQ users and setting permissions..."
kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmqctl add_user nolucksec nolucksec
kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmqctl set_user_tags nolucksec administrator management
kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmqctl set_permissions -p / nolucksec ".*" ".*" ".*"

kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmqctl add_user device "O5rk#2M&Es59Av"
kubectl exec -n $NAMESPACE $RABBITMQ_POD -- rabbitmqctl set_permissions -p / device "^mqtt-subscription-device-.*" "^(amq\\.topic)|(mqtt-subscription-device-.*)$" "^(amq\\.topic)|(mqtt-subscription-device-.*)$"

echo "✅ RabbitMQ configuration completed!"

# Configure Docker logging
echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"7"}}' > /etc/docker/daemon.json
