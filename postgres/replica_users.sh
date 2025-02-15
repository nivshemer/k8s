#!/bin/sh

sudo -u postgres psql -c "create user nano_replicator with replication encrypted password 'nolucksec'"

