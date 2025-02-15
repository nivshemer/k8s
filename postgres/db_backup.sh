#!/bin/bash

# Temporary directory for backups
backup_dir="/var/lib/postgresql/12/main/archivedir"

# List of databases to dump

databases=("nolucksec" "assets" "keycloak" "postgres" "notifications")
export PGPASSWORD=$POSTGRES_PASSWORD;

# Loop through each database and perform the dump
for db in "${databases[@]}"; do
    if psql -h 0.0.0.0 -U nolucksec -lqt | cut -d \| -f 1 | grep -qw "$db"; then
        dump_file="$backup_dir/$db-$(date +%d-%m-%y).tar.gz"
        #export PGPASSWORD=nolucksec; 
	pg_dump -Ft "$db" -U nolucksec -h 0.0.0.0 | gzip > "$dump_file"
        echo "Dumped $db to $dump_file"
    else
        echo "Database $db does not exist. Skipping..."
    fi
done

# Clean up old files in the temporary directory
find "$backup_dir" -mtime +14 -type f -delete
echo "Old files cleaned up in $backup_dir"



