#!/bin/bash

# Script to collect logs from PostgreSQL and Valkey containers and ship them directly to Elasticsearch
# This avoids the need for a separate Filebeat container

LOG_DIR="/data/Projects/iron-stack/data/logs"
POSTGRES_LOG_DIR="$LOG_DIR/postgres"
VALKEY_LOG_DIR="$LOG_DIR/valkey"
ES_HOST="http://localhost:9200"
INDEX_PREFIX="logs"

# Ensure log directories exist
mkdir -p "$POSTGRES_LOG_DIR"
mkdir -p "$VALKEY_LOG_DIR"

# Function to collect logs from a container
collect_logs() {
  local container=$1
  local log_dir=$2
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local log_file="$log_dir/$container-$timestamp.log"
  
  echo "Collecting logs from $container to $log_file"
  podman logs $container > "$log_file"
  
  # Keep only the last 10 log files to prevent disk space issues
  ls -t "$log_dir"/*.log | tail -n +11 | xargs -r rm
}

# Function to ship logs to Elasticsearch
ship_logs() {
  local service=$1
  local log_dir=$2
  local today=$(date +"%Y.%m.%d")
  local index="${INDEX_PREFIX}-${service}-${today}"
  
  # Create index if it doesn't exist
  curl -s -X PUT "$ES_HOST/$index" -H 'Content-Type: application/json' -d '{
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "timestamp": { "type": "date" },
        "service": { "type": "keyword" },
        "message": { "type": "text" }
      }
    }
  }' > /dev/null
  
  # Process each log file
  for log_file in "$log_dir"/*.log; do
    if [ -f "$log_file" ]; then
      echo "Shipping $log_file to Elasticsearch"
      
      # Process each line and send to Elasticsearch
      while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Create JSON document
        json_doc=$(cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "service": "$service",
  "message": $(echo "$line" | jq -R .)
}
EOF
)
        
        # Index document
        curl -s -X POST "$ES_HOST/$index/_doc" \
          -H 'Content-Type: application/json' \
          -d "$json_doc" > /dev/null
      done < "$log_file"
    fi
  done
}

# Collect logs
collect_logs "postgres" "$POSTGRES_LOG_DIR"
collect_logs "valkey" "$VALKEY_LOG_DIR"

# Ship logs to Elasticsearch
ship_logs "postgres" "$POSTGRES_LOG_DIR"
ship_logs "valkey" "$VALKEY_LOG_DIR"

echo "Log collection and shipping completed at $(date)"
