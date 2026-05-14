# Phase 1: OCI Hook Characterization and Test Harness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 1-OCI Hook Characterization and Test Harness
**Areas discussed:** Harness shape, Mock boundary, Proof matrix

---

## Harness Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Repo-local acmetest-style harness | Add local shell tests shaped to be portable into `acmetest`; use live `acmetest` as the reference and optional UAT runner. | yes |
| Patch acmetest first | Build the test case in an `acmetest` fork/PR first, then adapt this repo. | |
| No local harness | Only document/run live `acmetest` and rely on code review for mocked behavior. | |

**User's choice:** Repo-local acmetest-style harness.
**Notes:** The user identified `https://github.com/acmesh-official/acmetest` as the unit test reference for acme.sh. Current checked `master` SHA during discussion was `d63b75bc5d02df13ccccef70e3f0a53dc6ef9b8e`.

### Live Smoke Gate

| Option | Description | Selected |
|--------|-------------|----------|
| Required before ship | Do not close v1 until one live OCI DNS run passes. | |
| UAT checkpoint | Mocked tests are the automated gate; live domain smoke is a human/operator checkpoint before final signoff. | yes |
| Document only | Planner documents how to run it, but v1 can close without doing it. | |

**User's choice:** UAT checkpoint.
**Notes:** The user is willing to use a sacrificial domain/subzone for infrequent live testing, but the automated path should remain mocked.

---

## Mock Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Provider boundary | Source `acme.sh` and `dnsapi/dns_oci.sh`, then stub `_signed_request` plus account config helpers. | yes |
| HTTP boundary | Stub `_get` and `_post` so `_signed_request` still runs. | |
| Function boundary | Call private helpers directly and assert strings. | |

**User's choice:** Provider boundary.
**Notes:** This exercises the public provider add/remove path without requiring real OCI or brittle OpenSSL/private-key setup.

---

## Proof Matrix

| Option | Description | Selected |
|--------|-------------|----------|
| Core + edge | Parent zone, delegated subzone, fallback to parent, no-zone failure, add/remove symmetry, API-key auth first, resource-principal fallback, missing-auth failure, and secure-log checks. | yes |
| Minimal core | Parent zone, delegated subzone, add/remove payloads, and API-key auth preservation only. | |
| Exhaustive upfront | Core + edge plus wildcard/base-domain combinations, token/key file variants, malformed config, and simulated OCI errors before implementation starts. | |

**User's choice:** Core + edge.
**Notes:** The matrix should prevent dangerous regressions without turning Phase 1 into the whole OCI implementation.

## the agent's Discretion

- The planner may choose the exact local filename and helper layout if it remains POSIX shell, acmetest-shaped, and portable into upstream acmetest.

## Deferred Ideas

- Upstream the local OCI mocked case into `acmesh-official/acmetest` after the local harness proves useful.
- Consider deeper HTTP-boundary or signing-boundary tests after resource principal signing exists.
