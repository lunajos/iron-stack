#!/bin/bash
set -e

# Create directories if they don't exist
mkdir -p /data/Projects/iron-stack/config/elasticsearch/certs/ca
mkdir -p /data/Projects/iron-stack/config/elasticsearch/certs/es
mkdir -p /data/Projects/iron-stack/config/elasticsearch/certs/kibana

# Generate CA certificate
openssl req -x509 -sha256 -nodes -newkey rsa:4096 \
  -keyout /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.key \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt \
  -days 365 \
  -subj "/CN=Iron Stack CA"

# Generate Elasticsearch certificate
openssl req -new -newkey rsa:4096 -nodes \
  -keyout /data/Projects/iron-stack/config/elasticsearch/certs/es/es.key \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/es/es.csr \
  -subj "/CN=es"

# Create config file for SAN
cat > /data/Projects/iron-stack/config/elasticsearch/certs/es/es.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = es
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Sign Elasticsearch certificate with our CA
openssl x509 -req -in /data/Projects/iron-stack/config/elasticsearch/certs/es/es.csr \
  -CA /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt \
  -CAkey /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.key \
  -CAcreateserial \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/es/es.crt \
  -days 365 \
  -extfile /data/Projects/iron-stack/config/elasticsearch/certs/es/es.conf \
  -extensions v3_req

# Generate Kibana certificate
openssl req -new -newkey rsa:4096 -nodes \
  -keyout /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.key \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.csr \
  -subj "/CN=kibana"

# Create config file for SAN
cat > /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.conf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = kibana
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Sign Kibana certificate with our CA
openssl x509 -req -in /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.csr \
  -CA /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt \
  -CAkey /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.key \
  -CAcreateserial \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.crt \
  -days 365 \
  -extfile /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.conf \
  -extensions v3_req

# Create PKCS12 file for Elasticsearch
openssl pkcs12 -export \
  -in /data/Projects/iron-stack/config/elasticsearch/certs/es/es.crt \
  -inkey /data/Projects/iron-stack/config/elasticsearch/certs/es/es.key \
  -out /data/Projects/iron-stack/config/elasticsearch/certs/es/es.p12 \
  -name "es" \
  -CAfile /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt \
  -caname "Iron Stack CA" \
  -passout pass:changeit

# Set proper permissions
chmod 644 /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.crt
chmod 600 /data/Projects/iron-stack/config/elasticsearch/certs/ca/ca.key
chmod 644 /data/Projects/iron-stack/config/elasticsearch/certs/es/es.crt
chmod 600 /data/Projects/iron-stack/config/elasticsearch/certs/es/es.key
chmod 644 /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.crt
chmod 600 /data/Projects/iron-stack/config/elasticsearch/certs/kibana/kibana.key

echo "Certificates generated successfully!"
