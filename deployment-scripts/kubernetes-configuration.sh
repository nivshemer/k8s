#!/bin/bash
set -e
# Environment for preventing path substitution on windows.
MSYS_NO_PATHCONV=1
SOURCE_TEMPLATE=$1
if [ ! "${SOURCE_TEMPLATE}" ]; then
  SOURCE_TEMPLATE=noluck-deployment-otd-template.yaml
fi
SOURCE_TEMPLATE_INFRA=$3
if [ ! "${SOURCE_TEMPLATE_INFRA}" ]; then
  SOURCE_TEMPLATE_INFRA=noluck-infra-deployment-template.yaml
fi
SOURCE_MIGRATE=$5
if [ ! "${SOURCE_MIGRATE}" ]; then
  SOURCE_MIGRATE=configuration-template.yaml
fi
TARGET=$2
if [ ! "${TARGET}" ]; then
  TARGET=noluck-services.yaml
fi
TARGET_INFRA=$4
if [ ! "${TARGET_INFRA}" ]; then
  TARGET_INFRA=noluck-infra.yaml
fi
TARGET_MIGRATE=$6
if [ ! "${TARGET_MIGRATE}" ]; then
  TARGET_MIGRATE=configuration.yaml
fi
if [[ -f variables.env ]]; then
    set -a
    . ./variables.env
    set +a
fi
if [ ! "${APP_SERVER}" ]; then
  read -p "APP_SERVER: " temp
  export APP_SERVER=${temp}
fi

if [ ! "${AUTH_SERVER}" ]; then
  read -p "AUTH_SERVER: " temp
  export AUTH_SERVER=${temp}
fi

if [ ! "${AUTH_SERVER_API}" ]; then
  read -p "AUTH_SERVER_API: " temp
  export AUTH_SERVER_API=${temp}
fi

if [ ! "${AUTH_SERVER_ADMIN}" ]; then
  read -p "AUTH_SERVER_ADMIN: " temp
  export AUTH_SERVER_ADMIN=${temp}
fi

if [ ! "${noluck_API}" ]; then
  read -p "noluck_API: " temp
  export noluck_API=${temp}
fi

if [ ! "${noluck_CLIENTMONITORING}" ]; then
  read -p "noluck_CLIENTMONITORING: " temp
  export noluck_CLIENTMONITORING=${temp}
fi

if [ ! "${noluck_SERVERMONITORING}" ]; then
  read -p "noluck_SERVERMONITORING: " temp
  export noluck_SERVERMONITORING=${temp}
fi

if [ ! "${noluck_MNGTCLIENT}" ]; then
  read -p "noluck_MNGTCLIENT: " temp
  export noluck_MNGTCLIENT=${temp}
fi

if [ ! "${CONFIGURATION_SERVICE_URL}" ]; then
  read -p "CONFIGURATION_SERVICE_URL: " temp
  export CONFIGURATION_SERVICE_URL=${temp}
fi

if [ ! "${AUTH_CLIENT_ID}" ]; then
  read -p "AUTH_CLIENT_ID: " temp
  export AUTH_CLIENT_ID=${temp}
fi

if [ ! "${AUTH_CLIENT_SECRET}" ]; then
  read -p "AUTH_CLIENT_SECRET: " temp
  export AUTH_CLIENT_SECRET=${temp}
fi

if [ ! "${AUTH_CONFIG_SCOPE}" ]; then
  read -p "AUTH_CONFIG_SCOPE: " temp
  export AUTH_CONFIG_SCOPE=${temp}
fi

if [ ! "${MOT_SITE}" ]; then
  read -p "MOT_SITE: " temp
  export MOT_SITE=${temp}
fi

if [ ! "${MOT_SITE_ID}" ]; then
  read -p "MOT_SITE_ID: " temp
  export MOT_SITE_ID=${temp}
fi

if [ ! "${STORAGE_TAG}" ]; then
  read -p "STORAGE_TAG: " temp
  export STORAGE_TAG=${temp}
fi

if [ ! "${DEVICE_KEY_STORE_TAG}" ]; then
  read -p "DEVICE_KEY_STORE_TAG: " temp
  export DEVICE_KEY_STORE_TAG=${temp}
fi

if [ ! "${ALERTS_TAG}" ]; then
  read -p "ALERTS_TAG: " temp
  export ALERTS_TAG=${temp}
fi

if [ ! "${OTA_TAG}" ]; then
  read -p "OTA_TAG: " temp
  export OTA_TAG=${temp}
fi

if [ ! "${IDENTITY_TAG}" ]; then
  read -p "IDENTITY_TAG: " temp
  export IDENTITY_TAG=${temp}
fi

if [ ! "${DEVICE_TAG}" ]; then
  read -p "DEVICE_TAG: " temp
  export DEVICE_TAG=${temp}
fi

if [ ! "${MANAGEMENT_CONSOLE_TAG}" ]; then
  read -p "MANAGEMENT_CONSOLE_TAG: " temp
  export MANAGEMENT_CONSOLE_TAG=${temp}
fi

if [ ! "${DEVICE_AUTHENTICATION_TAG}" ]; then
  read -p "DEVICE_AUTHENTICATION_TAG: " temp
  export DEVICE_AUTHENTICATION_TAG=${temp}
fi

if [ ! "${CONFIGURATION_TAG}" ]; then
  read -p "CONFIGURATION_TAG: " temp
  export CONFIGURATION_TAG=${temp}
fi

if [ ! "${GUID_GENERATION_TAG}" ]; then
  read -p "GUID_GENERATION_TAG: " temp
  export GUID_GENERATION_TAG=${temp}
fi


if [ ! "${BUILD_TAG}" ]; then
  read -p "BUILD_TAG: " temp
  export BUILD_TAG=${temp}
fi


if [ ! "${MANAGEMENT_API_TAG}" ]; then
  read -p "MANAGEMENT_API_TAG: " temp
  export MANAGEMENT_API_TAG=${temp}
fi

if [ ! "${DATA_READY_PROCESSOR_TAG}" ]; then
  read -p "DATA_READY_PROCESSOR_TAG: " temp
  export DATA_READY_PROCESSOR_TAG=${temp}
fi

if [ ! "${ASSETS_TAG}" ]; then
  read -p "ASSETS_TAG: " temp
  export ASSETS_TAG=${temp}
fi

if [ ! "${NOTIFICATIONS_TAG}" ]; then
  read -p "NOTIFICATIONS_TAG: " temp
  export NOTIFICATIONS_TAG=${temp}
fi

if [ ! "${MNGT_TAG}" ]; then
  read -p "MNGT_TAG: " temp
  export MNGT_TAG=${temp}
fi

if [ ! "${API_URL}" ]; then
  read -p "API_URL: " temp
  export API_URL=${temp}
fi

if [ ! "${AUTHORITY_URL}" ]; then
  read -p "AUTHORITY_URL: " temp
  export AUTHORITY_URL=${temp}
fi

if [ ! "${MACHINE_DEFENDER_TAG}" ]; then
  read -p "MACHINE_DEFENDER_TAG: " temp
  export MACHINE_DEFENDER_TAG=${temp}
fi

if [ ! "${NGINX_TAG}" ]; then
  read -p "NGINX_TAG: " temp
  export NGINX_TAG=${temp}
fi

if [ ! "${ELASTIC_TAG}" ]; then
  read -p "ELASTIC_TAG: " temp
  export ELASTIC_TAG=${temp}
fi

if [ ! "${KEYCLOAK_TAG}" ]; then
  read -p "KEYCLOAK_TAG: " temp
  export KEYCLOAK_TAG=${temp}
fi


if [ ! "${noluck_HOME}" ]; then
  read -p "noluck_HOME: " temp
  export noluck_HOME=${temp}
fi

if [ ! "${noluck_HOME}" ]; then
  read -p "noluck_HOME: " temp
  export noluck_HOME=${temp}
fi

if [ ! "${ENV_VAR}" ]; then
  read -p "ENV_VAR: " temp
  export ENV_VAR=${temp}
fi




envsubst '${APP_SERVER} ${AUTH_SERVER} ${ENV_VAR} ${AUTH_SERVER_API} ${noluck_HOME}\
   ${AUTH_SERVER_ADMIN} ${noluck_API} ${noluck_CLIENTMONITORING}\
   ${noluck_SERVERMONITORING} ${noluck_MNGTCLIENT} ${CONFIGURATION_SERVICE_URL}\
   ${AUTH_CLIENT_ID} ${AUTH_CLIENT_SECRET} ${AUTH_CONFIG_SCOPE}\
   ${MOT_SITE} ${MOT_SITE_ID} ${NOTIFICATIONS_TAG}\
   ${STORAGE_TAG} ${DEVICE_KEY_STORE_TAG} ${ALERTS_TAG}\
   ${OTA_TAG} ${IDENTITY_TAG} ${AUTHORITY_URL} ${BUILD_TAG}\
   ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${CONFIGURATION_TAG} ${GUID_GENERATION_TAG} ${OTA_BASE_URL} ${ASSETS_CONNECTIONSTRING}\
   ${SERVICES_DOMAIN} ${ELASTIC_SEARCH_URL} ${STORAGE_TAG} {$DEVICE_KEY_STORE_TAG}\
   ${ALERTS_TAG} ${OTA_TAG} ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${GUID_GENERATION_TAG} ${MANAGEMENT_API_TAG} ${DATA_READY_PROCESSOR_TAG} ${ASSETS_TAG}\
   ${MNGT_TAG} ${API_URL} ${MACHINE_DEFENDER_TAG}'\
      < $SOURCE_TEMPLATE > $TARGET 
	  
envsubst '${APP_SERVER} ${AUTH_SERVER} ${AUTH_SERVER_API} ${noluck_HOME}\
   ${AUTH_SERVER_ADMIN} ${noluck_API} ${noluck_CLIENTMONITORING}\
   ${noluck_SERVERMONITORING} ${noluck_MNGTCLIENT} ${CONFIGURATION_SERVICE_URL}\
   ${AUTH_CLIENT_ID} ${AUTH_CLIENT_SECRET} ${AUTH_CONFIG_SCOPE}\
   ${MOT_SITE} ${MOT_SITE_ID} ${NOTIFICATIONS_TAG}\
   ${NGINX_TAG} ${KEYCLOAK_TAG} ${ELASTIC_TAG}\
   ${STORAGE_TAG} ${DEVICE_KEY_STORE_TAG} ${ALERTS_TAG}\
   ${OTA_TAG} ${IDENTITY_TAG} ${AUTHORITY_URL} ${BUILD_TAG}\
   ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${CONFIGURATION_TAG} ${GUID_GENERATION_TAG} ${OTA_BASE_URL} ${ASSETS_CONNECTIONSTRING}\
   ${SERVICES_DOMAIN} ${ELASTIC_SEARCH_URL} ${STORAGE_TAG} {$DEVICE_KEY_STORE_TAG}\
   ${ALERTS_TAG} ${OTA_TAG} ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${GUID_GENERATION_TAG} ${MANAGEMENT_API_TAG} ${DATA_READY_PROCESSOR_TAG} ${ASSETS_TAG}\
   ${MNGT_TAG} ${API_URL} ${MACHINE_DEFENDER_TAG}'\
      < $SOURCE_TEMPLATE_INFRA > $TARGET_INFRA 


envsubst '${APP_SERVER} ${AUTH_SERVER} ${AUTH_SERVER_API} ${noluck_HOME}\
   ${AUTH_SERVER_ADMIN} ${noluck_API} ${noluck_CLIENTMONITORING}\
   ${noluck_SERVERMONITORING} ${noluck_MNGTCLIENT} ${CONFIGURATION_SERVICE_URL}\
   ${AUTH_CLIENT_ID} ${AUTH_CLIENT_SECRET} ${AUTH_CONFIG_SCOPE}\
   ${MOT_SITE} ${MOT_SITE_ID} ${NOTIFICATIONS_TAG}\
   ${NGINX_TAG} ${KEYCLOAK_TAG} ${ELASTIC_TAG}\
   ${STORAGE_TAG} ${DEVICE_KEY_STORE_TAG} ${ALERTS_TAG}\
   ${OTA_TAG} ${IDENTITY_TAG} ${AUTHORITY_URL} ${BUILD_TAG}\
   ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${CONFIGURATION_TAG} ${GUID_GENERATION_TAG} ${OTA_BASE_URL} ${ASSETS_CONNECTIONSTRING}\
   ${SERVICES_DOMAIN} ${ELASTIC_SEARCH_URL} ${STORAGE_TAG} {$DEVICE_KEY_STORE_TAG}\
   ${ALERTS_TAG} ${OTA_TAG} ${DEVICE_TAG} ${MANAGEMENT_CONSOLE_TAG} ${DEVICE_AUTHENTICATION_TAG}\
   ${GUID_GENERATION_TAG} ${MANAGEMENT_API_TAG} ${DATA_READY_PROCESSOR_TAG} ${ASSETS_TAG}\
   ${MNGT_TAG} ${API_URL} ${MACHINE_DEFENDER_TAG}'\
      < $SOURCE_MIGRATE > $TARGET_MIGRATE 