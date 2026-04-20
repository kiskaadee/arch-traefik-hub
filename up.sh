#!/bin/bash

# Ensure the shared network exists
docker network inspect proxy-net >/dev/null 2>&1 || \
    docker network create proxy-net

# CRITICAL: Traefik SSL file permissions
mkdir -p core/letsencrypt
touch core/letsencrypt/acme.json
chmod 600 core/letsencrypt/acme.json

# Function to start a service
start_service() {
    echo "Starting $1..."
    # Using -f allows us to stay in root and avoid 'cd' headaches
    docker compose -f "$1/docker-compose.yml" up -d
}

start_service "core"
start_service "services/dozzle"
start_service "services/excalidraw"

echo "Arch-traefik-hub is up!"
