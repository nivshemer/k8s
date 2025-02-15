#!/bin/bash

set -e  # Exit on errors
set -u  # Treat unset variables as errors
set -o pipefail  # Prevent silent failures in pipelines

export KUBECONFIG=/etc/kubernetes/admin.conf

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

start_port_forward() {
    local service_name="$1"
    local port="$2"
    local screen_name="${service_name}-port-forward"

    if ! screen -list | grep -q "$service_name"; then
        log "Starting port forward for $service_name..."
        screen -dmS "$screen_name" bash -c "kubectl port-forward service/$service_name $port --address=0.0.0.0"
        sleep 1
        screen -S "$screen_name" -X detach
        log "$service_name port forward started."
    else
        log "$service_name port forward is already running."
    fi
}

# Start port-forwarding for necessary services
start_port_forward "nginx" "443"
start_port_forward "postgres" "5432"
start_port_forward "rabbit-mq" "15672"

# Additional RabbitMQ port forward if needed
if ! screen -list | grep -q "rabbitmq-5672"; then
    log "Starting additional RabbitMQ port forward on 5672..."
    screen -dmS "rabbitmq-port-forward-5672" bash -c "kubectl port-forward service/rabbit-mq 5672 --address=0.0.0.0"
    sleep 1
    screen -S "rabbitmq-port-forward-5672" -X detach
    log "RabbitMQ port 5672 forward started."
else
    log "RabbitMQ port 5672 forward is already running."
fi

# Add Elasticsearch users
log "Adding Elasticsearch users..."
ES_POD=$(kubectl get pods -l app=elasticsearch -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [[ -n "$ES_POD" ]]; then
    kubectl exec -it "$ES_POD" -- elasticsearch-users useradd nolucksec -p noluckSec! -r superuser || log "Failed to add user nolucksec"
    kubectl exec -it "$ES_POD" -- elasticsearch-users useradd kibanolucksec -p kibanolucksec -r kibana_system || log "Failed to add user kibanolucksec"
    log "Elasticsearch users added successfully."
else
    log "No Elasticsearch pod found."
fi

# Fix PostgreSQL directory permissions
log "Updating ownership for PostgreSQL archive directory..."
chown -R 70:root $NOLUCK/postgres/archivedir/

# Run PostgreSQL backup script
log "Running PostgreSQL backup..."
PG_POD=$(kubectl get pods -l app=postgres -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [[ -n "$PG_POD" ]]; then
    kubectl exec -it "$PG_POD" -- /etc/postgresql/db_backup.sh || log "PostgreSQL backup script failed."
    log "PostgreSQL backup completed."
else
    log "No PostgreSQL pod found."
fi

log "Script execution completed."
