# Iron Stack

A mini infrastructure deployment using Podman Compose with the following services:

- PostgreSQL
- Valkey (Redis alternative)
- Keycloak
- Elasticsearch
- Prometheus
- Grafana

## Features

- All services are configured with persistent storage in `./data/{service}/` directories
- Easy to use Makefile commands for management
- Environment variables configured in `.env` file
- Profiles for ephemeral or persistent deployments
- Container networking for inter-service communication

## Prerequisites

- Podman and Podman Compose installed
- Sufficient system resources to run all services

## Network Setup

The stack uses a dedicated network called `iron-stack-net` for container communication. This ensures services can resolve each other by hostname (e.g., Keycloak can connect to PostgreSQL using the hostname `postgres`).

The network is automatically created when you start the stack with the provided commands. If you need to create it manually:

```bash
podman network create iron-stack-net
```

All services are configured to use this network in the `podman-compose.yml` file.

## Getting Started

### Starting the Stack

#### Using Makefile (Note: Currently experiencing permission issues with some services)

For ephemeral storage (data will be lost when containers are removed):

```bash
make up
```

For persistent storage (data will be saved to ./data/{service}/ directories):

```bash
make up-persist
```

#### Manual Startup Commands (Working Alternative)

Create a network for container communication:

```bash
podman network create iron-stack-net
```

Start PostgreSQL:

```bash
podman run -d --name postgres --network iron-stack-net -p 15432:5432 \
  -e POSTGRES_USER=kc -e POSTGRES_PASSWORD=kcpass -e POSTGRES_DB=keycloak \
  -v /data/Projects/iron-stack/data/postgres:/var/lib/postgresql/data:Z \
  docker.io/postgres:15-alpine
```

Start Valkey:

```bash
podman run -d --name valkey --network iron-stack-net -p 6379:6379 \
  -v /data/Projects/iron-stack/valkey.conf:/etc/valkey/valkey.conf:Z \
  -v /data/Projects/iron-stack/data/valkey:/data:Z \
  valkey/valkey:latest valkey-server /etc/valkey/valkey.conf
```

Start Elasticsearch:

```bash
podman run -d --name es --network iron-stack-net -p 9200:9200 \
  -e "discovery.type=single-node" -e "xpack.security.enabled=false" \
  -e "bootstrap.memory_lock=true" -e "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
  -v /data/Projects/iron-stack/data/elasticsearch:/usr/share/elasticsearch/data:Z \
  --ulimit memlock=-1:-1 --ulimit nofile=65536:65536 \
  docker.elastic.co/elasticsearch/elasticsearch:8.14.3
```

Start Grafana:

```bash
podman run -d --name grafana --network iron-stack-net -p 3000:3000 \
  -e GF_SECURITY_ADMIN_USER=admin -e GF_SECURITY_ADMIN_PASSWORD=admin123 \
  -v /data/Projects/iron-stack/data/grafana:/var/lib/grafana:Z \
  -v /data/Projects/iron-stack/provisioning/grafana/datasources:/etc/grafana/provisioning/datasources:Z \
  docker.io/grafana/grafana:11.2.0
```

Start Kibana:

```bash
podman run -d --name kibana --network iron-stack-net -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://es:9200" \
  docker.elastic.co/kibana/kibana:8.14.3
```

Start Prometheus:

```bash
podman run -d --name prometheus --network iron-stack-net -p 9090:9090 \
  -v /data/Projects/iron-stack/prometheus.yml:/etc/prometheus/prometheus.yml:Z \
  -v /data/Projects/iron-stack/data/prometheus:/prometheus:Z \
  docker.io/prom/prometheus:v2.54.1 \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle
```

Start MinIO (S3-compatible object storage):

```bash
podman run -d --name minio --network iron-stack-net -p 9000:9000 -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  -v /data/Projects/iron-stack/data/minio:/data:Z \
  quay.io/minio/minio:latest server /data --console-address ":9001"
```

Start Keycloak (first time setup):

```bash
podman run -d --name keycloak --network iron-stack-net -p 18080:18080 \
  -e KC_DB=postgres -e KC_DB_URL_HOST=postgres -e KC_DB_URL_DATABASE=keycloak \
  -e KC_DB_USERNAME=kc -e KC_DB_PASSWORD=kcpass -e KC_HTTP_PORT=18080 \
  -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  -e KC_HOSTNAME=localhost \
  -v /data/Projects/iron-stack/data/keycloak:/opt/keycloak/data:Z \
  quay.io/keycloak/keycloak:26.0 start-dev
```

> **Note**: For Keycloak, do not use the `--optimized` flag on first startup. See [Keycloak Setup Guide](docs/keycloak-setup.md) for details on optimized mode.

### Stopping the Stack

```bash
make down
```

Or manually:

```bash
podman stop postgres valkey es grafana kibana keycloak prometheus minio
podman rm postgres valkey es grafana kibana keycloak prometheus minio
```

### Resetting Data

To reset all persistent data (but keep Prometheus and Grafana data):

```bash
make reset
```

To completely reset all data and containers:

```bash
make reset-all
```

### Viewing Logs

```bash
make logs
```

Or manually:

```bash
podman logs postgres
podman logs es
podman logs grafana
```

## Service Access

| Service       | URL                      | Default Credentials     | Status       |
|---------------|--------------------------|-------------------------|-------------|
| PostgreSQL    | localhost:15432          | kc / kcpass             | Running      |
| Valkey        | localhost:6379           | No auth (configurable)  | Running      |
| Keycloak      | http://localhost:18080   | admin / admin123        | Running      |
| Elasticsearch | http://localhost:9200    | No auth                 | Running      |
| Kibana        | http://localhost:5601    | No auth                 | Running      |
| Prometheus    | http://localhost:9090    | No auth                 | Running      |
| Grafana       | http://localhost:3000    | admin / admin123        | Running      |
| MinIO         | http://localhost:9000    | minioadmin / minioadmin | Running      |
| MinIO Console | http://localhost:9001    | minioadmin / minioadmin | Running      |

## Directory Structure

- `./data/`: Contains persistent data for all services
- `./provisioning/`: Contains configuration for services (e.g., Grafana datasources)
- `.env`: Environment variables for all services
- `podman-compose.yml`: Service definitions
- `prometheus.yml`: Prometheus configuration
- `valkey.conf`: Valkey configuration

## License

This project is licensed under a proprietary license. See the [LICENSE](LICENSE) file for details.

**Important**: This software is provided with restricted usage rights. You may view and fork this repository solely for evaluation purposes. Any other use requires explicit written permission from the copyright holder.

## Troubleshooting

### Network Issues

If services can't communicate with each other (e.g., Keycloak can't connect to PostgreSQL):

1. Verify the network exists: `podman network ls`
2. Check that containers are on the same network: `podman inspect <container_name> | grep -A 10 Networks`
3. Try pinging between containers: `podman exec <container_name> ping <other_container_name>`
4. Ensure services are using hostnames that match container names

### Permission Issues

If you encounter permission issues with configuration files or data directories, try these solutions:

1. Use the manual startup commands provided above which use absolute paths and the `:Z` SELinux flag
2. Ensure your user has appropriate permissions to the directories
3. For persistent issues, you can try:
   ```bash
   chmod -R 777 data/
   ```
   (Note: This is not recommended for production environments)

### Container Communication Issues

If containers cannot communicate with each other:

1. Ensure they are on the same network: `podman network create iron-stack-net`
2. Connect existing containers to the network: `podman network connect iron-stack-net container_name`
3. Use container names as hostnames when connecting from one service to another

### Port Conflicts

If you see errors like "address already in use":

1. Change the port mapping in the command (e.g., `-p 15432:5432` instead of `-p 5432:5432`)
2. Update the `.env` file with the new port numbers
3. Make sure to update any service configurations that reference these ports

## Notes

- The stack is configured with reasonable defaults for development use
- For production use, you should modify the configurations and credentials
- Some exporters for Prometheus monitoring are commented out in the configuration and would need to be added separately
