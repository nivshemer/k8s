#!/bin/bash
# Function to check if the pod is ready
function is_pod_ready() {
    local app_name="$1"
    if [ -z "$app_name" ]; then
        echo "Error: the variable is an empty string: $app_name"
        return 1
    else
        kubectl get pod "$(kubectl get pods -l app=$app_name -n default | tail -1 | cut -f1 -d' ')" -n default | grep -q "1/1"
    fi
}

check_health() {
  docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null
}


is_slave=0
cd $NOLUCK
chmod +x *.sh
chmod +x $NOLUCK/postgres/*.sh
chmod +x $NOLUCK/kibana/healthcheck.sh
cd $NOLUCK/deployment-scripts/
chmod +x *.sh
echo "*****Adding new jobs to crontab*****" >> $NOLUCK/log.log 2>&1
(crontab -l 2>/dev/null; echo "*/5 * * * * /noluck/deployment-scripts/init-configuration.sh >> /tmp/noluck-init-log.log 2>&1") | crontab -
service cron restart

export $(cat /etc/.noluck_env | xargs)
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /tmp/$USER_NAME/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

source /tmp/$USER_NAME/.bashrc

#sudo service cron status
chmod +x $NOLUCK/kibana/healthcheck.sh

export PGPASSWORD=POSTGRES_PW
# Variables
PG_USER="nolucksec"
PG_HOST="127.0.0.1"
PG_PORT="5432"
LOG_FILE="$NOLUCK/log.log"

# Databases to create
DATABASES=("notifications" "groupsandpolicies" "assets" "devicekeystore")

# Create databases
for DB in "${DATABASES[@]}"; do
  sudo docker exec -e PGPASSWORD="$PGPASSWORD" -it postgres psql \
    -U "$PG_USER" -d postgres -h "$PG_HOST" -p "$PG_PORT" \
    -c "CREATE DATABASE $DB WITH ENCODING 'UTF8';" >> "$LOG_FILE" 2>&1

  if [ $? -ne 0 ]; then
    echo "Error creating database $DB" >> "$LOG_FILE"
  fi
done




cd $NOLUCK/deployment-scripts/
chmod +x *.sh
kubectl create secret docker-registry gcr-secret \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat $NOLUCK\noluck-server.json)" \
  --docker-email=any@email.com

if ping -c 1 8.8.8.8 &> /dev/null; then
    ./kubernetes-dependencies.sh 
else
    echo "no need to run kubernetes-dependencies.sh script, since it's an offline setup"
fi

cd $NOLUCK/service-configurations
kubectl apply -f coredns-cm -n kube-system
kubectl rollout restart -n kube-system deployment/coredns

cd $NOLUCK/deployment-scripts/

print_line_with_string "Install kubernetes secrets"
./create_k8s_confmap_and_secrets.sh #|| { echo "create_k8s_confmap_and_secrets.sh command failed"; exit 0; }
print_line_with_string "Install kubernetes configuration"
./kubernetes-configuration.sh #|| { echo "kubernetes-configuration.sh command failed"; exit 0; }
print_line_with_string "apply noluck-infra"
kubectl apply -f noluck-infra.yaml #|| { echo "apply -f noluck-infra.yaml command failed"; exit 0; }

while ! is_pod_ready "rabbit-mq"; do
    sleep 1
    echo -n "."
done

echo "Usage: checking whether $(kubectl get pods -l app=nginx | tail -1 | cut -f1 -d' ') is up and running"
while ! is_pod_ready "nginx"; do
    sleep 1
    echo -n "."
done


# Poll the status of the pod until it's ready
echo "Usage: checking whether $(kubectl get pods -l app=postgres | tail -1 | cut -f1 -d' ') is up and running"
while ! is_pod_ready "postgres"; do
    sleep 1
    echo -n "."
done

$NOLUCK/grafana/monitoring-deploy.sh

sudo ./migration.sh >> $NOLUCK/log.log 2>&1 || { echo "migration.sh command failed"; exit 1; }
start_noluck_services

kubectl exec -it $(kubectl get pods -l app=rabbit-mq | tail -1 | cut -f1 -d' ') -- rabbitmqctl change_password guest nolucksec

if [[ -z "$ES_POD" ]]; then
    echo "No Elasticsearch pod found" | tee -a "$NOLUCK/log.log"
    exit 1
fi

# Create users inside Elasticsearch container
echo "Adding 'nolucksec' user to Elasticsearch..."
kubectl exec -it "$ES_POD" -- /bin/bash -c "elasticsearch-users useradd nolucksec -p noluckSec! -r superuser" >> "$NOLUCK/log.log" 2>&1 \
    || { echo "Adding 'nolucksec' user to Elasticsearch failed" | tee -a "$NOLUCK/log.log"; exit 1; }

echo "Adding 'kibanolucksec' user to Elasticsearch..."
kubectl exec -it "$ES_POD" -- /bin/bash -c "elasticsearch-users useradd kibanolucksec -p kibanolucksec -r kibana_system" >> "$NOLUCK/log.log" 2>&1 \
    || { echo "Adding 'kibanolucksec' user to Elasticsearch failed" | tee -a "$NOLUCK/log.log"; exit 1; }

echo "Elasticsearch users added successfully."

cd $NOLUCK

chmod +x $NOLUCK/grafana/addViewUser.sh
$NOLUCK/grafana/addViewUser.sh >> $NOLUCK/log.log 2>&1

# Configuration
CONTAINER_NAME="otd-service"  # Replace with your Vault container name
TIMEOUT=15              # Maximum wait time in seconds
LOG_FILE="$NOLUCK/log.log"


# Define the passwords for the FactoryTalk users
factorytalksuper_pw="supervisor_pwd"
factorytalkprog_pw="programmer_pwd"

# Export the variables 
export factorytalksuper_pw
export factorytalkprog_pw

# Stage 1
OTD_POD=$(kubectl get pods -l app=otd-service -o jsonpath="{.items[0].metadata.name}")

if [[ -z "$OTD_POD" ]]; then
    echo "No OTD service pod found." | tee -a "$NOLUCK/log.log"
    exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$NOLUCK/log.log"
}

# Stage 1: Authenticate User
log "Authenticating user..."
kubectl exec -it "$OTD_POD" -- touch AuthenticateUser.txt
kubectl exec -it "$OTD_POD" -- curl -X POST "http://localhost:8070/api/Auth/AuthenticateUser" \
    -H "accept: */*" -H "Nl-Platform: MOT" -H "Content-Type: application/json" \
    -d '{"userName":"admin","password":"AuthenticateUserPassword"}' \
    -c AuthenticateUser.txt -b AuthenticateUser.txt >> "$NOLUCK/log.log" 2>&1 \
    || { log "AuthenticateUser failed"; exit 1; }

# Stage 2: Create Supervisor User
log "Creating FactoryTalk Supervisor user..."
kubectl exec -it "$OTD_POD" -- curl -b AuthenticateUser.txt -X POST \
    "http://localhost:8070/api/ExternalDevices/CreateFactoryTalkUser?userName=noluckSup&password=$factorytalksuper_pw&role=2" \
    -H "accept: */*" -H "Nl-Platform: MOT" -d "" >> "$NOLUCK/log.log" 2>&1 \
    || { log "AuthenticateUser sup failed"; exit 1; }

# Stage 3: Create Programmer User
log "Creating FactoryTalk Programmer user..."
kubectl exec -it "$OTD_POD" -- curl -b AuthenticateUser.txt -X POST \
    "http://localhost:8070/api/ExternalDevices/CreateFactoryTalkUser?userName=noluckProg&password=$factorytalkprog_pw&role=1" \
    -H "accept: */*" -H "Nl-Platform: MOT" -d "" >> "$NOLUCK/log.log" 2>&1 \
    || { log "AuthenticateUser prog failed"; exit 1; }

log "OTD service user setup completed successfully."
# Supervisor
# Nk%Sup$9
# programmer
# Nk%Pro$9

openssl aes-256-cbc -a -salt -pbkdf2 -in $NOLUCK/deployment-scripts/.secrets.env -out $NOLUCK/stores/.sec_enc.env -pass pass:$nanop >> $NOLUCK/log.log 2>&1

openssl aes-256-cbc -a -salt -pbkdf2 -in $NOLUCK/postgres/.postgres.env -out $NOLUCK/stores/.pos_enc.env -pass pass:$nanop >> $NOLUCK/log.log 2>&1

openssl aes-256-cbc -a -salt -pbkdf2 -in $NOLUCK/grafana/.grafana.env -out $NOLUCK/stores/.gra_enc.env -pass pass:$nanop >> $NOLUCK/log.log 2>&1

if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR exists. Cleaning that directory." >> $NOLUCK/log.log 2>&1
    rm -rf $INSTALL_DIR/*
    rm -rf $NOLUCK/01-install-server.sh 
    rm -rf $NOLUCK/02-install-server.sh 
    rm -rf $NOLUCK/03-install-server.sh
    rm -rf $NOLUCK/enable-swap.sh
    rm -rf $NOLUCK/ft1_daily_snapshot.sh
    rm -rf $NOLUCK/defender-type.sh
    rm -rf $NOLUCK/mot-upgrade.sh
    rm -rf $NOLUCK/offline-preparation.sh
    rm -rf $NOLUCK/validate_files.sh
    rm -rf $NOLUCK/online-preparation.sh
    rm -rf $NOLUCK/populate_env.sh
    rm -rf $NOLUCK/update-pw.sh
    rm -rf $NOLUCK/install-google-cloud.sh
    rm -rf $NOLUCK/noluck-server.json
    rm -rf $NOLUCK/configure-ip-dns.sh
    rm -rf $NOLUCK/support.sh
    rm -rf $NOLUCK/autoSnapshot.sh
    rm -rf $NOLUCK/keycloak/.keycloak.env
    rm -rf $NOLUCK/postgres/.postgres.env
    rm -rf $NOLUCK/grafana/.grafana.env
    rm -rf $NOLUCK/deployment-scripts/.secrets.env
    rm -rf $NOLUCK/init-secrets.sh
    rm -rf $NOLUCK/ft1-vm.service
    rm -rf $NOLUCK/grafana/addViewUser.sh
    rm -rf $NOLUCK/deployment-scripts/pg-credentials.yaml
    rm -rf $NOLUCK/deployment-scripts/create_db.sh
    rm -rf $NOLUCK/deployment-scripts/reset_conf_db.sh
    rm -rf $NOLUCK/log*
else
    echo "Error: Directory /tmp does not exist."
fi



noluck-watch 
currentscript="$0"

 # Function that is called when the script exits:
 function finish {
 echo "Securely shredding ${currentscript}"; shred -u ${currentscript};
 }