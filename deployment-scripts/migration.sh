#!/bin/bash

# Check and set noluck home directory
if [[ -z "${noluck_HOME}" ]]; then
  export $(cat /etc/.noluck_env | xargs) >> $NOLUCK/log.log 2>&1
fi
if [[ -f ${noluck_HOME}/deployment-scripts/domain-names.env ]]; then
  export $(cat ${noluck_HOME}/deployment-scripts/domain-names.env | xargs)
fi

# Utility functions
print_error() {
  echo "Error: $1" >&2
}

print_warning() {
  echo "Warning: $1" >&2
}

print_info() {
  echo "Info: $1"
}

# Function to validate and read JSON configuration file
read_json() {
  local file=$1
  if [[ -f "$file" ]]; then
    jq empty "$file" || {
      print_error "Invalid JSON format in $file"
      exit 1
    }
    cat "$file" | jq '.' || {
      print_error "Failed to parse JSON file: $file"
      exit 1
    }
  else
    print_error "JSON file not found: $file"
    exit 1
  fi
}

# Function to migrate RabbitMQ
migrate_rabbitmq() {
  local rabbitmq_config="$1"

  if [[ -f "$rabbitmq_config" ]]; then
    local exchanges=$(jq -c '.exchanges[]' "$rabbitmq_config" 2>/dev/null)
    local queues=$(jq -c '.queues[]' "$rabbitmq_config" 2>/dev/null)

    if [[ -z "$exchanges" && -z "$queues" ]]; then
      print_warning "No exchanges or queues found in $rabbitmq_config"
      return
    fi

    for exchange in $exchanges; do
      local name=$(echo "$exchange" | jq -r '.name // empty')
      local type=$(echo "$exchange" | jq -r '.type // "direct"')
      local durable=$(echo "$exchange" | jq -r '.durable // true')

      if [[ -n "$name" ]]; then
        print_info "Processing exchange: $name"
        local url="http://localhost:15672/api/exchanges/%2F/$name"

        # Check existing exchange properties
        local existing=$(curl -u guest:guest -s -H "Content-Type: application/json" -X GET "$url")

        if echo "$existing" | jq -e .name &>/dev/null; then
          local existing_type=$(echo "$existing" | jq -r '.type')
          local existing_durable=$(echo "$existing" | jq -r '.durable')

          if [[ "$existing_type" != "$type" || "$existing_durable" != "$durable" ]]; then
            print_warning "Inequivalent properties for exchange $name. Skipping creation."
          else
            print_info "Exchange $name already exists with matching properties."
          fi
        else
          curl -u guest:guest -H "Content-Type: application/json" -X PUT "$url" -d '{"type":"'$type'","durable":'$durable'}' || {
            print_warning "Failed to create exchange: $name"
          }
        fi
      else
        print_warning "Exchange name missing or invalid in configuration: $exchange"
      fi
    done

    for queue in $queues; do
      local name=$(echo "$queue" | jq -r '.name // empty')
      local durable=$(echo "$queue" | jq -r '.durable // true')
      local bindings=$(echo "$queue" | jq -c '.bindings[] // empty' 2>/dev/null || true)

      if [[ -n "$name" ]]; then
        print_info "Processing queue: $name"
        local url="http://localhost:15672/api/queues/%2F/$name"

        # Check existing queue properties
        local existing=$(curl -u guest:guest -s -H "Content-Type: application/json" -X GET "$url")

        if echo "$existing" | jq -e .name &>/dev/null; then
          local existing_durable=$(echo "$existing" | jq -r '.durable')

          if [[ "$existing_durable" != "$durable" ]]; then
            print_warning "Inequivalent properties for queue $name. Skipping creation."
          else
            print_info "Queue $name already exists with matching properties."
          fi
        else
          curl -u guest:guest -H "Content-Type: application/json" -X PUT "$url" -d '{"durable":'$durable'}' || {
            print_warning "Failed to create queue: $name"
          }
        fi

        for binding in $bindings; do
          local exchange_name=$(echo "$binding" | jq -r '.exchange_name // empty')
          if [[ -n "$exchange_name" ]]; then
            print_info "  Binding queue $name to exchange $exchange_name"
            local binding_url="http://localhost:15672/api/bindings/%2F/e/$exchange_name/q/$name"
            curl -u guest:guest -H "Content-Type: application/json" -X POST "$binding_url" -d '{}' || {
              print_warning "Failed to bind queue $name to exchange $exchange_name"
            }
          else
            print_warning "Binding exchange_name missing or invalid in configuration: $binding"
          fi
        done
      else
        print_warning "Queue name missing or invalid in configuration: $queue"
      fi
    done
  else
    print_error "RabbitMQ configuration file not found: $rabbitmq_config"
  fi
}


# Function to get server configuration
get_server_configuration() {
  local server_name=$SERVER_NAME

  if [[ -z "$server_name" ]]; then
    local config_file="./service-config.json"
    if [[ -f "$config_file" ]]; then
      read_json "$config_file"
    else
      print_error "Server name environment variable is missing, and config file not found!"
      exit 1
    fi
  else
    print_info "Fetching configuration from SSM for server: $server_name"
    # Simulate SSM fetch with AWS CLI or similar
  fi
}

# Main operation
invoke_after_install_operations() {
  print_info "noluck home directory: $NOLUCK"

  configuration=$(get_server_configuration)

  print_info "Updating configurations..."
  # Simulate update configuration logic here

  print_info "Migrating RabbitMQ..."
  migrate_rabbitmq "$NOLUCK/deployment-scripts/rabbit_mq_configuration.json"

  #start_noluck_services
}

# Start script execution
invoke_after_install_operations
