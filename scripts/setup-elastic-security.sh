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

# Function to check if Elasticsearch is ready
check_es_ready() {
  local status_code=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:changeme http://localhost:9200)
  if [[ $status_code == "200" ]]; then
    return 0
  else
    # Try through container
    local container_status=$(podman exec -it es curl -s -o /dev/null -w "%{http_code}" -u elastic:changeme http://localhost:9200 2>/dev/null || echo "000")
    if [[ $container_status == "200" ]]; then
      return 0
    fi
  fi
  return 1
}

# Wait for Elasticsearch to be ready
while ! check_es_ready; do
  echo -e "${YELLOW}Elasticsearch is not ready yet, waiting...${NC}"
  sleep 5
done

echo -e "${GREEN}Elasticsearch is ready!${NC}"

# Set the elastic user password from .env
ELASTIC_PASSWORD=$(grep ELASTIC_PASSWORD .env | cut -d= -f2)

# Create Kibana service account token
echo -e "${YELLOW}Creating Kibana service account token...${NC}"

# Function to run a command either directly or through the container
run_es_command() {
  local command=$1
  local result
  
  # Try direct access first
  local status_code=$(curl -s -o /dev/null -w "%{http_code}" -u elastic:changeme http://localhost:9200)
  if [[ $status_code == "200" ]]; then
    result=$(eval "$command")
    echo "$result"
    return 0
  fi
  
  # Try through container if direct access fails
  command="${command/curl/podman exec -it es curl}"
  result=$(eval "$command")
  echo "$result"
  return 0
}

# Delete existing token if it exists
echo -e "${YELLOW}Deleting existing Kibana token if it exists...${NC}"
run_es_command "curl -s -X DELETE -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token"

# Create new token
echo -e "${YELLOW}Creating new Kibana token...${NC}"
TOKEN_RESPONSE=$(run_es_command "curl -s -X POST -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token")
echo "$TOKEN_RESPONSE" > kibana-token-response.json

# Check if token creation was successful
if echo "$TOKEN_RESPONSE" | grep -q "created.*true"; then
  echo -e "${GREEN}Kibana token created successfully!${NC}"
else
  echo -e "${RED}Failed to create Kibana token. Response: $TOKEN_RESPONSE${NC}"
  exit 1
fi

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

# Delete existing token if it exists
run_es_command "curl -s -X DELETE -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1" > /dev/null

# Create new token
FLEET_RESPONSE=$(run_es_command "curl -s -X POST -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_security/service/elastic/fleet-server/credential/token/fleet-token-1")
echo "$FLEET_RESPONSE" > fleet-token-response.json

# Extract the token value
FLEET_TOKEN_VALUE=$(cat fleet-token-response.json | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

if [ -n "$FLEET_TOKEN_VALUE" ]; then
  echo -e "${GREEN}Fleet Server token created successfully!${NC}"
  echo -e "${GREEN}Fleet Server token: ${FLEET_TOKEN_VALUE}${NC}"
  
  # Store the Fleet token in a separate environment variable
  echo "FLEET_TOKEN=${FLEET_TOKEN_VALUE}" >> .env
  echo -e "${GREEN}Added FLEET_TOKEN to .env file${NC}"
else
  echo -e "${RED}Failed to create Fleet Server token!${NC}"
fi

# Clean up
rm -f fleet-token-response.json kibana-token-response.json

echo -e "${GREEN}Elasticsearch security setup completed!${NC}"
