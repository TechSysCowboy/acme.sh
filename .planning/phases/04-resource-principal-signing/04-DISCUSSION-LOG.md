# Phase 4: Resource Principal Signing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 04-Resource Principal Signing
**Areas discussed:** Material Loading Contract, Signer Shape, Failure And Logging Policy, Verification Bar

---

## Material Loading Contract

### RPST And Private PEM Source Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Path-first with inline fallback | If the env value points to an existing file, read it; otherwise treat it as inline RPST or PEM content. | Yes |
| File paths only | Require both env vars to be readable files; simpler and closest to OCI Functions docs. | |
| Paths only for PEM, either for RPST | Support inline token but not inline private PEM. | |

**User's choice:** Path-first with inline fallback.
**Notes:** The decision aligns with the current OCI SDK v2.2 contract while still supporting OCI Functions file-backed runtime behavior.

### Material Freshness

| Option | Description | Selected |
|--------|-------------|----------|
| Read per signed request | Each GET/PATCH reads current file contents if path-backed, so OCI token rotation can be picked up without caching secrets. | Yes |
| Read once per hook call | Load at auth selection and reuse for zone lookup and patch. | |
| Cache in private globals | Fastest, but easiest to leak or reuse stale secret material. | |

**User's choice:** Read per signed request.
**Notes:** No cached token or private-key globals.

### Passphrase Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Defer passphrase | Support unencrypted private PEM now; report unsupported passphrase if the env var is set. | |
| Support passphrase now | Read path-or-inline passphrase and wire it into signing in this phase. | Yes |
| Ignore passphrase env | Keep the phase smaller but risk confusing encrypted-key failures. | |

**User's choice:** Support passphrase now.
**Notes:** `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` follows the same path-first, inline-fallback shape.

### Loading Failure Diagnostics

| Option | Description | Selected |
|--------|-------------|----------|
| Variable names only | Normal errors name relevant env vars and failure class, but never values, paths, token fragments, key material, or passphrase. | Yes |
| Include file paths | Normal errors include unreadable paths to help operators fix mounts and permissions. | |
| Generic failure only | Say RP material could not be loaded without naming which variable failed. | |

**User's choice:** Variable names only.
**Notes:** Normal logs stay strict even when paths would help diagnosis.

---

## Signer Shape

### Helper Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Dispatcher plus private helpers | Keep `_signed_request` as the public boundary and dispatch to private API-key/RP helpers. | Yes |
| Inline branch in `_signed_request` | Put RP signing logic directly inside the existing function. | |
| Separate new RP entry point | Add a new request function and make callers choose the signer. | |

**User's choice:** Dispatcher plus private helpers.
**Notes:** `_signed_request` remains the chokepoint for zone `GET` and records `PATCH`.

### Authorization KeyId

| Option | Description | Selected |
|--------|-------------|----------|
| `ST$<rpst>` | Match OCI SDK/security-token signer behavior and Oracle custom Functions example. | Yes |
| JWT claims derived ID | Parse RPST claims and construct a custom keyId. | |
| Existing API-key shape | Reuse tenancy/user/fingerprint shape. | |

**User's choice:** `ST$<rpst>`.
**Notes:** Do not derive a custom identifier from token claims.

### Headers To Sign

| Option | Description | Selected |
|--------|-------------|----------|
| Same standard OCI header set | `date`, `(request-target)`, `host` for GET; add body hash/type/length for PATCH. | Yes |
| Minimal GET/PATCH headers only | Sign the smallest possible header set. | |
| Use `x-date` instead of `date` | Valid per OCI docs but diverges from the existing signer. | |

**User's choice:** Same standard OCI header set.
**Notes:** Keep the same signing shape as the existing API-key signer.

### Signing Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse `_sign` with temp file | Write ephemeral PEM to `_mktemp`, sign through the existing pattern, and remove the temp file. | Yes |
| Pipe key directly to OpenSSL | Avoid temp files but add a new lower-level signing path. | |
| Require external OCI tooling | Shell out to OCI CLI or SDK signer. | |

**User's choice:** Reuse `_sign` with temp file.
**Notes:** No new runtime dependency. Passphrase support may require a minimal wrapper around the same OpenSSL pattern.

---

## Failure And Logging Policy

### Zone Lookup Failure Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Terminal auth failure | Mark a private auth/signing error flag so zone lookup stops immediately and avoids misleading zone-not-found noise. | Yes |
| Keep existing zone walk | Let GET failures behave like normal not-found responses. | |
| Retry once then stop | Allow one retry for transient token/key file replacement. | |

**User's choice:** Terminal auth failure.
**Notes:** RP load/sign failures should stop the label walk.

### Normal Log Detail

| Option | Description | Selected |
|--------|-------------|----------|
| Mode and variable names only | Normal logs may mention RP mode and env var names, never values, paths, or secret-derived material. | Yes |
| Include non-secret paths | Normal logs may include unreadable token/key/passphrase paths. | |
| No RP details at all | Normal logs only say OCI authentication failed. | |

**User's choice:** Mode and variable names only.
**Notes:** Paths are treated as too sensitive for normal logs.

### Secure Debug Detail

| Option | Description | Selected |
|--------|-------------|----------|
| Sensitive signing internals | `_secure_debug*` may capture RPST, private PEM material, signing string, and Authorization header. | Yes |
| Authorization header only | Keep secure debug narrower. | |
| No RP secrets even in secure debug | Maximum secrecy but harder signature debugging. | |

**User's choice:** Sensitive signing internals.
**Notes:** Normal logs remain clean; secure debug may carry sensitive troubleshooting data.

### Passphrase Failure Diagnostics

| Option | Description | Selected |
|--------|-------------|----------|
| Env-name diagnostic only | Name `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` and failure class, no value/path/detail. | Yes |
| OpenSSL error summary | Include sanitized OpenSSL error class. | |
| Generic signing failure | No passphrase-specific clue. | |

**User's choice:** Env-name diagnostic only.
**Notes:** Avoid raw OpenSSL error detail in normal logs.

---

## Verification Bar

### Signing Correctness Proof

| Option | Description | Selected |
|--------|-------------|----------|
| Mocked exact header/request proof | No live OCI; assert `ST$` keyId, signed headers, signing string, body hash/length, flow, no persistence, and clean logs. | Yes |
| Mocked flow only | Prove GET/PATCH flow and no persistence without exact signature assertions. | |
| Require live OCI smoke | Stronger real-world proof but outside the mocked v1 boundary. | |

**User's choice:** Mocked exact header/request proof.
**Notes:** Live OCI remains out of scope for Phase 4.

### Path Vs Inline Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Both paths and inline | Fixture files plus inline values, including passphrase. | Yes |
| Path fixtures only | Closest to OCI Functions docs and simpler. | |
| Inline fixtures only | Simpler to mock but misses the main production Functions path. | |

**User's choice:** Both paths and inline.
**Notes:** Coverage must include passphrase.

### Refresh Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, per-request refresh | Change file contents between GET and PATCH and assert the later request uses updated material. | Yes |
| No, static fixtures enough | Implementation reads per request, but tests do not simulate rotation. | |
| Only RPST refresh | Prove token rotation but not key rotation. | |

**User's choice:** Yes, per-request refresh.
**Notes:** Tests should cover changed RPST and key material between requests.

### Passphrase Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Success and failure | Encrypted/passphrase-backed signing succeeds; wrong or missing passphrase fails cleanly. | Yes |
| Success only | Prove passphrase can be consumed but skip diagnostics. | |
| Failure only | Prove clean errors but avoid encrypted-key fixture complexity. | |

**User's choice:** Success and failure.
**Notes:** Exact passphrase behavior is part of the Phase 4 verification bar.

---

## the agent's Discretion

- Exact helper names and private flag names.
- Minimal implementation shape for passphrase-backed signing, provided it keeps
  the existing temp-file/OpenSSL pattern and avoids new runtime dependencies.
- Exact stable diagnostic phrasing, provided tests assert durable facts rather
  than brittle full messages.

## Deferred Ideas

- Live OCI resource-principal validation in an OCI-hosted workload.
- User-facing documentation and provider metadata updates for resource-principal
  auth and OCI policy expectations.
- Broader DNS-provider conformance coverage.
