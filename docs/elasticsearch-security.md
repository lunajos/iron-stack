# Secure Elasticsearch and Kibana Deployment

This document provides instructions for setting up and using the secure Elasticsearch and Kibana deployment with X-Pack security enabled.

## Features

- X-Pack security enabled for authentication and authorization
- Service account tokens for secure service-to-service communication
- Elastic Fleet server for agent management
- Authentication for all Elasticsearch and Kibana access
- Integration with Metricbeat and Filebeat

## Testing Results

We have successfully tested the secure Elasticsearch and Kibana deployment with the following configuration:

- Elasticsearch with X-Pack security enabled
- Kibana using a service account token for authentication
- Verified access to Elasticsearch indices
- Verified access to Kibana web interface

## Prerequisites

Before starting the secure Elasticsearch and Kibana deployment, ensure you have:

1. Updated the `.env` file with secure passwords:
   ```
   ELASTIC_PASSWORD=your_secure_password_here
   KIBANA_ENCRYPTION_KEY=at_least_32_characters_long_random_string
   ```

2. Sufficient permissions for data directories:
   ```bash
   mkdir -p /data/Projects/iron-stack/data/elasticsearch
   mkdir -p /data/Projects/iron-stack/data/kibana
   chmod 777 /data/Projects/iron-stack/data/kibana
   ```

## Starting the Deployment

The secure Elasticsearch and Kibana deployment can be started using the `make up-persist` command, which will use the configurations in `podman-compose.yml`. The setup is fully replicable with a fresh clone by following these steps:

1. Clone the repository and navigate to the project directory:
   ```bash
   git clone <repository-url>
   cd iron-stack
   ```

2. Start the secure Elasticsearch and Kibana deployment:
   ```bash
   make up-persist
   ```

3. Run the security setup script to initialize the service account tokens:
   ```bash
   ./scripts/setup-elastic-security.sh
   ```

   This script will:
   - Wait for Elasticsearch to be ready
   - Delete any existing Kibana service account token
   - Create a new Kibana service account token
   - Update the `.env` file with the Kibana token
   - Create a Fleet server token

4. Restart Kibana to use the newly generated token:
   ```bash
   podman restart kibana
   ```

Alternatively, if you prefer to start the services manually:

1. Start Elasticsearch with security enabled:
   ```bash
   podman run -d --name es --network iron-stack-net -p 9200:9200 \
     -e "ELASTIC_PASSWORD=changeme" \
     -e "bootstrap.memory_lock=true" \
     -e "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
     -e "xpack.security.enabled=true" \
     -e "discovery.type=single-node" \
     -e "xpack.license.self_generated.type=basic" \
     -v ./data/elasticsearch:/usr/share/elasticsearch/data:Z \
     --ulimit memlock=-1:-1 --ulimit nofile=65536:65536 \
     docker.elastic.co/elasticsearch/elasticsearch:8.14.3
   ```

2. Run the security setup script to initialize the service account tokens:
   ```bash
   ./scripts/setup-elastic-security.sh
   ```

3. Start Kibana with the generated token:
   ```bash
   podman run -d --name kibana --network iron-stack-net -p 5601:5601 \
     -e "ELASTICSEARCH_HOSTS=http://es:9200" \
     -e "ELASTICSEARCH_SERVICEACCOUNTTOKEN=$(grep FLEET_SERVER_SERVICE_TOKEN .env | cut -d= -f2)" \
     -e "XPACK_SECURITY_ENCRYPTIONKEY=something_at_least_32_characters_long" \
     -e "XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=something_at_least_32_characters_long" \
     -e "XPACK_REPORTING_ENCRYPTIONKEY=something_at_least_32_characters_long" \
     -e "XPACK_FLEET_ENABLED=true" \
     -v ./data/kibana:/usr/share/kibana/data:Z \
     docker.elastic.co/kibana/kibana:8.14.3
   ```

> **Note:** Ensuring both containers are on the same network is critical for hostname resolution. The network allows Kibana to resolve the `es` hostname to reach Elasticsearch.

## Accessing Elasticsearch and Kibana

- **Elasticsearch**: http://localhost:9200
  - Username: `elastic`
  - Password: The value of `ELASTIC_PASSWORD` in your `.env` file

- **Kibana**: http://localhost:5601
  - Login with Elasticsearch credentials

For production deployments, it's recommended to enable TLS/SSL for secure communications.

## Testing the Deployment

To verify that your secure Elasticsearch and Kibana deployment is working correctly:

1. Check that Elasticsearch is running with security enabled:
   ```bash
   podman exec -it es curl -u elastic:changeme "http://localhost:9200/_cat/indices?v"
   ```
   You should see a list of indices and be prompted for authentication.

2. Verify that Kibana can connect to Elasticsearch:
   ```bash
   curl http://localhost:5601/api/status
   ```
   You should get a response indicating that Kibana is running.

3. Open Kibana in your browser at http://localhost:5601 and log in with the Elasticsearch credentials.

4. Check that the service account tokens were created successfully:
   ```bash
   podman exec -it es curl -u elastic:changeme "http://localhost:9200/_security/service/elastic/kibana/credential?pretty"
   ```
   You should see the `kibana-token` in the response.

## Using Elastic Fleet

Elastic Fleet is enabled in this deployment, allowing you to manage agents and integrations centrally.

1. Access Kibana at http://localhost:5601
2. Navigate to Management → Fleet
3. Follow the setup instructions to add integrations

To set up a Fleet server:

```bash
podman run -d --name fleet-server --network iron-stack-net -p 8220:8220 \
  -e "FLEET_SERVER_ENABLE=true" \
  -e "FLEET_SERVER_ELASTICSEARCH_HOST=http://es:9200" \
  -e "FLEET_SERVER_ELASTICSEARCH_USERNAME=elastic" \
  -e "FLEET_SERVER_ELASTICSEARCH_PASSWORD=changeme" \
  -e "FLEET_SERVER_SERVICE_TOKEN=YOUR_FLEET_SERVICE_TOKEN" \
  -e "FLEET_SERVER_POLICY_ID=fleet-server-policy" \
  -e "FLEET_URL=http://fleet-server:8220" \
  -e "KIBANA_FLEET_SETUP=true" \
  -e "KIBANA_HOST=http://kibana:5601" \
  docker.elastic.co/beats/elastic-agent:8.14.3
```

## Troubleshooting

### Common Issues

#### Permission Issues

If you encounter permission issues with data directories:

```bash
chmod 777 /data/Projects/iron-stack/data/kibana
```

#### Kibana Authentication Issues

If Kibana fails to start with an error about service account token authentication:

1. Check the Kibana logs for specific error messages:
   ```bash
   podman logs kibana | grep -i error
   ```

2. If you see an error like `failed to authenticate service account [elastic/kibana] with token name [kibana-token]`, recreate the token:
   ```bash
   # Delete the existing token
   podman exec -it es curl -X DELETE -u elastic:changeme \
     "http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token?pretty"
   
   # Create a new token
   podman exec -it es curl -X POST -u elastic:changeme \
     "http://localhost:9200/_security/service/elastic/kibana/credential/token/kibana-token?pretty"
   ```

3. Update the token in the `.env` file and restart Kibana:
   ```bash
   # Update the token in .env (replace YOUR_TOKEN with the actual token value)
   sed -i "s|FLEET_SERVER_SERVICE_TOKEN=.*|FLEET_SERVER_SERVICE_TOKEN=YOUR_TOKEN|" .env
   
   # Restart Kibana
   podman restart kibana
   ```

4. If you see an error about using the elastic superuser, make sure to use a service account token instead:
   ```bash
   # Use service account token instead of username/password
   -e "ELASTICSEARCH_SERVICEACCOUNTTOKEN=YOUR_SERVICE_ACCOUNT_TOKEN"
   ```

#### Network Connectivity Issues

If you see errors like `getaddrinfo ENOTFOUND es` in the Kibana logs:

1. Make sure both Elasticsearch and Kibana are on the same network:
   ```bash
   # Create a custom network
   podman network create elastic-net
   
   # Start both containers on this network
   podman run -d --name es --network elastic-net ... docker.elastic.co/elasticsearch/elasticsearch:8.14.3
   podman run -d --name kibana --network elastic-net ... docker.elastic.co/kibana/kibana:8.14.3
   ```

2. Verify network connectivity between containers:
   ```bash
   podman exec -it kibana ping es
   ```

### Authentication Issues

If you can't authenticate:

1. Verify that X-Pack security is enabled:
   ```bash
   podman exec -it es curl -k -u elastic:${ELASTIC_PASSWORD} https://localhost:9200/_xpack
   ```

2. Reset the elastic user password if needed:
   ```bash
   podman exec -it es /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
   ```

## Security Best Practices

1. Change the default passwords for all built-in users
2. Use strong, unique passwords for each service
3. Regularly rotate certificates and credentials
4. Monitor Elasticsearch audit logs for suspicious activity
5. Implement network-level security to restrict access to your Elasticsearch and Kibana instances
