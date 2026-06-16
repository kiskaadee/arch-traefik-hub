# Server Migration Todo List

## 1. Pre-Migration (Old Server)
- [ ] Fill in all missing values in `secrets.txt`.
- [ ] Verify that `backup.zip` contains all necessary files.
- [ ] Stop all containers: `./down.sh` or `docker-compose down` in each directory.
- [ ] Securely transfer `backup.zip` to the new server (e.g., using `scp`).

## 2. Environment Setup (New Server)
- [ ] Install Docker and Docker Compose.
- [ ] Create external Docker networks:
  - `docker network create proxy-net`
  - `docker network create socket-net`
- [ ] Clone the repository to the new server.
- [ ] Unzip `backup.zip` into the project root.

## 3. Configuration & Data Restoration
- [ ] **Traefik SSL**: Move `acme.json` to `infra/core/letsencrypt/`.
- [ ] **Traefik Permissions**: Run `chmod 600 infra/core/letsencrypt/acme.json`.
- [ ] **Authelia Data**: Move `users.yml` and `db.sqlite3` to `infra/authelia/config/`.
- [ ] **Environment Files**: 
  - Create `infra/core/.env` from `secrets.txt`.
  - Create `infra/authelia/.env` from `secrets.txt`.
  - Run `chmod 600 infra/core/.env infra/authelia/.env`.
- [ ] **DDNS**: Restore `scripts/dynu/dynu-environment`.
- [ ] **Homepage**: Restore `homepage/config/*.yaml` files.

## 4. Deployment
- [ ] Run `./up.sh` to start all services.
- [ ] Check Traefik logs: `docker logs traefik -f`.
- [ ] Verify SSL certificates are loading correctly.
- [ ] Check Authelia logs: `docker logs authelia -f`.
- [ ] Test login via `auth.<your-domain>`.

## 5. Post-Deployment
- [ ] Update Dynu IP manually if the update script hasn't run yet.
- [ ] Verify all services in the Homepage dashboard.
- [ ] **CRITICAL**: Delete `backup.zip` and `secrets.txt` from the server once verified.
