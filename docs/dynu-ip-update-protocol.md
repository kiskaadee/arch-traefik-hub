# Dynu IP Monitor & Updater (Design / Architecture)

## Problem Definition

Maintain accurate DNS A records in Dynu despite:

* dynamic public IPs
* unreliable external IP providers
* transient network failures

### Success Criteria

* Correct IP is eventually reflected in Dynu
* No invalid or private IPs are ever persisted
* No redundant updates (avoid Dynu abuse flags)
* Safe under concurrent or repeated execution

### Non-Goals

* IPv6 support
* complex DNS record management
* real-time updates (polling only)

---

## Core Design Decisions

### 1. Probe Model (Not a Daemon)

The system runs periodically instead of continuously.

**Why:**

* simpler lifecycle (systemd handles scheduling)
* naturally idempotent
* avoids long-lived state bugs

---

### 2. Dual-Source Discovery

* Primary: DNS (`dig`)
* Fallback: HTTP providers

**Why:**

* DNS is faster and lightweight
* HTTP provides redundancy when DNS fails

---

### 3. Explicit Degradation Model

Failures are classified:

* `degraded` → fallback used, system still functional
* `error` → no valid IP, abort

**Why:**

* improves observability
* avoids silent failure modes

---

### 4. Strict Validation Pipeline

Every candidate IP must pass:

1. format validation (regex + bounds)
2. public IP validation (no RFC1918 / CGNAT)

Validation is applied:

* per-provider
* after discovery (final gate)

**Why:**

* prevents poisoning state with invalid data
* enforces invariant: *state must always be valid*

---

### 5. State as a Consistency Contract

`last_ip` represents:

> “The last IP successfully synchronized with Dynu”

It is updated **only after**:

* HTTP 200
* valid Dynu semantic response (`good` / `nochg`)

**Why:**

* avoids divergence between local state and remote DNS

---

### 6. Atomic Writes

State updates use:

```
write → temp file → mv
```

**Why:**

* guarantees consistency even on crash/interruption
* `mv` is atomic on same filesystem

---

### 7. Concurrency Strategy

Non-blocking lock via `flock`.

If locked:

```
skip execution
```

**Why:**

* prevents overlapping runs
* avoids queue buildup from timers
* ensures last execution “wins”

---

### 8. Deferred Credential Processing

Password hashing happens only when update is needed.

**Why:**

* avoids unnecessary computation
* keeps fast-path (no-change) minimal

---

### 9. Transport vs Semantic Validation

Two layers:

1. Transport → HTTP status must be `200`
2. Semantic → response must start with `good` or `nochg`

**Why:**

* separates network failures from API logic failures
* improves debugging clarity

---

### 10. Structured Logging

All logs follow:

```
event=... reason=... cause=...
```

**Why:**

* machine-filterable via journald
* consistent debugging surface

---

## Trade-offs

### Bash vs Higher-Level Language

**Chosen:** Bash

**Pros:**

* zero runtime dependency
* native systemd integration
* simple deployment

**Cons:**

* limited abstractions
* harder error composition
* more manual validation

Given the scope (I/O-bound, small state machine), Bash remains appropriate.

---

## Failure Modes Considered

* DNS unavailable → fallback to HTTP
* HTTP provider failure → rotate providers
* invalid IP returned → rejected
* API failure → no state mutation
* concurrent execution → skipped
* partial execution → no persistent side effects

---

## Key Invariants

* No invalid IP is ever persisted
* State reflects only successful external sync
* Script is safe to run repeatedly
* System is eventually consistent, not instantly consistent
