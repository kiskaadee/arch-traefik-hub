# Arch-traefik-hub 🚀

A centralized local services manager using **Traefik v3** as a reverse proxy with automated **SSL (Let's Encrypt)** via Dynu DNS-01 challenges.

## 🏗️ Architecture
- **Gateway**: Traefik (running in `core/`)
- **Network**: `proxy-net` (shared Docker bridge)
- **Domain**: `*.arch-services.mywire.org`
- **Automation**: `up.sh` script for zero-config deployment

## 🚦 Project Status

| Task | Status |
| :--- | :--- |
| NAT Port Forwarding (80/443) | ✅ Completed |
| Folder Scaffolding | ✅ Completed |
| Shared Network Setup | ✅ Completed |
| Custom Python Dashboard | 🏗️ In Progress |
| Dynu API Integration | ⏳ Pending (Key found) |
| Let's Encrypt Validation | ⏳ Pending |

## 🚀 Getting Started

### 1. Configuration
Create a `.env` file in the root directory (use `.env-example` as a template):
```bash
DYNU_API_KEY=your_key_here
ACME_EMAIL=your_email@example.com
DOMAIN=arch-services.mywire.org
```

### 2. Launching the Hub
The `up.sh` script handles network creation, directory permissions for SSL, and container startup.
```bash
chmod +x up.sh
./up.sh
```

### 3. Verification
- **Traefik Logs**: `docker logs -f traefik` (Watch for successful SSL challenge)
- **Local Dashboard**: `http://192.168.1.36:3000` (Once dashboard service is up)
- **Service Logs**: `https://logs.arch-services.mywire.org` (Via Dozzle)

## 🛠️ Adding New Services
To add a service, create a folder in `services/` and ensure the `docker-compose.yml` uses the `proxy-net` and includes the Traefik labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.MYSERVICE.rule=Host(`myservice.arch-services.mywire.org`)"
  - "traefik.http.routers.MYSERVICE.entrypoints=websecure"
  - "traefik.http.routers.MYSERVICE.tls.certresolver=myresolver"
```

---

## 📦 Current Service Map
- **Excalidraw**: `excalidraw.${DOMAIN}`
- **Gitea**: `gitea.${DOMAIN}`
- **Ollama**: `ollama.${DOMAIN}` (Load balanced x3)
- **Dozzle**: `logs.${DOMAIN}`
