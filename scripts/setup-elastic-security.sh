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
until curl -s http://localhost:9200 -u elastic:changeme; do
  echo -e "${YELLOW}Elasticsearch is not ready yet, waiting...${NC}"
  sleep 5
done

echo -e "${GREEN}Elasticsearch is ready!${NC}"

# Set the elastic user password from .env
ELASTIC_PASSWORD=$(grep ELASTIC_PASSWORD .env | cut -d= -f2)

# Create Kibana service account token
echo -e "${YELLOW}Creating Kibana service account token...${NC}"

# Delete existing token if it exists
podman exec -it es curl -s -X DELETE \
  -u elastic:${ELASTIC_PASSWORD} \
  http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token

# Create new token
podman exec -it es curl -s -X POST \
  -u elastic:${ELASTIC_PASSWORD} \
  http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token | tee kibana-token-response.json

# Extract the token value
KIBANA_TOKEN_VALUE=$(cat kibana-token-response.json | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -n "$KIBANA_TOKEN_VALUE" ]; then
  echo -e "${GREEN}Kibana service account token created successfully!${NC}"
  
  # Update the .env file with the new token
  sed -i "s|FLEET_SERVER_SERVICE_TOKEN=.*|FLEET_SERVER_SERVICE_TOKEN=${KIBANA_TOKEN_VALUE}|" .env
  echo -e "${GREEN}Updated FLEET_SERVER_SERVICE_TOKEN in .env file${NC}"
else
  echo -e "${RED}Failed to create Kibana service account token!${NC}"
fi

# Create Fleet Server service token if it doesn't exist
echo -e "${YELLOW}Creating Fleet Server service token...${NC}"
podman exec -it es curl -s -X POST \
  -u elastic:${ELASTIC_PASSWORD} \
  http://localhost:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1 | tee fleet-token-response.json

# Extract the token value
FLEET_TOKEN_VALUE=$(cat fleet-token-response.json | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -n "$FLEET_TOKEN_VALUE" ]; then
  echo -e "${GREEN}Fleet Server token created successfully!${NC}"
  echo -e "${GREEN}Fleet Server token: ${FLEET_TOKEN_VALUE}${NC}"
else
  echo -e "${RED}Failed to create Fleet Server token!${NC}"
fi

# Clean up
rm -f fleet-token-response.json kibana-token-response.json

echo -e "${GREEN}Elasticsearch security setup completed!${NC}"
