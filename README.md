# Arch-traefik-hub 🚀

A centralized local services platform using **Traefik v3** as a reverse proxy with automated **SSL (Let's Encrypt)** and resilient **Dynu DDNS IP synchronization**.

---

## 🏗️ Architecture

The system is composed of two independent but complementary layers:

### 1. Gateway Layer (Traefik)
- Reverse proxy for all services
- Handles HTTPS termination
- Performs ACME DNS-01 challenges via Dynu API
- Runs inside `core/`

### 2. Infrastructure Layer (Dynu IP Sync)
- Systemd-managed IP monitor (`dynu.service`)
- Periodically detects public IPv4 changes
- Updates Dynu DNS records only when necessary
- Uses:
  - DNS (fast path via `dig`)
  - HTTP providers (fallback)
  - Atomic state (`/var/lib/dynu/last_ip`)
  - Structured journald logs

### 3. Network
- Shared Docker bridge: `proxy-net`
- Domain: `*.arch-services.mywire.org`

---

## 🚦 Project Status

| Component | Status |
| :--- | :--- |
| NAT Port Forwarding (80/443) | ✅ Completed |
| Traefik Gateway | ✅ Operational |
| Dynu DDNS IP Sync | ✅ Completed |
| ACME DNS-01 (Let's Encrypt) | ⏳ Pending validation |
| Python Dashboard | 🏗️ In Progress |

---

## 🚀 Getting Started

### 1. Environment Configuration

Create `.env` in the project root:

```bash
DYNU_API_KEY=your_key_here
ACME_EMAIL=your_email@example.com
DOMAIN=arch-services.mywire.org
```

---

### 2. Launch the Gateway

```bash
chmod +x up.sh
./up.sh
```

This will:
- Create the shared Docker network
- Set correct permissions for ACME storage
- Start Traefik and core services

---

### 3. Configure Dynu IP Sync (Host-level)

The IP updater runs **outside Docker** via systemd.

Run the setup script:

```bash
sudo ./setup-dynu.sh \
  --host yourdomain.mywire.org \
  --user your_dynu_username \
  --password your_dynu_password
```

This installs:
- `/usr/local/bin/ip-monitor.sh`
- `dynu.service`
- `dynu.timer`

Verify:

```bash
systemctl status dynu.timer
journalctl -u dynu.service -f
cat /var/lib/dynu/last_ip
```

---

## 🔍 Verification

- **Traefik Logs**
  ```bash
  docker logs -f traefik
  ```

- **Dynu Sync Logs**
  ```bash
  journalctl -u dynu.service -f
  ```

- **Check Current IP State**
  ```bash
  cat /var/lib/dynu/last_ip
  ```

---

## 🛠️ Adding New Services

Each service must:

- Join `proxy-net`
- Define Traefik routing labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.MYSERVICE.rule=Host(`myservice.arch-services.mywire.org`)"
  - "traefik.http.routers.MYSERVICE.entrypoints=websecure"
  - "traefik.http.routers.MYSERVICE.tls.certresolver=myresolver"
```

---

## 📦 Current Services

- Excalidraw → `excalidraw.${DOMAIN}`
- Gitea → `gitea.${DOMAIN}`
- Ollama (x3) → `ollama.${DOMAIN}`
- Dozzle → `logs.${DOMAIN}`

---

## 📌 Design Principles

- **Idempotent execution** (safe under repetition)
- **Fail-fast behavior** (no partial state)
- **Atomic state updates**
- **Separation of concerns**:
  - Traefik → TLS + routing
  - Dynu updater → IP correctness
- **Observability-first logging** (journald structured events)

---

## 📚 Related Docs

- `docs/dynu-ip-update.md` → usage and operational notes  
- `docs/dynu-ip-update-protocol.md` → design and architecture decisions  