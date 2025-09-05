# Keycloak Setup Guide

This guide explains how to properly set up and configure Keycloak for your infrastructure.

## Network Configuration

Keycloak needs to be on the same network as PostgreSQL to connect to it. The stack uses a dedicated network called `iron-stack-net` for container communication.

```bash
# Create the network if it doesn't exist
podman network create iron-stack-net

# Make sure both PostgreSQL and Keycloak are on this network
```

## First-Time Startup

When starting Keycloak for the first time, you should:

1. Use the `start-dev` command instead of `start` (since we don't have HTTPS certificates)
2. Ensure PostgreSQL is running and on the same network
3. **Not** use the `--optimized` flag (the optimized mode requires a pre-built server)

```bash
# First make sure PostgreSQL is running
podman run -d --name postgres --network iron-stack-net -p 15432:5432 \
  -e POSTGRES_USER=kc -e POSTGRES_PASSWORD=kcpass -e POSTGRES_DB=keycloak \
  -v /data/Projects/iron-stack/data/postgres:/var/lib/postgresql/data:Z \
  docker.io/postgres:15-alpine

# First-time startup of Keycloak (correct way)
podman run -d --name keycloak --network iron-stack-net -p 18080:18080 \
  -e KC_DB=postgres \
  -e KC_DB_URL_HOST=postgres \
  -e KC_DB_URL_DATABASE=keycloak \
  -e KC_DB_USERNAME=kc \
  -e KC_DB_PASSWORD=kcpass \
  -e KC_HTTP_PORT=18080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  -e KC_HOSTNAME=localhost \
  -v /data/Projects/iron-stack/data/keycloak:/opt/keycloak/data:Z \
  quay.io/keycloak/keycloak:26.0 start-dev
```

## Building an Optimized Server

After your first successful startup, you can stop the container and build an optimized version for better performance:

```bash
# Stop the container
podman stop keycloak
podman rm keycloak

# Run a temporary container to build the optimized server
podman run --rm -v /data/Projects/iron-stack/data/keycloak:/opt/keycloak/data:Z \
  quay.io/keycloak/keycloak:26.0 build

# Start with optimized mode
podman run -d --name keycloak --network iron-stack-net -p 18080:18080 \
  -e KC_DB=postgres \
  -e KC_DB_URL_HOST=postgres \
  -e KC_DB_URL_DATABASE=keycloak \
  -e KC_DB_USERNAME=kc \
  -e KC_DB_PASSWORD=kcpass \
  -e KC_HTTP_PORT=18080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  -e KC_HOSTNAME=localhost \
  -v /data/Projects/iron-stack/data/keycloak:/opt/keycloak/data:Z \
  quay.io/keycloak/keycloak:26.0 start --optimized
```

## Initial Configuration

After starting Keycloak, you can access the admin console at http://localhost:18080/admin/ using the credentials specified in the environment variables (`admin`/`admin123`).

### Creating a New Realm

1. Log in to the admin console
2. Hover over the realm dropdown in the top-left corner and click "Create Realm"
3. Enter a name for your realm (e.g., "app-realm")
4. Click "Create"

### Creating a Client

1. In your realm, go to "Clients" in the left sidebar
2. Click "Create client"
3. Fill in the client details:
   - Client ID: A unique identifier for your client (e.g., "app-client")
   - Client Protocol: OpenID Connect
   - Client Authentication: On (for confidential clients)
4. Click "Next" and configure the client settings:
   - Valid redirect URIs: Add your application URLs (e.g., "http://localhost:3000/*")
   - Web Origins: Add your application origins for CORS (e.g., "http://localhost:3000")
5. Click "Save"

### Creating Roles

1. Go to "Realm roles" in the left sidebar
2. Click "Create role"
3. Enter a name for the role (e.g., "user", "admin")
4. Add a description
5. Click "Save"

### Creating Users

1. Go to "Users" in the left sidebar
2. Click "Add user"
3. Fill in the user details:
   - Username: The user's username
   - Email: The user's email address
   - First Name/Last Name: The user's name
4. Click "Create"
5. Go to the "Credentials" tab for the user
6. Click "Set password"
7. Enter a password and toggle off "Temporary" if you don't want the user to reset their password on first login
8. Click "Save"
9. Go to the "Role mappings" tab
10. Assign appropriate roles to the user

## Automated Configuration

For automated setup, you can use the Keycloak REST API or import a realm configuration file:

```bash
# Import a realm configuration file during startup
podman run -d --name keycloak --network iron-stack-net -p 18080:18080 \
  -e KC_DB=postgres \
  -e KC_DB_URL_HOST=postgres \
  -e KC_DB_URL_DATABASE=keycloak \
  -e KC_DB_USERNAME=kc \
  -e KC_DB_PASSWORD=kcpass \
  -e KC_HTTP_PORT=18080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin123 \
  -e KC_HOSTNAME=localhost \
  -v /data/Projects/iron-stack/data/keycloak:/opt/keycloak/data:Z \
  -v /data/Projects/iron-stack/config/keycloak/realm-config.json:/opt/keycloak/data/import/realm-config.json:Z \
  quay.io/keycloak/keycloak:26.0 start --import-realm
```

## Production Considerations

For production deployments, consider the following:

1. **Use HTTPS**: Configure Keycloak to use HTTPS by setting up a reverse proxy or using the built-in HTTPS support
2. **Strong Passwords**: Use strong, unique passwords for admin and service accounts
3. **Database Configuration**: Use a dedicated PostgreSQL instance with proper backup procedures
4. **Email Configuration**: Set up email for account verification and password reset
5. **User Federation**: Configure LDAP or other user federation if needed
6. **Theme Customization**: Customize the login and admin themes to match your branding
