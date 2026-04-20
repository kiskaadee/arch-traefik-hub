import docker
from fastapi import FastAPI

app = FastAPI()
client = docker.from_env()


@app.get("/api/services")
def get_services():
    services = []
    # Filter for containers in our specific network
    for container in client.containers.list(all=True):
        networks = container.attrs["NetworkSettings"]["Networks"]
        if "proxy-net" in networks:
            services.append(
                {
                    "name": container.name,
                    "status": container.status,  # running, exited, etc.
                    "image": container.image.tags[0] if container.image.tags else "N/A",
                    "hostname": container.labels.get(
                        f"traefik.http.routers.{container.name}.rule",
                        "No Hostname",
                    ),
                }
            )
    return services
