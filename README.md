# Traefik Reverse Proxy Setup

This directory contains the Docker Compose configuration for running Traefik as a reverse proxy for local development.

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of Docker networking

## Initial Setup

### 1. Create the Docker Network

Before starting Traefik, create the external Docker network that Traefik will use to communicate with other containers:

```bash
docker network create traefik_proxy
```

### 2. Start Traefik

```bash
docker compose up -d
```

### 3. Verify Traefik is Running

- Access the Traefik dashboard at: http://localhost:8080
- Check container status: `docker compose ps`

## Deploying Containers with Traefik

To have Traefik automatically route traffic to your containers, follow these steps:

### Example Docker Compose Configuration

Add this to your application's `docker-compose.yml`:

```yaml
services:
  my-app:
    image: my-app:latest
    container_name: my-app
    networks:
      - traefik_proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`my-app.localhost`)"
      - "traefik.http.routers.my-app.entrypoints=web"
      - "traefik.http.services.my-app.loadbalancer.server.port=3000"

networks:
  traefik_proxy:
    external: true
```

### Key Configuration Points

1. **Network**: Connect your container to the `traefik_proxy` network
2. **Labels**:
   - `traefik.enable=true` - Tell Traefik to watch this container
   - `traefik.http.routers.{name}.rule` - Define the routing rule (usually by hostname)
   - `traefik.http.routers.{name}.entrypoints` - Which entrypoint to use (web = HTTP:80)
   - `traefik.http.services.{name}.loadbalancer.server.port` - The port your app listens on inside the container

### Accessing Your Application

After deploying with the example above, access your app at:
- http://my-app.localhost

You can use any subdomain pattern like:
- `app.localhost`
- `api.localhost`
- `dashboard.localhost`

## Managing Traefik

### Stop Traefik
```bash
docker compose down
```

### View Logs
```bash
docker compose logs -f traefik
```

### Restart Traefik
```bash
docker compose restart
```

## Configuration Details

### Current Setup
- **HTTP Port**: 80
- **Dashboard Port**: 8080 (insecure mode for local development)
- **Network**: `traefik_proxy` (external)
- **Docker Socket**: Mounted read-only for container discovery

### Security Notes

⚠️ This configuration uses `--api.insecure=true` which is fine for local development but should **never** be used in production.

## Troubleshooting

### Container not accessible
1. Ensure your container is connected to the `traefik_proxy` network
2. Verify the container has the correct Traefik labels
3. Check the Traefik dashboard (http://localhost:8080) to see if the route appears
4. Ensure the port specified in labels matches your app's listening port

### Traefik not starting
1. Verify the `traefik_proxy` network exists: `docker network ls`
2. Check if port 80 or 8080 are already in use
3. Review logs: `docker compose logs traefik`

## Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Provider Configuration](https://doc.traefik.io/traefik/providers/docker/)
