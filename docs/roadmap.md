# 🗺️ Project Roadmap: Arch-traefik-hub

This document outlines the development phases for the **Arch-traefik-hub** ecosystem, focusing on security, observability, and service scalability.

## Phase 1: Core Gateway & Security 🔒
*The objective is to establish a hardened "Front Door" with automated certificate management.*

- [ ] **Credential Provisioning:** Configure the `.env` layer using Dynu API credentials.
- [ ] **Infrastructure Initialization:** Execute the `up.sh` deployment orchestration script.
- [ ] **ACME Validation:** Monitor Traefik logs to verify successful **DNS-01 challenges** and SSL certificate issuance.
- [ ] **Traffic Verification:** Confirm secure $HTTPS$ routing to the gateway via the `*.arch-services.mywire.org` TLD.

## Phase 2: Observability & Management Dashboard 📊
*Transitioning from CLI-based management to a centralized visual interface.*

- [ ] **Full-Stack Dashboard:** Develop a FastAPI-backed JS frontend to consume real-time container metadata.
- [ ] **Dockerization:** Containerize the Python dashboard and deploy it as a core service within the `proxy-net`.
- [ ] **Log Stream Integration:** Implement deep-linking between the custom dashboard and **Dozzle** for instant per-service log access.

## Phase 3: Service Ecosystem Expansion 🚀
*Deploying high-utility services while maintaining network isolation and resource efficiency.*

- [ ] **Visual Collaboration:** Deploy and configure **Excalidraw** and **Mermaid** for local diagramming.
- [ ] **Local AI Hub:** Optimize the **Ollama** deployment with load-balanced replicas for high-availability inference.
- [ ] **Performance Profiling:** Establish baseline CPU/RAM metrics to ensure host stability across all active services.

## Phase 4: Network Optimization & Resilience 🌐
*Optimizing the home network for low-latency and local-first access.*

- [ ] **Local DNS Resolution:** (Optional) Integrate a DNS sinkhole (e.g., Pi-hole) to resolve hostnames locally, reducing reliance on external DNS lookups.
- [ ] **Cross-Device Validation:** Audit **NAT Hairpinning** performance to ensure seamless access from mobile and IoT devices on the local Wi-Fi.

---

## 💡 Implementation Best Practices

### Network Resolution in Python
When querying the Docker socket via the Python SDK, ensure the logic is resilient to Docker Compose project naming (which often prepends directory names to network strings):

```python
# Use partial matching to find the proxy-net membership
if any("proxy-net" in net for net in networks.keys()):
    # logic for proxy-registered containers
```

### Security Standards
- **ACME Storage:** The `acme.json` file must maintain `600` permissions to be accepted by the Traefik provider.
- **Socket Access:** The Docker socket is mounted as `ro` (Read-Only) wherever possible to adhere to the principle of least privilege.

---

### How to use this roadmap
This roadmap is updated as features are merged into the `main` branch. Contributions to the service templates or dashboard logic are welcome via Pull Requests.
