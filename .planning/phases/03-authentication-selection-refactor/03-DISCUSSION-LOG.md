# Phase 3: Authentication Selection Refactor - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 3-Authentication Selection Refactor
**Areas discussed:** Auth Boundary Shape, Fallback Conditions, Persistence Rules, Mock Proof Matrix

---

## Auth Boundary Shape

### Split Between Auth Selection and Request Signing

| Option | Description | Selected |
|--------|-------------|----------|
| Mode variable plus helpers | Selector sets an auth mode such as `api_key` / `resource_principal`; signing branches later. | yes |
| Separate selector and signer stubs | Add selector plus API-key and RP signer helper shapes now. | |
| Minimal inline split | Preserve most current `_oci_config` flow and only carve out fallback check. | |

**User's choice:** Mode variable plus helpers
**Notes:** Keep Phase 3 small while giving Phase 4 a clear hook.

### Meaning of `_oci_config`

| Option | Description | Selected |
|--------|-------------|----------|
| API-key config only | `_oci_config` keeps its current job: load/persist OCI CLI/API-key settings. | yes |
| Generic auth config | `_oci_config` becomes the top-level selector for both auth modes. | |
| Compatibility wrapper | `_oci_config` delegates internally and returns success for any selected mode. | |

**User's choice:** API-key config only
**Notes:** Add a selector around `_oci_config` rather than expanding the function's meaning.

### Selected Mode Storage

| Option | Description | Selected |
|--------|-------------|----------|
| Private global | Set a private value such as `_oci_auth_mode`. | yes |
| Return string helper | Selector prints the mode and callers capture it. | |
| Separate predicate helpers | Use helpers like `_oci_has_api_key_auth`. | |

**User's choice:** Private global
**Notes:** Avoid command-substitution side effects and match existing shell style.

### Signer Branching in Phase 3

| Option | Description | Selected |
|--------|-------------|----------|
| Mode gate, API-key signer unchanged | Keep current `_signed_request` implementation for API-key mode. | yes |
| Rename current signer to API-key signer now | Move current body into an API-key-specific helper. | |
| Add full dispatch skeleton | Add API-key and RP helper dispatch stubs now. | |

**User's choice:** Mode gate, API-key signer unchanged
**Notes:** RP mode may fail at a clear not-implemented boundary until Phase 4.

---

## Fallback Conditions

### When To Consider Resource Principal

| Option | Description | Selected |
|--------|-------------|----------|
| Only after complete API-key auth fails to configure | Try current OCI CLI/env/account config first. | yes |
| Whenever RP env vars are present | Detect RP early even if API-key config also exists. | |
| Only when no OCI CLI config file/env vars exist at all | Very conservative fallback. | |

**User's choice:** Only after complete API-key auth fails to configure
**Notes:** Matches the milestone contract that existing key-based auth stays primary.

### Partial Key Config With RP Present

| Option | Description | Selected |
|--------|-------------|----------|
| Fallback with a clear key-path diagnostic | Incomplete key config does not block RP fallback. | yes |
| Fail hard on partial key config | Treat partial key settings as intentional misconfiguration. | |
| Fallback only for saved config, fail hard for fresh env vars | More nuanced persisted-vs-current behavior. | |

**User's choice:** Fallback with a clear key-path diagnostic
**Notes:** Missing key-based pieces should remain visible before trying RP.

### RP Availability Signal

| Option | Description | Selected |
|--------|-------------|----------|
| Supported RP version plus required env pointers | Require version and expected token/key/region signals. | yes |
| Any `OCI_RESOURCE_PRINCIPAL_*` variable | Loose detection. | |
| Version only | Single primary switch. | |

**User's choice:** Supported RP version plus required env pointers
**Notes:** Exact current OCI variable names must be verified against official docs during planning/implementation.

### RP Selected Before Phase 4 Signing

| Option | Description | Selected |
|--------|-------------|----------|
| Clear boundary failure | Select RP mode, then fail before signing with a not-implemented message. | yes |
| Treat RP as unavailable until Phase 4 | Detect env but still fail as missing auth. | |
| Soft-success selector only in tests | Keep public add/remove failure looking like missing auth. | |

**User's choice:** Clear boundary failure
**Notes:** Proves Phase 3's fallback boundary without pretending signing works.

---

## Persistence Rules

### Saved `OCI_CLI_*` Config During RP Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve existing saved key config | Do not clear saved values just because this run falls back to RP. | yes |
| Clear incomplete saved key config | Remove unusable saved key config before RP fallback. | |
| Clear only the missing key material entry | Narrower cleanup. | |

**User's choice:** Preserve existing saved key config
**Notes:** Avoid surprising existing users.

### RP Detection Persistence

| Option | Description | Selected |
|--------|-------------|----------|
| Save nothing RP-related | RP env/token/key/version/region signals stay process-local. | yes |
| Save non-secret RP version/region only | Persist debugging metadata. | |
| Save a boolean that RP was detected | Persist a detection marker. | |

**User's choice:** Save nothing RP-related
**Notes:** Matches the security contract and keeps Phase 4 clean.

### Key-Path Diagnostics

| Option | Description | Selected |
|--------|-------------|----------|
| Process-local message only | Collect missing key-path reasons privately and print in the failure/fallback path. | yes |
| Debug log only | Put detail behind `_debug`. | |
| Persist last failure reason | Store a postmortem trail. | |

**User's choice:** Process-local message only
**Notes:** Useful diagnostics without account config churn.

### Both API-Key and RP Present

| Option | Description | Selected |
|--------|-------------|----------|
| Use and persist API-key path as today; ignore RP except secure/debug trace if needed | API-key wins; RP is not saved or normal-logged. | yes |
| Use API-key but log that RP was also present | More transparent normal output. | |
| Use API-key and clear RP-related env-derived state variables | Internal cleanup. | |

**User's choice:** Use and persist API-key path as today; ignore RP except secure/debug trace if needed
**Notes:** Preserves current behavior.

---

## Mock Proof Matrix

### Public-Path Cases

| Option | Description | Selected |
|--------|-------------|----------|
| API-key success, partial-key-to-RP boundary, missing-all-auth failure, API-key-wins-over-RP | Public proof without Phase 4 signing. | yes |
| Only selector helper tests plus existing API-key public path | Smaller matrix. | |
| Full public matrix for add and remove across every auth state | Exhaustive matrix. | |

**User's choice:** API-key success, partial-key-to-RP boundary, missing-all-auth failure, API-key-wins-over-RP
**Notes:** Covers the auth selection contract without implementing RP signing.

### Remove Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| One focused remove smoke case | Main matrix stays on add, but remove proves it uses the selector. | yes |
| Mirror every add case for remove | Exhaustive remove matrix. | |
| No new remove case | Rely on Phase 2 symmetry tests. | |

**User's choice:** One focused remove smoke case
**Notes:** Catches path drift without doubling the suite.

### RP Fallback Boundary Assertions

| Option | Description | Selected |
|--------|-------------|----------|
| Public failure plus internal mode/log facts | Assert failure before PATCH, RP mode selected, and no RP persistence. | yes |
| Internal helper only | Assert selector returns RP mode. | |
| Fake successful RP PATCH | Pretend RP signing works. | |

**User's choice:** Public failure plus internal mode/log facts
**Notes:** Proves behavior without fake signing.

### Diagnostic Wording Strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Stable substrings only | Assert durable phrases rather than whole messages. | yes |
| Exact messages | Stronger UX contract but brittle. | |
| Return/status only | Least brittle but weak for AUTH-03. | |

**User's choice:** Stable substrings only
**Notes:** Protects meaningful diagnostics without brittle shell tests.

---

## the agent's Discretion

- Exact helper names.
- Whether the selector is one helper or a small helper cluster.
- Exact stable diagnostic phrasing.
- Exact current OCI resource-principal version handling after checking official docs.

## Deferred Ideas

- Resource-principal Authorization header construction and signing belongs to Phase 4.
- Live OCI resource-principal smoke testing belongs to later UAT/final verification.
