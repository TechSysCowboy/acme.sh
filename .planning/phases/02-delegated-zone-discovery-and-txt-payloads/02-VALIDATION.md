---
phase: 02
slug: delegated-zone-discovery-and-txt-payloads
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-15
---

# Phase 02 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | POSIX shell, acmetest-style local script |
| Config file | none |
| Quick run command | `CASE=le_test_oci_parent_fallback sh test/dns_oci_mock.sh` |
| Full suite command | `sh test/dns_oci_mock.sh` |
| Estimated runtime | under 10 seconds |

## Sampling Rate

- After every task commit: run the task-specific `CASE=... sh test/dns_oci_mock.sh`.
- After every plan wave: run `sh test/dns_oci_mock.sh`.
- Before `$gsd-verify-work`: run full harness plus ShellCheck.
- Max feedback latency: 10 seconds for mocked tests.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 02-01 | 1 | ZONE-01, ZONE-02, ZONE-03 | T-02-01 | No live OCI calls; no PATCH on no-zone/authz failure | shell unit | `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard sh test/dns_oci_mock.sh` | yes | pending |
| 02-02-01 | 02-02 | 2 | TXT-01, TXT-02, TXT-03 | T-02-02 | Add/remove use same selected zone and owner | shell unit | `CASE=le_test_oci_add_remove_symmetry,le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh` | yes | pending |
| 02-02-02 | 02-02 | 2 | TXT-01, TXT-02 | T-02-03 | JSON payload remains valid for realistic TXT/domain data | shell unit | `CASE=le_test_oci_txt_value_json_escape,le_test_oci_record_domain_json_escape sh test/dns_oci_mock.sh` | yes | pending |
| 02-03-01 | 02-03 | 3 | ZONE-01, ZONE-02, ZONE-03, TXT-01, TXT-02, TXT-03 | T-02-04 | Full mocked suite remains deterministic and credential-free | shell unit | `sh test/dns_oci_mock.sh` | yes | pending |

## Wave 0 Requirements

Existing infrastructure covers all Phase 2 requirements:

- [x] `test/dns_oci_mock.sh` exists with acmetest-style runner and assertion helpers.
- [x] `test/dns_oci_mock.sh` can source `acme.sh` without executing normal CLI commands.
- [x] `test/dns_oci_mock.sh` can source `dnsapi/dns_oci.sh` and override provider-boundary helpers.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live OCI delegated-zone smoke | v2 LIVE-01 | v1 intentionally avoids live OCI credentials and zones | Not required for Phase 2; capture as deferred UAT evidence later |

## Validation Sign-Off

- [ ] All tasks have automated verify commands.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency under 10 seconds.
- [ ] `nyquist_compliant: true` remains set in frontmatter.

**Approval:** pending
