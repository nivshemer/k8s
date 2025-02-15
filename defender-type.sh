#!/bin/bash

REPLY=$1

if [ "$REPLY" = "1" ]; then
    echo "Device-Defender"
    if [ -f "service-configurations/management-console.json" ]; then
        sed -i -e 's/MachineDefender/deviceDefender/g' "service-configurations/management-console.json"
    fi
elif [ "$REPLY" = "2" ]; then
    echo "Machine-Defender"
    sed -i -e 's/DeviceDefender/MachineDefender/g' "service-configurations/management-console.json" || exit 1
elif [ "$REPLY" = "3" ]; then
    sed -i -e 's/management-console/mngtclient/g' "nginx/nginx.conf"
fi
