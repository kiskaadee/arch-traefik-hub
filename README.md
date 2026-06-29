# Traefik Homelab Core

This repository contains the core Control Plane for a modular, secure, and self-documenting homeserver architecture based on the **Hardened Hub** model.

It consolidates all routing, authentication, and core panel management into a single, unified Docker Compose stack, optimized for secure credentials management via `sops-nix`.

---

## 🏗️ Architectural Overview

The system is split into two distinct planes to ensure stability, security, and a clean separation of concerns:

### 1. Control Plane (This Repository)
The "nervous system" of the server. These services handle security, edge routing, identity, maintenance, and portal visualization. All services are defined in a single, root-level `docker-compose.yml` and state configurations are stored in `./config/`:

* **`traefik` (v3.6):** The edge gateway. Handles wildcard HTTPS (Let's Encrypt DNS-01 challenges via Dynu), reverse routing, and load balancing.
* **`socket-proxy`:** Security boundary. Decouples containers from the host's `/var/run/docker.sock`.
* **`authelia`:** Provides Single Sign-On (SSO) and 2FA protection for administrative tools and exposed applications.
* **`portainer`:** Visual container and stack management.
* **`dozzle`:** Real-time log streaming for core containers (SSO Protected).
* **`watchtower` & `diun`:** Automated image updates and registry monitoring.
* **`homepage`:** Central landing dashboard at the root domain (`arch-services.mywire.org`) serving as the entry portal.

### 2. Data Plane (Decoupled User Applications)
User applications (such as Gitea, Jellyfin, or Kanban boards) live in separate directories outside this repository (e.g. `/home/kiskaadee/Deployments/traefik-deployments`). They integrate with the Control Plane dynamically via the shared external Docker network (`proxy-net`) and Traefik routing labels.

---

## 🚀 Getting Started

All instructions on deployment, structure, and secrets management have been updated for this release:

👉 **See the [Setup & Secrets Management Guide](docs/setup_guide.md)**

### Quick Start (NixOS systemd Service)
If you are deploying on NixOS with the matching configuration, the service is managed declaratively. To check status or read logs:
```bash
systemctl status homeserver-core
journalctl -u homeserver-core -f
```

### Manual Verification
If running manually (or troubleshooting config edits):
```bash
docker compose --env-file /run/secrets/rendered/homeserver.env up -d --remove-orphans
```

---

## 📚 Documentation
* **[Setup & Secrets Guide](docs/setup_guide.md)**: Detailed configuration, systemd service, and SOPS secret integration.
* **[Legacy Documentation](docs/legacy/)**: Archive of old setup files and html pages.
