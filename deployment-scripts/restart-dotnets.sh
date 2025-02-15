#!/bin/bash

SERVICES=( 'assets' 'otd' 'device-key-store' 'notifications')

for service in "${SERVICES[@]}"
do
	./service_restart.sh $service
done
