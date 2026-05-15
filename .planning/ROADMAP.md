# Roadmap: OCI DNS Subzones and Resource Principal Auth

## Overview

This milestone upgrades the existing OCI DNS provider hook in place. The path is
deliberately narrow: first make the current behavior testable without live OCI
calls, then prove delegated-zone selection and TXT payload construction, then
separate authentication selection from request signing, then add resource
principal signing, and finally document and verify the complete provider surface.

## Milestones

### v1.0 OCI DNS Subzones and Resource Principal Auth (In Progress)

**Milestone Goal:** Make `dnsapi/dns_oci.sh` correctly handle delegated OCI DNS
subzones and support keyless OCI resource-principal auth without breaking current
OCI CLI/API-key users.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: OCI Hook Characterization and Test Harness** - Create a local mocked proof harness for the OCI DNS hook.
- [x] **Phase 2: Delegated Zone Discovery and TXT Payloads** - Implement and prove longest-match zone discovery plus relative TXT payloads. (completed 2026-05-14)
- [ ] **Phase 3: Authentication Selection Refactor** - Preserve current OCI API-key auth while creating a clean fallback point for resource principal auth.
- [ ] **Phase 4: Resource Principal Signing** - Add secure resource-principal signing for OCI DNS API requests.
- [ ] **Phase 5: Documentation and Release Verification** - Document behavior, run static checks, and capture final mocked proof.

## Phase Details

### Phase 1: OCI Hook Characterization and Test Harness
**Goal:** Create a mocked shell-level harness that can exercise `dnsapi/dns_oci.sh` behavior without live OCI DNS calls or credentials.
**Depends on:** Nothing (first phase)
**Requirements:** TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. Mocked tests can source `dnsapi/dns_oci.sh` and intercept `_signed_request`, `_get`, `_post`, account config helpers, and debug helpers.
  2. Existing parent-zone behavior is captured before functional changes are made.
  3. Auth branch behavior can be tested without reading real OCI config, tokens, or private keys.
  4. The harness is small, POSIX-shell friendly, and does not introduce a runtime package manager.
**Plans:** 3 plans

Plans:
- [x] 01-01: Build a minimal OCI hook shell test harness.
- [x] 01-02: Add characterization tests for current zone discovery and TXT add/remove paths.
- [x] 01-03: Add auth-branch fixtures and secure-debug assertions.

### Phase 2: Delegated Zone Discovery and TXT Payloads
**Goal:** Make `_get_zone`, `dns_oci_add`, and `dns_oci_rm` select the longest accessible OCI DNS zone and construct TXT record names relative to that selected zone.
**Depends on:** Phase 1
**Requirements:** ZONE-01, ZONE-02, ZONE-03, TXT-01, TXT-02, TXT-03
**Success Criteria** (what must be TRUE):
  1. A challenge for `_acme-challenge.x.domain.com` selects `x.domain.com` before `domain.com` when both are accessible.
  2. A challenge falls back to `domain.com` when `x.domain.com` is inaccessible and `domain.com` is accessible.
  3. Add and remove payloads use the same relative TXT record domain for parent, delegated-subzone, and wildcard cases.
  4. No-zone failures remain explicit and do not attempt record mutation.
**Plans:** 3/3 plans complete

Plans:
- [x] 02-01: Tighten and document longest-match zone discovery behavior.
- [x] 02-02: Normalize relative TXT domain construction for add and remove.
- [x] 02-03: Expand mocked coverage for delegated subzones, wildcard names, fallback, and no-zone errors.

### Phase 3: Authentication Selection Refactor
**Goal:** Separate OCI authentication selection from request signing so existing API-key auth stays first and resource principal auth has a clear fallback boundary.
**Depends on:** Phase 2
**Requirements:** AUTH-01, AUTH-02, AUTH-03
**Success Criteria** (what must be TRUE):
  1. Complete OCI CLI config or `OCI_CLI_*` API-key configuration continues to sign requests through the existing key-based path.
  2. Resource principal auth is considered only after key-based auth cannot be configured.
  3. Missing-auth errors explain which path failed and why.
  4. Account config persistence remains limited to durable key-based settings.
**Plans:** 3 plans

Plans:
- [x] 03-01: Extract auth-mode selection from `_oci_config` without changing the public hook contract.
- [ ] 03-02: Preserve OCI CLI config and `OCI_CLI_*` persistence semantics.
- [ ] 03-03: Add missing-auth and fallback tests for key-based and resource-principal paths.

### Phase 4: Resource Principal Signing
**Goal:** Implement OCI resource principal request signing using OCI-provided session token and ephemeral private key material while keeping secrets out of persisted config and normal logs.
**Depends on:** Phase 3
**Requirements:** RP-01, RP-02, RP-03, RP-04
**Success Criteria** (what must be TRUE):
  1. The hook detects supported OCI resource principal environment configuration and reads referenced token/key material only for the current operation.
  2. OCI DNS GET and PATCH requests can be signed with resource principal session-token credentials.
  3. Resource principal token, private key, and Authorization header values are never written to account/domain config.
  4. Sensitive signing values use `_secure_debug*` only.
**Plans:** 4 plans

Plans:
- [ ] 04-01: Add resource principal environment detection and token/key loading.
- [ ] 04-02: Add resource principal Authorization header construction for OCI DNS requests.
- [ ] 04-03: Keep ephemeral material process-local and out of account/domain config.
- [ ] 04-04: Add mocked resource-principal signing and secure-logging tests.

### Phase 5: Documentation and Release Verification
**Goal:** Update provider metadata/docs and run the final static and mocked verification suite for the OCI DNS hook.
**Depends on:** Phase 4
**Requirements:** DOC-01, DOC-02, TEST-03
**Success Criteria** (what must be TRUE):
  1. OCI DNS provider metadata documents API-key auth, resource principal fallback, delegated subzones, and policy expectations.
  2. User-facing docs describe setup for existing key-based users and OCI-hosted resource-principal workloads.
  3. ShellCheck and shfmt pass for changed hook/test/doc-support shell files.
  4. The mocked OCI hook suite passes and the verification record names any live OCI checks intentionally deferred.
**Plans:** 3 plans

Plans:
- [ ] 05-01: Update OCI provider metadata and user-facing documentation.
- [ ] 05-02: Run shfmt and ShellCheck against the OCI hook and added shell test support.
- [ ] 05-03: Capture final mocked proof and deferred live-validation notes.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. OCI Hook Characterization and Test Harness | 3/3 | Complete | 2026-05-14 |
| 2. Delegated Zone Discovery and TXT Payloads | 3/3 | Complete    | 2026-05-14 |
| 3. Authentication Selection Refactor | 0/3 | Not started | - |
| 4. Resource Principal Signing | 0/4 | Not started | - |
| 5. Documentation and Release Verification | 0/3 | Not started | - |
