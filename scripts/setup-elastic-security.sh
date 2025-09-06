#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Elasticsearch security...${NC}"

# Wait for Elasticsearch to be ready
echo -e "${YELLOW}Waiting for Elasticsearch to be ready...${NC}"
until curl -s --cacert /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt https://localhost:9200 -u elastic:changeme; do
  echo -e "${YELLOW}Elasticsearch is not ready yet, waiting...${NC}"
  sleep 5
done

echo -e "${GREEN}Elasticsearch is ready!${NC}"

# Set the elastic user password from .env
ELASTIC_PASSWORD=$(grep ELASTIC_PASSWORD .env | cut -d= -f2)

# Create Fleet Server service token if it doesn't exist
echo -e "${YELLOW}Creating Fleet Server service token...${NC}"
podman exec -it es curl -s -X POST \
  --cacert /usr/share/elasticsearch/config/certs/ca.crt \
  -u elastic:${ELASTIC_PASSWORD} \
  -H "Content-Type: application/json" \
  https://localhost:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1 \
  -d '{"name":"fleet-token-1"}' | tee fleet-token-response.json

# Extract the token value
TOKEN_VALUE=$(cat fleet-token-response.json | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN_VALUE" ]; then
  echo -e "${GREEN}Fleet Server token created successfully!${NC}"
  
  # Update the .env file with the new token
  sed -i "s|FLEET_SERVER_SERVICE_TOKEN=.*|FLEET_SERVER_SERVICE_TOKEN=${TOKEN_VALUE}|" .env
  echo -e "${GREEN}Updated FLEET_SERVER_SERVICE_TOKEN in .env file${NC}"
else
  echo -e "${RED}Failed to create Fleet Server token!${NC}"
fi

# Clean up
rm -f fleet-token-response.json

echo -e "${GREEN}Elasticsearch security setup completed!${NC}"
