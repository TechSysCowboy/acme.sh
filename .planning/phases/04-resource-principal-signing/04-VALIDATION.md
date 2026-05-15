---
phase: 04
slug: resource-principal-signing
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-15
---

# Phase 04 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | POSIX shell mock harness |
| **Config file** | none - `test/dns_oci_mock.sh` is self-contained |
| **Quick run command** | `CASE=<case-list> sh test/dns_oci_mock.sh` |
| **Full suite command** | `sh test/dns_oci_mock.sh` |
| **Estimated runtime** | under 10 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task-specific `CASE=... sh test/dns_oci_mock.sh`.
- **After every plan wave:** Run `sh test/dns_oci_mock.sh`.
- **Before `$gsd-verify-work`:** Full suite, ShellCheck, and shfmt must be green.
- **Max feedback latency:** 10 seconds for mocked shell tests.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 04-01 | 1 | RP-01, RP-03, RP-04 | T-04-01 / T-04-02 | loader handles inline/path material without persistence | shell | `CASE=le_test_oci_rp_loads_inline_material,le_test_oci_rp_loads_path_material sh test/dns_oci_mock.sh` | yes | pending |
| 04-01-02 | 04-01 | 1 | RP-01, RP-04 | T-04-03 | missing/unsupported RP config is env-name-only | shell | `CASE=le_test_oci_rp_missing_material_reports_env_names,le_test_oci_rp_unsupported_version_reports_env_name sh test/dns_oci_mock.sh` | yes | pending |
| 04-02-01 | 04-02 | 2 | RP-02, RP-04 | T-04-04 / T-04-05 | GET signer uses `ST$` keyId and secure debug only | shell | `CASE=le_test_oci_rp_signs_get_with_st_key_id sh test/dns_oci_mock.sh` | yes | pending |
| 04-02-02 | 04-02 | 2 | RP-02, RP-04 | T-04-06 | PATCH signer includes body hash/type/length | shell | `CASE=le_test_oci_rp_signs_patch_body_headers sh test/dns_oci_mock.sh` | yes | pending |
| 04-03-01 | 04-03 | 3 | RP-01, RP-03, RP-04 | T-04-07 / T-04-08 | path-backed material refreshes per request and remains unpersisted | shell | `CASE=le_test_oci_rp_refreshes_path_material_between_requests,le_test_oci_rp_does_not_persist_or_normal_log_material sh test/dns_oci_mock.sh` | yes | pending |
| 04-03-02 | 04-03 | 3 | RP-01, RP-02, RP-04 | T-04-09 | load/sign failures stop zone fallback and hide secrets | shell | `CASE=le_test_oci_rp_signing_failure_stops_zone_fallback sh test/dns_oci_mock.sh` | yes | pending |
| 04-04-01 | 04-04 | 4 | RP-01, RP-02, RP-04 | T-04-10 | passphrase success/failure is covered with clean diagnostics | shell | `CASE=le_test_oci_rp_passphrase_success,le_test_oci_rp_passphrase_failure_is_clean sh test/dns_oci_mock.sh` | yes | pending |
| 04-04-02 | 04-04 | 4 | RP-01, RP-02, RP-03, RP-04 | T-04-11 | full matrix and static gates prove no regression | shell/static | `sh test/dns_oci_mock.sh` plus ShellCheck/shfmt commands | yes | pending |

---

## Wave 0 Requirements

Existing Phase 1-3 infrastructure covers test execution, mock captures,
selected-zone flow, auth-selection flow, and static shell gates. Phase 4 adds
only lower signing-boundary stubs for exact Authorization proof.

---

## Manual-Only Verifications

None required for Phase 4. Live OCI resource-principal validation remains out
of scope for v1 and is deferred to later release qualification.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
