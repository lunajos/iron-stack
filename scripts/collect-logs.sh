#!/bin/bash

# Script to collect logs from PostgreSQL and Valkey containers and save them to log directories
# for processing by Filebeat

LOG_DIR="/data/Projects/iron-stack/data/logs"
POSTGRES_LOG_DIR="$LOG_DIR/postgres"
VALKEY_LOG_DIR="$LOG_DIR/valkey"

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

# Collect logs from PostgreSQL
collect_logs "postgres" "$POSTGRES_LOG_DIR"

# Collect logs from Valkey
collect_logs "valkey" "$VALKEY_LOG_DIR"

echo "Log collection completed at $(date)"
