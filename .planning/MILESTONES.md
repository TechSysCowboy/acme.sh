# Milestones

## v1.0 OCI DNS Subzones and Resource Principal Auth (Shipped: 2026-05-15)

**Delivered:** OCI DNS now supports delegated-subzone discovery and
resource-principal signing while preserving existing API-key users and avoiding
live OCI requirements for v1 proof.

**Phases completed:** 1-5 (5 phases, 16 plans, 49 tasks)

**Key accomplishments:**

- Added a POSIX shell OCI DNS mock harness with safe `acme.sh` loading,
  CASE-selected `le_test_*` cases, and provider-boundary stubs.
- Proved parent, delegated, fallback, no-zone, wildcard, authz, and TXT escaping
  behavior through mocked OCI DNS coverage.
- Preserved OCI CLI/API-key auth as primary while adding a process-local
  resource-principal fallback boundary.
- Implemented resource-principal GET/PATCH signing with request-local token,
  private-key, passphrase, and secure-log handling.
- Updated provider metadata and created wiki-ready OCI DNS guidance for API-key
  and resource-principal operators.
- Captured final release verification with 38 mocked cases, ShellCheck, shfmt,
  docs checks, freshness evidence, and explicit v2 live-validation deferral.

**Stats:**

- 84 files created/modified across code, tests, and planning artifacts.
- 5 phases, 16 plans, 49 tasks.
- 38 mocked OCI shell cases in `test/dns_oci_mock.sh`.
- 1 day from milestone setup to ship.

**Git range:** `fb7cf198` -> `c7aa664f`

**Archived:**

- `.planning/milestones/v1.0-ROADMAP.md`
- `.planning/milestones/v1.0-REQUIREMENTS.md`
- `.planning/milestones/v1.0-MILESTONE-AUDIT.md`

**Known deferred items:** Live OCI DNS mutation and OCI-hosted
resource-principal smoke tests are deferred to v2 (`LIVE-01`, `LIVE-02`).

**What's next:** Start a new milestone with `$gsd-new-milestone` if live OCI
qualification or broader provider conformance work should continue.

---
