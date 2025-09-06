#!/bin/bash

# Script to set up a scheduled task for log collection and shipping to Elasticsearch

# Path to the log shipping script
LOG_SCRIPT="/data/Projects/iron-stack/scripts/ship-logs-to-elastic.sh"

# Create a cron job to run the log shipping script every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * $LOG_SCRIPT >> /data/Projects/iron-stack/data/logs/cron.log 2>&1") | crontab -

echo "Scheduled log shipping task has been set up to run every 5 minutes."
echo "Logs will be collected from PostgreSQL and Valkey and shipped to Elasticsearch."
echo "Check /data/Projects/iron-stack/data/logs/cron.log for execution logs."
