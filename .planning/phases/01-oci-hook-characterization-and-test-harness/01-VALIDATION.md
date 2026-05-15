---
phase: 01
slug: oci-hook-characterization-and-test-harness
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-15
completed: 2026-05-15
---

# Phase 01 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | POSIX shell, acmetest-style local script |
| Config file | none |
| Quick run command | `CASE=le_test_oci_harness_bootstrap sh test/dns_oci_mock.sh` |
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
| 01-01-01 | 01-01 | 1 | TEST-01, TEST-02 | T-01-01 | No live OCI calls during bootstrap | shell unit | `CASE=le_test_oci_harness_bootstrap sh test/dns_oci_mock.sh` | yes | pass |
| 01-02-01 | 01-02 | 2 | TEST-01 | T-01-02 | Mocked TXT mutation only | shell unit | `CASE=le_test_oci_parent_zone_add,le_test_oci_delegated_zone_add,le_test_oci_parent_fallback,le_test_oci_no_zone_failure,le_test_oci_add_remove_symmetry sh test/dns_oci_mock.sh` | yes | pass |
| 01-02-02 | 01-02 | 2 | TEST-01 | T-01-03 | Return-field parse has no stray artifact | shell unit | `CASE=le_test_oci_signed_request_return_field sh test/dns_oci_mock.sh` | yes | pass |
| 01-03-01 | 01-03 | 3 | TEST-02 | T-01-04 | No real config, key, or token reads | shell unit | `CASE=le_test_oci_auth_api_key,le_test_oci_auth_missing,le_test_oci_auth_resource_principal_current_state sh test/dns_oci_mock.sh` | yes | pass |
| 01-03-02 | 01-03 | 3 | TEST-02 | T-01-05 | Secrets only in secure debug capture | shell unit | `CASE=le_test_oci_secure_debug_boundaries sh test/dns_oci_mock.sh` | yes | pass |

## Wave 0 Requirements

- [x] `test/dns_oci_mock.sh` exists with acmetest-style runner and assertion helpers.
- [x] `test/dns_oci_mock.sh` can source `acme.sh` without executing normal CLI commands.
- [x] `test/dns_oci_mock.sh` can source `dnsapi/dns_oci.sh` and override provider-boundary helpers.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live OCI DNS smoke | v2 LIVE-01 | Phase 1 intentionally avoids real OCI credentials and zones | Not required for Phase 1; capture as deferred UAT evidence later |

## Validation Sign-Off

- [x] All tasks have automated verify commands.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency under 10 seconds.
- [x] `nyquist_compliant: true` remains set in frontmatter.

**Approval:** complete from `01-VERIFICATION.md` and audit rerun evidence.
