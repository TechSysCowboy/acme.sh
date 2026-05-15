---
phase: 03
slug: authentication-selection-refactor
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-15
completed: 2026-05-15
---

# Phase 03 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | POSIX shell mock harness |
| **Config file** | none - `test/dns_oci_mock.sh` is self-contained |
| **Quick run command** | `CASE=<case-list> sh test/dns_oci_mock.sh` |
| **Full suite command** | `sh test/dns_oci_mock.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task-specific `CASE=... sh test/dns_oci_mock.sh`
- **After every plan wave:** Run `sh test/dns_oci_mock.sh`
- **Before `$gsd-verify-work`:** Full suite, ShellCheck, and shfmt must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 03-01 | 1 | AUTH-01, AUTH-02 | T-03-01 / T-03-02 | selector does not leak secrets | shell | `CASE=le_test_oci_auth_api_key,le_test_oci_auth_resource_principal_detected_boundary sh test/dns_oci_mock.sh` | yes | pass |
| 03-01-02 | 03-01 | 1 | AUTH-01, AUTH-02, AUTH-03 | T-03-01 / T-03-03 | RP boundary fails before signing/PATCH | shell | `CASE=le_test_oci_auth_resource_principal_detected_boundary,le_test_oci_auth_partial_key_falls_back_to_resource_principal sh test/dns_oci_mock.sh` | yes | pass |
| 03-02-01 | 03-02 | 2 | AUTH-01, AUTH-02 | T-03-04 / T-03-05 | no RP persistence | shell | `CASE=le_test_oci_auth_api_key_wins_over_resource_principal,le_test_oci_auth_resource_principal_does_not_persist sh test/dns_oci_mock.sh` | yes | pass |
| 03-02-02 | 03-02 | 2 | AUTH-01, AUTH-03 | T-03-04 | existing OCI CLI config/env persistence preserved | shell | `CASE=le_test_oci_auth_api_key,le_test_oci_auth_oci_cli_config_file_primary,le_test_oci_auth_missing_reports_both_paths sh test/dns_oci_mock.sh` | yes | pass |
| 03-03-01 | 03-03 | 3 | AUTH-01, AUTH-02, AUTH-03 | T-03-06 / T-03-07 | full public-path matrix is credential-free | shell | `sh test/dns_oci_mock.sh` | yes | pass |
| 03-03-02 | 03-03 | 3 | AUTH-01, AUTH-02, AUTH-03 | T-03-07 | static gates and formatting clean | static | `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh` | yes | pass |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All Phase 3 behaviors have automated verification. Live OCI and OCI-hosted
resource-principal smoke checks remain deferred out of v1 Phase 3 scope.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete from `03-VERIFICATION.md` and audit rerun evidence.
