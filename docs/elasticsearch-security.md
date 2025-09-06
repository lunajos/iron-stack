# Secure Elasticsearch and Kibana Deployment

This document provides instructions for setting up and using the secure Elasticsearch and Kibana deployment with TLS/SSL and X-Pack security enabled.

## Features

- TLS/SSL encryption for all communications
- X-Pack security enabled
- Elastic Fleet server for agent management
- Authentication for all Elasticsearch and Kibana access
- Integration with Metricbeat and Filebeat

## Prerequisites

Before starting the secure Elasticsearch and Kibana deployment, ensure you have:

1. Generated the necessary certificates using the provided script:
   ```bash
   ./scripts/generate-certs.sh
   ```

2. Updated the `.env` file with secure passwords:
   ```
   ELASTIC_PASSWORD=your_secure_password_here
   KIBANA_ENCRYPTION_KEY=at_least_32_characters_long_random_string
   ```

## Starting the Deployment

1. Start the secure Elasticsearch deployment:
   ```bash
   podman-compose up -d es kibana fleet-server
   ```

2. Wait for Elasticsearch to be ready (this may take a minute or two).

3. Run the security setup script to initialize the Fleet server token:
   ```bash
   ./scripts/setup-elastic-security.sh
   ```

## Accessing Elasticsearch and Kibana

- **Elasticsearch**: https://localhost:9200
  - Username: `elastic`
  - Password: The value of `ELASTIC_PASSWORD` in your `.env` file

- **Kibana**: https://localhost:5601
  - Username: `elastic`
  - Password: The value of `ELASTIC_PASSWORD` in your `.env` file

**Note**: Since we're using self-signed certificates, your browser will show a security warning. You can safely proceed by accepting the risk.

## Using Elastic Fleet

Elastic Fleet is enabled in this deployment, allowing you to manage agents and integrations centrally.

1. Access Kibana at https://localhost:5601
2. Navigate to Management → Fleet
3. Follow the setup instructions to add integrations

The Fleet server is accessible at https://fleet-server:8220 from within the container network.

## Troubleshooting

### Certificate Issues

If you encounter certificate-related errors:

1. Verify that the certificates were generated correctly:
   ```bash
   ls -la config/elasticsearch/certs/
   ```

2. Ensure the certificates are mounted correctly in the containers:
   ```bash
   podman exec -it es ls -la /usr/share/elasticsearch/config/certs/
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
