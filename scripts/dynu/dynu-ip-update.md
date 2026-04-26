# Dynu IP Monitor & Updater

This component keeps your Dynu DNS record in sync with your current public IPv4 address.

It runs as a **systemd timer-driven probe**, not a daemon.

## Execution Flow

```
timer → service → script
                     ├─ lock (skip if overlapping run)
                     ├─ DNS discovery (fast path)
                     ├─ HTTP fallback (multi-provider)
                     ├─ strict validation
                     ├─ compare with last known IP
                     ├─ update Dynu (only on change)
                     ├─ atomic state write
                     └─ structured logs (journald)
```

---

## Installation

Run the setup script as root:

```bash
sudo ./setup.sh \
  --host your-domain.mywire.org \
  --user your-dynu-username \
  --password your-dynu-password
```

This will:

* Install the script to `/usr/local/bin/ip-monitor.sh`
* Install systemd units:

  * `/etc/systemd/system/dynu.service`
  * `/etc/systemd/system/dynu.timer`
* Store credentials in:

  * `/etc/conf.d/dynu-environment` (mode `600`)
* Enable and start the timer

---

## Runtime Behavior

* Runs every **5 minutes** (configurable via `dynu.timer`)
* Skips execution if a previous run is still active
* Only updates Dynu **when IP changes**
* Never writes state unless the update succeeds

---

## State Management

* Directory: `/var/lib/dynu/` (managed by systemd)
* Files:

  * `last_ip` → last successfully synced public IP
  * `lock` → used for concurrency control

State updates are **atomic**:

* write → temp file
* move → final file

---

## Logs & Monitoring

View logs:

```bash
journalctl -u dynu.service -f
```

### Log Types

* `event=discovered` → IP successfully detected
* `event=change` → IP changed
* `event=state_updated` → Dynu successfully updated
* `event=degraded` → fallback or partial failure
* `event=error` → hard failure (no state change)
* `event=skip` → concurrent run avoided

---

## Manual Testing

Force an update:

```bash
echo "1.1.1.1" > /var/lib/dynu/last_ip
systemctl start dynu.service
```

Check state:

```bash
cat /var/lib/dynu/last_ip
```

---

## Configuration

### Timer

```ini
OnBootSec=30s
OnUnitActiveSec=5min
Persistent=true
```

### Service

* Runs as `root`
* Uses systemd sandboxing:

  * `ProtectSystem=strict`
  * `NoNewPrivileges=true`
  * limited write access to `/var/lib/dynu`  
