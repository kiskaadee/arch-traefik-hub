# Setup & Secrets Management Guide (Traefik Homelab)

This document provides a guide for deploying, managing, and securing the consolidated homeserver core stack.

---

## 🏗️ Architectural Overview

The core infrastructure is organized as a single, unified Docker Compose stack:

* **/docker-compose.yml**: Root orchestrator defining all core services (`traefik`, `authelia`, `portainer`, `dozzle`, `watchtower`, `diun`, `homepage`, `socket-proxy`).
* **/config/**: Holds the configuration directories and sqlite databases for all services:
  * `config/letsencrypt/`: Contains SSL certificate state (`acme.json`).
  * `config/authelia/`: Contains single sign-on configs (`configuration.yml`, `users.yml`) and database (`db.sqlite3`).
  * `config/homepage/`: Contains dashboard layout files (`services.yaml`, `bookmarks.yaml`, etc.).
  * `config/diun/`: Diun registry monitoring database (`diun.db`).

---

## 🔒 Credentials & Secrets Management

Secrets are managed declaratively using **`sops-nix`** (Mozilla SOPS + age keys) inside your system configuration repository (`~/Config`). This keeps all private credentials completely out of Git in an encrypted format.

### How Secrets Flow:

```
[~/Config/hosts/desktop/secrets.yaml] (Encrypted)
       │
       ▼ (Decrypted at boot by sops-nix using SSH host key)
[/run/secrets/rendered/homeserver.env] (Runtime Environment File)
       │
       ▼ (Fed via --env-file flag into Docker Compose)
[Docker Containers] (Active environment variables)
```

---

## 🔑 Adding/Editing Secrets

To add or modify credentials (e.g. changing your Dynu API key or updating Authelia users):

1. Navigate to your system configuration repository:
   ```bash
   cd ~/Config
   ```
2. Decrypt and open the secrets file in your editor using SOPS:
   ```bash
   nix-shell -p sops --run "sops hosts/desktop/secrets.yaml"
   ```
3. Append or edit the required keys under the root block:
   ```yaml
   dynu_api_key: "your_dynu_api_key"
   acme_email: "your_email@provider.com"
   authelia_session_secret: "secure_64_character_hex_string"
   authelia_storage_encryption_key: "secure_64_character_hex_string"
   authelia_identity_validation_reset_password_jwt_secret: "secure_64_character_hex_string"
   
   # Hashed password for the default admin user
   authelia_user_kiskaadee_password_hash: "$argon2id$v=19$m=65536..."
   ```
   *To generate an Argon2 password hash securely, run:*
   `docker run --rm -it authelia/authelia:latest authelia crypto hash generate argon2`
4. Save and close the editor. SOPS will automatically encrypt the file and write it back to disk.

---

## ⚙️ NixOS Integration

The stack is managed as a declarative systemd service inside `/home/kiskaadee/Config/hosts/desktop/homeserver.nix`:

### 1. Secret Environment Template
The module defines a SOPS template to gather all secrets and structure them as key-value pairs at `/run/secrets/rendered/homeserver.env`:
```nix
sops.templates."homeserver.env" = {
  owner = "kiskaadee";
  content = lib.generators.toKeyValue {} {
    DOMAIN = "arch-services.mywire.org";
    DOCKER_API_VERSION = "1.40";
    DYNU_API_KEY = config.sops.placeholder.dynu_api_key;
    ACME_EMAIL = config.sops.placeholder.acme_email;
    AUTHELIA_SESSION_SECRET = config.sops.placeholder.authelia_session_secret;
    AUTHELIA_STORAGE_ENCRYPTION_KEY = config.sops.placeholder.authelia_storage_encryption_key;
    AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET = config.sops.placeholder.authelia_identity_validation_reset_password_jwt_secret;
  };
};

# 2. Declarative User Database Template
We also generate Authelia's `users.yml` file from the decrypted Argon2 hash:
```nix
sops.templates."users.yml" = {
  owner = "kiskaadee";
  content = ''
    users:
      kiskaadee:
        displayname: "Kiskaadee"
        password: "${config.sops.placeholder.authelia_user_kiskaadee_password_hash}"
        email: "fcortesbio@gmail.com"
        groups:
          - admins
          - dev
  '';
};
```

### 3. systemd Lifecycle Daemon
The service starts and stops the compose stack automatically:
```nix
systemd.services.homeserver-core = {
  description = "Homeserver Core Stack";
  after = [ "network-online.target" "docker.service" ];
  wants = [ "network-online.target" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    WorkingDirectory = "/home/kiskaadee/Deployments/homeserver";
    ExecStart = "${pkgs.docker-compose}/bin/docker-compose --env-file ${config.sops.templates."homeserver.env".path} up -d --remove-orphans";
    ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
  };
};
```

---

## 🚀 Running and Managing the Stack

Because the systemd service manages the containers, standard `systemctl` commands can be used:

* **Start the stack**: `sudo systemctl start homeserver-core`
* **Stop the stack**: `sudo systemctl stop homeserver-core`
* **Check service status**: `systemctl status homeserver-core`
* **Check logs**: `journalctl -u homeserver-core`

### Dynamic Configuration Tweaks (Non-Nix Workflow)
If you modify `docker-compose.yml` (e.g. adding a new Traefik routing label), you do **not** need to rebuild NixOS! You can apply it instantly:
```bash
cd /home/kiskaadee/Deployments/homeserver
docker compose --env-file /run/secrets/rendered/homeserver.env up -d --remove-orphans
```
This preserves the extreme agility of Docker Compose while keeping your system configuration and secrets declaratively managed.
