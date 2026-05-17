# ADR 001: Removal of Localhost Routers for Development Freedom

*   **Status**: Accepted & Implemented
*   **Date**: 2026-05-17
*   **Decider**: User & Gemini CLI

## Context
Initially, we implemented `*.localhost` routers in Traefik to allow local access to services (e.g., `jellyfin.localhost`) without traversing the public internet. The goal was to provide a "fast lane" for local management.

However, two major technical hurdles were encountered:
1.  **SSL/TLS Restrictions**: Public Certificate Authorities (like Let's Encrypt) cannot issue certificates for the `.localhost` TLD. This resulted in "Insecure" warnings in browsers and the need to manage a local CA (like `mkcert`) or accept self-signed certificates.
2.  **SSO (Cookie) Limitations**: Browsers enforce strict domain matching for cookies. Our Authelia instance is configured for `arch-services.mywire.org`. Browsers refuse to send these session cookies to `*.localhost` domains. This caused an infinite redirect loop or authentication errors when accessing services locally.
3.  **Namespace Pollution**: Using `*.localhost` in Traefik intercepts traffic that might be needed for other developer workflows (e.g., running undeployed apps, Vite dev servers, or testing environments that default to `localhost`).

## Decision
We decided to **deprecate and remove all `*.localhost` routers** from the Traefik configuration across all services. 

Instead of dedicated local hostnames, we will use the **Public Domain + Local IP** strategy for local access.

## Consequences

### Positive
*   **Seamless SSO**: Authelia SSO works perfectly because the browser sees the public domain (`*.arch-services.mywire.org`) and sends the correct cookies.
*   **Valid SSL**: Traefik serves the real Let's Encrypt wildcard certificate, providing "Green Lock" security in browsers without manual certificate management.
*   **Clean Namespace**: The `.localhost` TLD is now entirely free for other developer-specific tools and testing.
*   **Local Speed**: When configured correctly via `/etc/hosts`, traffic never leaves the local machine, maintaining the speed benefits of the previous implementation.

### Negative / Required Actions
*   **Manual Configuration**: Users must manually update their machine's `/etc/hosts` file to point the public subdomains to `127.0.0.1`.
*   **SSO Requirement**: Local access now requires the same Authelia authentication as public access (unless explicitly bypassed in the public router, which is not recommended for security).

## Implementation Detail
To access services locally with this architecture, add the following to your `/etc/hosts`:
```text
127.0.0.1  traefik.arch-services.mywire.org auth.arch-services.mywire.org jellyfin.arch-services.mywire.org gitea.arch-services.mywire.org excalidraw.arch-services.mywire.org homepage.arch-services.mywire.org mermaid.arch-services.mywire.org ollama.arch-services.mywire.org learning.arch-services.mywire.org logs.arch-services.mywire.org portainer.arch-services.mywire.org
```
