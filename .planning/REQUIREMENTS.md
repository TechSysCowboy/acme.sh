# Requirements: OCI DNS Subzones and Resource Principal Auth

**Defined:** 2026-05-15
**Core Value:** OCI DNS validation must choose the right zone and authenticate safely without breaking existing key-based OCI users.

## v1 Requirements

### Delegated Zone Discovery

- [x] **ZONE-01**: Operator can issue a DNS-01 certificate for a delegated subzone when the most specific accessible OCI DNS zone matches the challenge FQDN.
- [x] **ZONE-02**: Operator can still issue through the parent OCI DNS zone when no delegated subzone is accessible and the parent zone is accessible.
- [x] **ZONE-03**: Operator receives a clear failure when no accessible OCI DNS zone matches the challenge FQDN.

### TXT Record Payloads

- [ ] **TXT-01**: `dns_oci_add` sends the TXT record domain relative to the selected OCI DNS zone for parent-zone, delegated-subzone, and wildcard challenge names.
- [ ] **TXT-02**: `dns_oci_rm` removes the same relative TXT record that `dns_oci_add` created for parent-zone, delegated-subzone, and wildcard challenge names.
- [x] **TXT-03**: Add/remove success and failure messages identify the selected record name without exposing secret material.

### Authentication Selection

- [ ] **AUTH-01**: Existing OCI CLI config and `OCI_CLI_*` API-key authentication remains the primary path when complete key-based configuration is present.
- [ ] **AUTH-02**: Resource principal authentication is attempted only when key-based OCI authentication is unavailable and resource principal environment configuration is present.
- [ ] **AUTH-03**: Missing or incomplete authentication configuration fails with messages that distinguish key-based configuration problems from resource principal configuration problems.

### Resource Principal Signing

- [ ] **RP-01**: Resource principal signing reads session token, private key, region, and version data from OCI resource-principal environment variables or their referenced files.
- [ ] **RP-02**: Resource principal request signing uses the OCI session token and ephemeral private key for OCI DNS API requests without requiring tenancy/user/fingerprint API-key credentials.
- [ ] **RP-03**: Ephemeral resource principal session tokens, private keys, and authorization headers are never saved to acme.sh account/domain config.
- [ ] **RP-04**: Resource principal secrets and derived authorization material are logged only through secure debug helpers.

### Documentation and Verification

- [ ] **DOC-01**: OCI DNS provider metadata documents authentication order, supported resource principal variables, delegated-subzone behavior, and required OCI policies.
- [ ] **DOC-02**: User-facing docs explain how to configure OCI DNS with existing API-key auth and with resource principal auth.
- [x] **TEST-01**: Mocked shell-level tests cover longest-match zone discovery and relative TXT payload construction without live OCI DNS calls.
- [x] **TEST-02**: Mocked shell-level tests cover key-based auth, resource-principal fallback, missing-auth failures, and secure logging boundaries.
- [ ] **TEST-03**: Static verification runs ShellCheck and shfmt against the changed OCI hook and any added test harness files.

## v2 Requirements

Deferred to future release. Tracked but not in the current roadmap.

### Live OCI Validation

- **LIVE-01**: Operator can run an optional live OCI DNS smoke test against a disposable zone.
- **LIVE-02**: Maintainers can run OCI resource principal validation inside an OCI-hosted workload during release qualification.

### Broader Provider Quality

- **PROV-01**: DNS provider hooks have a shared conformance harness for zone discovery, TXT add/remove payloads, credential persistence, and secure logging.
- **PROV-02**: OCI DNS hook behavior is represented in upstream acmetest-style integration coverage when provider secrets are available.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rewriting the generic DNS provider hook system | The milestone is scoped to `dnsapi/dns_oci.sh` and narrowly needed docs/tests. |
| Making resource principal auth preferred over configured API-key auth | Existing OCI users must keep their current behavior. |
| Requiring live OCI credentials for v1 completion | v1 readiness is mocked shell-level proof plus static shell validation. |
| Adding a runtime SDK or language package manager | acme.sh DNS hooks must remain POSIX shell and use existing helpers. |
| Fixing unrelated provider or CI concerns | These are real concerns but would expand the OCI hook milestone beyond its goal. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TEST-01 | Phase 1 | Complete |
| TEST-02 | Phase 1 | Complete |
| ZONE-01 | Phase 2 | Complete |
| ZONE-02 | Phase 2 | Complete |
| ZONE-03 | Phase 2 | Complete |
| TXT-01 | Phase 2 | Pending |
| TXT-02 | Phase 2 | Pending |
| TXT-03 | Phase 2 | Complete |
| AUTH-01 | Phase 3 | Pending |
| AUTH-02 | Phase 3 | Pending |
| AUTH-03 | Phase 3 | Pending |
| RP-01 | Phase 4 | Pending |
| RP-02 | Phase 4 | Pending |
| RP-03 | Phase 4 | Pending |
| RP-04 | Phase 4 | Pending |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 5 | Pending |
| TEST-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-05-15*
*Last updated: 2026-05-15 after milestone v1.0 initialization*
