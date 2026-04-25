# Dynu IP Address Update Protocol

## Problem Definition
* **Success Criteria**: The system must detect changes in public IPv4 addresses and update Dynu records with high resilience, using strict validation and atomic state management to avoid `abuse` flags.
* **Non-Goals**: This implementation does not manage complex DNS records (MX/TXT) or IPv6 addressing.

## ADR: Resilience & Security Hardening
**Decision**: Implement a hardened, multi-provider discovery engine via systemd.

* **Rationale**: 
    * **Redundancy**: Iterating through multiple HTTP providers prevents failure if a single service (like `ifconfig.me`) goes offline.
    * **Security**: Systemd sandboxing (`ProtectSystem=strict`, `NoNewPrivileges`) ensures the script operates in a "least privilege" environment.
    * **Observability**: Capturing `stderr` from discovery commands into the journal allows for deep-dive debugging of network timeouts.
* **Consequences**: Slightly higher complexity in shell logic, but provides a "set and forget" infrastructure layer.

---

## Implementation Details

### 1. Directory & State Management
Runtime data is handled by systemd's `StateDirectory` directive, which manages `/var/lib/dynu` automatically.
* **State File**: `/var/lib/dynu/last_ip` (Atomic updates via `mktemp` + `mv`).
* **Locking**: Concurrency is managed via `flock` on `/var/lib/dynu/lock`.

### 2. Core Logic: `ip-monitor.sh`
The script follows a "Fail-Fast" philosophy:
1.  **Invariants**: Validates that it is running within a systemd environment.
2.  **Discovery Loop**: 
    * Primary: DNS query via `dig` (ultra-fast).
    * Fallback: Multi-URL HTTP loop (`api.ipify.org`, `ifconfig.me`, `wtfismyip.com`).
3.  **Validation**: Strict regex and numeric bound checks for IPv4 format.
4.  **Update**: Hits the Dynu REST API only upon confirmed IP delta.

### 3. Hardened Systemd Orchestration

#### Service: `dynu.service`
```ini
[Service]
Type=oneshot
User=root
StateDirectory=dynu
EnvironmentFile=/etc/conf.d/dynu-environment
ExecStart=/usr/local/bin/ip-monitor.sh
# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/dynu
```

#### Timer: `dynu.timer`
```ini
[Timer]
OnBootSec=30s
OnUnitActiveSec=15min
Persistent=true
```

---

## Verification and Monitoring
* **Live Logs**: `journalctl -u dynu.service -f`
* **Check State**: `cat /var/lib/dynu/last_ip`
* **Simulate Update**: `echo "1.1.1.1" > /var/lib/dynu/last_ip && systemctl start dynu.service`
```