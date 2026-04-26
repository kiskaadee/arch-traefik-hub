# 🗺️ Project Roadmap: Arch-traefik-hub

This roadmap reflects the current system maturity and next priorities.

---

## Phase 1: Core Gateway & DNS Stability 🔒 (Mostly Complete)

Objective: stable external access with correct DNS resolution.

- [x] NAT Port Forwarding (80/443)
- [x] Dynu DDNS IP synchronization (systemd-based)
- [x] Traefik deployment with reverse proxy
- [ ] ACME DNS-01 validation (Let's Encrypt)
- [ ] End-to-end HTTPS verification across all services

Notes:
- IP drift is now handled independently via Dynu updater
- Remaining risk is ACME challenge correctness

---

## Phase 2: Observability & Control Plane 📊

Objective: reduce reliance on CLI and improve visibility.

- [ ] FastAPI backend for service metadata
- [ ] Minimal JS frontend dashboard
- [ ] Integration with Docker socket (read-only)
- [ ] Deep-linking to Dozzle logs per service
- [ ] Health/status indicators for:
  - containers
  - domains
  - SSL certificates

---

## Phase 3: Service Ecosystem Expansion 🚀

Objective: increase utility without compromising isolation.

- [ ] Excalidraw + diagram tooling
- [ ] Expand Ollama cluster (load + memory tuning)
- [ ] Add developer-focused tools (CI, registry, etc.)
- [ ] Define service templates for quick onboarding

Constraints:
- Must use `proxy-net`
- Must be Traefik-exposed
- Must remain resource-aware

---

## Phase 4: Network Optimization & Resilience 🌐

Objective: reduce external dependencies and improve latency.

- [ ] Local DNS resolver (Pi-hole or equivalent)
- [ ] Internal hostname resolution (LAN-first)
- [ ] NAT hairpinning validation across devices
- [ ] Optional fallback DNS providers for redundancy

---

## Phase 5: Hardening & Reliability ⚙️

Objective: move from “working” to “robust”.

- [ ] Add alerting (failed Dynu updates, SSL issues)
- [ ] Timer tuning based on real IP volatility
- [ ] Rate-limit awareness for Dynu API
- [ ] Backup strategy for:
  - Traefik config
  - ACME storage
- [ ] Evaluate IPv6 support (explicitly out-of-scope so far)

---

## 💡 Engineering Notes

### Separation of Concerns

- Dynu updater:
  - ensures correct **public IP**
  - runs via systemd (host-level)

- Traefik:
  - ensures **TLS + routing**
  - runs in Docker

This separation prevents coupling failures (e.g., container restart affecting DNS correctness).

---

### Failure Model

- **Degraded**
  - DNS failure → HTTP fallback
  - Provider-specific issues

- **Error**
  - No valid IP found
  - Dynu API failure

Only **successful external sync** mutates local state.

---

### How to Use This Roadmap

- Updated after stable merges into `main`
- Items should represent **deployable increments**, not ideas
- Avoid speculative features unless tied to concrete problems