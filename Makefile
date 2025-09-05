.PHONY: up up-persist down reset reset-all logs tree

dirs:
	mkdir -p data/postgres data/valkey data/keycloak data/elasticsearch data/grafana data/prometheus provisioning/grafana/datasources

up: dirs
	podman-compose up -d postgres valkey keycloak es prometheus grafana

up-persist: dirs
	podman-compose up -d postgres_persist valkey_persist keycloak_persist es_persist prometheus grafana

down:
	podman-compose down

reset: ## reset persistent data (safe for Prom/Graf—will be wiped)
	podman-compose down
	rm -rf data/*
	mkdir -p data/postgres data/valkey data/keycloak data/elasticsearch data/grafana data/prometheus

reset-all: ## nuke containers & data
	podman-compose down -v || true
	rm -rf data/*

logs:
	podman-compose logs -f

tree:
	@echo "Project tree:" && find . -maxdepth 3 -type d | sed 's|^\./||'

