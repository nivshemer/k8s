#!/bin/bash

# Function to check and replace values in a file
update_file() {
    local file_path=$1
    local search=$2
    local replace=$3

    if [ -f "$file_path" ]; then
        sed -i -e "s/$search/$replace/g" "$file_path"
        echo "Updated $file_path" >> $NOLUCK/log.log 2>&1
    else
        echo "Warning: File $file_path does not exist." >> $NOLUCK/log.log 2>&1
    fi
}

# Main variables
REPLY=$1
REPLY2=$2

if [ "$REPLY" == "MoTAdmin" ]; then
    echo "Updating password for MoTAdmin..."
    update_file "deployment-scripts/.secrets.env" "ADMIN_PW" "$REPLY2"
    update_file "identity-seed/import.sh" "--new-password 123Abc!" "--new-password $REPLY2"
    update_file "03-install-server.sh" "AuthenticateUserPassword" "$REPLY2"

    for template in device_defender_import machine_defender_import ot_defender_import; do
        update_file "identity-seed/Templates/${template}.sh" "--new-password 123Abc!" "--new-password $REPLY2"
    done

    update_file "service-configurations/identity.json" "adminPass" "$REPLY2"

elif [ "$REPLY" == "POSTGRES" ]; then
    echo "Updating password for POSTGRES..."
    update_file "deployment-scripts/pg-credentials.yaml" "POSTGRES_PW" "$REPLY2"
    update_file "replicaState.sh" "POSTGRES_PW" "$REPLY2"
    update_file "03-install-server.sh" "PGPASSWORD=POSTGRES_PW" "PGPASSWORD=$REPLY2"
    update_file "02-install-server.sh" "nanoloksec:POSTGRES_PW" "nanoloksec:$REPLY2"

    update_file "postgres/init.sql" "nolucksec" "$REPLY2"
    update_file "postgres/auditfailedlogin.sql" "password 'nolucksec'" "password '$REPLY2'"
    update_file "netdata/plugins/python/postgres.conf" "password: nolucksec" "password: $REPLY2"
    update_file "postgres/db_backup.sh" "PGPASSWORD=nolucksec" "PGPASSWORD=$REPLY2"
    update_file "postgres/replica_users.sh" "nolucksec" "$REPLY2"
    update_file "replication-setup.sh" "PGPASSWORD=nolucksec" "PGPASSWORD=$REPLY2"

    for config in service-configurations/assets.json service-configurations/device-key-store.json; do
        update_file "$config" "Pwd=nolucksec" "Pwd=$REPLY2"
    done

elif [ "$REPLY" == "factorytalkprog" ]; then
    echo "Updating for factorytalkprog..."
    update_file "03-install-server.sh" "programmer_pwd" "${REPLY2//$/%24}"

elif [ "$REPLY" == "factorytalksuper" ]; then
    echo "Updating for factorytalksuper..."
    update_file "03-install-server.sh" "supervisor_pwd" "${REPLY2//$/%24}"

else
    echo "Error: Unsupported REPLY value $REPLY"
    exit 1
fi

exit 0