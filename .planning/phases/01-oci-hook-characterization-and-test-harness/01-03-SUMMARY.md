---
phase: 01-oci-hook-characterization-and-test-harness
plan: 03
subsystem: testing
tags: [oci, auth, resource-principal, secure-debug, shell]
requires:
  - phase: 01-oci-hook-characterization-and-test-harness
    provides: Mocked OCI DNS hook harness and zone/TXT cases
provides:
  - API-key auth fixture that reaches mocked DNS PATCH without real OCI config
  - Missing-auth failure fixture with no PATCH request
  - Resource-principal current-state fixture for Phase 3/4 fallback work
  - Secure-debug boundary assertions for dummy key, RPST, Authorization, and ST token markers
affects: [dnsapi/dns_oci.sh, Phase 3, Phase 4, Phase 5]
tech-stack:
  added: []
  patterns: [credential-free auth fixtures, normal-vs-secure debug capture]
key-files:
  created: []
  modified: [test/dns_oci_mock.sh]
key-decisions:
  - "Missing-auth and resource-principal current-state tests must fail before PATCH until fallback support is implemented."
  - "The harness resets HOME to a temp mock directory so tests cannot read a real OCI CLI config."
patterns-established:
  - "Resource principal fixture names the Phase 3/4 flip point explicitly."
  - "Normal debug and secure debug captures are asserted separately."
requirements-completed: [TEST-02]
duration: 3 min
completed: 2026-05-14
---

# Phase 1 Plan 3: Auth and Secure-Debug Fixture Summary

**Credential-free OCI auth and secure-debug fixtures covering API-key success, missing auth, resource-principal current failure, and sensitive-log boundaries**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-14T17:43:16Z
- **Completed:** 2026-05-14T17:45:51Z
- **Tasks:** 4
- **Files modified:** 1

## Accomplishments

- Added `le_test_oci_auth_api_key` to prove dummy `OCI_CLI_*` API-key auth reaches a mocked PATCH without reading real OCI config.
- Added `le_test_oci_auth_missing` to prove missing key material fails before any PATCH request is attempted.
- Added `le_test_oci_auth_resource_principal_current_state` to characterize current resource-principal-only failure and mark the Phase 3/4 fixture flip point.
- Added `le_test_oci_secure_debug_boundaries` to prove dummy private key, RPST, Authorization, and `ST$` markers stay out of normal debug capture and appear only in secure debug capture.

## Task Commits

1. **Task 1: Add key-based and missing-auth cases** - `b0353579` (test)
2. **Task 2: Add resource-principal current-state fixture** - `b0353579` (test)
3. **Task 3: Add secure-debug boundary assertions** - `b0353579` (test)
4. **Task 4: Run full auth/security suite** - no code commit; verification only

**Plan metadata:** pending metadata commit

## Files Created/Modified

- `test/dns_oci_mock.sh` - Adds API-key, missing-auth, resource-principal current-state, and secure-debug boundary cases.

## Decisions Made

- The resource-principal-only fixture intentionally asserts current failure, not fallback success, because Phase 1 does not implement resource principal auth.
- The harness points `HOME` to its temp mock directory on reset to avoid accidental reads from a developer's real `~/.oci/config`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- ShellCheck flagged a single-quoted dummy `ST$...` fixture as variable-looking text. The test now builds that literal with an escaped `$` inside a double-quoted assignment.

## Verification

- PASS: `CASE=le_test_oci_auth_api_key,le_test_oci_auth_missing,le_test_oci_auth_resource_principal_current_state,le_test_oci_secure_debug_boundaries sh test/dns_oci_mock.sh`
- PASS: `sh test/dns_oci_mock.sh`
- PASS: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- SKIPPED: local `shfmt` is absent; Phase 1 remains mocked-only and records formatter pin cleanup for Phase 5.

## Self-Check: PASSED

- API-key auth reaches a mocked PATCH and does not read real OCI config.
- Missing-auth and resource-principal-only current-state cases fail before PATCH.
- Resource principal variables are present in the fixture and are not saved through `_saveaccountconf_mutable`.
- Normal debug capture excludes `TEST_DUMMY_PRIVATE_KEY`, `TEST_DUMMY_RPST`, `Authorization:`, and `ST$`; secure debug capture records those controlled fixtures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 1 is ready for phase-level verification. Live OCI DNS smoke remains deferred UAT evidence; the automated gate is the mocked harness plus ShellCheck.

---
*Phase: 01-oci-hook-characterization-and-test-harness*
*Completed: 2026-05-14*
