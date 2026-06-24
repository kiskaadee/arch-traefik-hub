# ADR 002: Migrate Dynu DDNS IP Discovery to Host NixOS Configuration

*   **Status**: Accepted & Implemented
*   **Date**: 2026-06-24
*   **Decider**: User & Antigravity

## Context
Previously, we managed dynamic DNS IP synchronization using custom bash scripts (`ip-monitor.sh`) and systemd unit configurations in the `homeserver` scripts directory. The service checked the WAN IP and pushed updates to Dynu every 5 minutes.

However, this design introduced several structural problems:
1.  **Imperative Secrets Leakage**: Credentials were stored in a cleartext out-of-band environment file (`/etc/conf.d/dynu-environment`). This required manual setup on target hosts and broke the declarative reproducibility goal.
2.  **Redundant Logic**: The desktop machine (`desktop`) and server machine shared the same router (external public IP), but operated separate, duplicated cron/timer implementations.
3.  **Inefficient Polling**: Checking the external IP and calling the Dynu APIs every 5 minutes from multiple endpoints generated unnecessary network traffic and risked API bans.

## Decision
We decided to **deprecate and remove all native Dynu IP updater scripts and systemd definitions** from the `homeserver` codebase. 

Instead, the Dynu IP monitoring and DDNS update lifecycle is now managed directly by the host operating system's configuration repository ([nixos-config](https://github.com/kiskaadee/nixos-config)).

## Consequences

### Positive
*   **Single Source of Truth**: All WAN IP discovery, validation, and update logic is handled declaratively in the [nixos-config](https://github.com/kiskaadee/nixos-config) repository.
*   **Cryptographic Secrets**: Credentials are encrypted inside Git using `sops-nix` and `age`, allowing safe storage in public dotfiles repositories.
*   **Smart Change Detection**: A lightweight background Python script (`monitor.py`) checks the public IP every 30 minutes, keeping a local historical log (`ip_history.jsonl`) and triggering updates via `ddclient` *only* when a WAN IP rotation actually occurs.
*   **Clean Repository**: Removed bloat and deprecated files from this service-level repo.

### Negative / Required Actions
*   None. The deployment process is simplified as secrets and services are now handled automatically during the system-wide NixOS activation phase.

## References
*   This decision was implemented in the [nixos-config commits](https://github.com/kiskaadee/nixos-config/commits/main/) under hash `c7acc2b0a3bb262dfd5577989d8d7f0218f2721e` (and subsequent hardening adjustments).
