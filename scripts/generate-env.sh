#!/bin/bash
# Script to generate a secure .env file for production
# Usage: ./generate-env.sh [output_file]

OUTPUT_FILE=${1:-".env"}
RANDOM_STRING=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

# Generate secure passwords
PG_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
KC_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
GRAFANA_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)

cat > $OUTPUT_FILE << EOL
# Postgres
POSTGRES_VERSION=15
POSTGRES_USER=kc
POSTGRES_PASSWORD=${PG_PASSWORD}
POSTGRES_DB=keycloak

# Keycloak
KEYCLOAK_VERSION=26.0
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=${KC_PASSWORD}
KC_HTTP_PORT=18080

# Valkey
VALKEY_IMAGE=valkey/valkey:latest

# Elasticsearch
ES_VERSION=8.14.3
ES_JAVA_MEM=1g

# Prometheus
PROM_VERSION=2.54.1

# Grafana
GRAFANA_VERSION=11.2.0
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
EOL

echo "Generated secure .env file at $OUTPUT_FILE"
echo "Make sure to keep this file secure and not commit it to version control."
