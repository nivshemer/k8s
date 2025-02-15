#!/bin/bash

set -e  # Exit on any error
set -u  # Treat unset variables as an error
set -o pipefail  # Prevent silent failures in pipelines

ACTION=$1
SERVICE_NAME=$2

if [[ -z "$ACTION" || -z "$SERVICE_NAME" ]]; then
    echo "Usage: $0 {start|stop|restart} <service_name>"
    exit 1
fi

case "$ACTION" in
    start)
        echo "Starting $SERVICE_NAME..."
        kubectl scale deployment "$SERVICE_NAME" --replicas=1
        echo "$SERVICE_NAME started successfully."
        ;;
    
    stop)
        echo "Stopping $SERVICE_NAME..."
        kubectl scale deployment "$SERVICE_NAME" --replicas=0
        echo "$SERVICE_NAME stopped successfully."
        ;;
    
    restart)
        echo "Restarting $SERVICE_NAME..."
        kubectl scale deployment "$SERVICE_NAME" --replicas=0
        sleep 2  # Short delay to ensure proper stop
        kubectl scale deployment "$SERVICE_NAME" --replicas=1
        echo "$SERVICE_NAME restarted successfully."
        ;;
    
    *)
        echo "Invalid action: $ACTION"
        echo "Usage: $0 {start|stop|restart} <service_name>"
        exit 1
        ;;
esac
