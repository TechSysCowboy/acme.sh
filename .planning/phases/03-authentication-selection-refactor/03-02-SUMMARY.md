---
phase: 03-authentication-selection-refactor
plan: 02
subsystem: auth
tags: [oci, dns, shell, resource-principal, persistence]
requires:
  - phase: 03-authentication-selection-refactor
    provides: auth selector boundary from plan 03-01
provides:
  - API-key-wins-over-resource-principal proof
  - OCI CLI config-file primary proof
  - Resource-principal no-persistence proof
  - Saved API-key config survival proof during RP fallback
affects: [dns_oci, auth-selection, account-config]
tech-stack:
  added: []
  patterns: [config-file fixture reads, no-RP-persistence assertions, dual-path missing-auth diagnostics]
key-files:
  created:
    - .planning/phases/03-authentication-selection-refactor/03-02-SUMMARY.md
  modified:
    - test/dns_oci_mock.sh
key-decisions:
  - "API-key auth remains primary when complete API-key config and complete RP env are both present."
  - "The RP detector stays environment-only and does not save or clear OCI_RESOURCE_PRINCIPAL_* values."
patterns-established:
  - "Mock _readini can return keyed OCI CLI config fixtures while recording each lookup."
  - "Persistence tests assert both variable names and fixture values stay out of account config captures."
requirements-completed: [AUTH-01, AUTH-02, AUTH-03]
duration: 3 min
completed: 2026-05-15
---

# Phase 03 Plan 02: Auth Persistence Boundary Summary

**The auth selector now has mocked proof that API-key config remains durable while resource-principal inputs remain process-local.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-15T04:13:02Z
- **Completed:** 2026-05-15T04:16:04Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

- Added `le_test_oci_auth_api_key_wins_over_resource_principal` to prove complete API-key config wins over complete RP env.
- Added config-file fixture support and `le_test_oci_auth_oci_cli_config_file_primary` to prove the OCI CLI config path still reaches PATCH through API-key mode.
- Added no-persistence and missing-all-auth tests that distinguish API-key and RP failures without saving or clearing RP values.
- Added account-config fixture reads and `le_test_oci_auth_saved_config_survives_resource_principal_fallback` to prove saved API-key config values survive RP fallback runs.

## Task Commits

1. **Task 1: Prove API-key wins over complete RP env** - `7559adbb` (test)
2. **Task 2: Prove OCI CLI config and RP persistence boundaries** - `7559adbb` (test)
   - Follow-up saved-config survival proof - `e418b144` (test)
3. **Task 3: Tighten missing-all-auth diagnostics** - `7559adbb` (test)

## Files Created/Modified

- `test/dns_oci_mock.sh` - Adds config-file fixture returns and the Phase 3 persistence/missing-auth matrix.

## Decisions Made

- Kept the production hook unchanged in this plan because the Plan 03-01 selector already satisfied the new persistence tests.
- Made `OCI_CLI_PROFILE=DEFAULT` explicit in the config-file fixture to preserve the hook's current profile behavior while proving the intended config path.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The first config-file fixture run did not read the `DEFAULT` profile because the test left `OCI_CLI_PROFILE` empty. The fixture now sets `OCI_CLI_PROFILE=DEFAULT`, matching the current hook behavior and keeping this plan scoped to auth selection persistence.

## User Setup Required

None - no external service configuration required.

## Verification

- `CASE=le_test_oci_auth_api_key_wins_over_resource_principal,le_test_oci_auth_resource_principal_does_not_persist sh test/dns_oci_mock.sh` - passed
- `CASE=le_test_oci_auth_saved_config_survives_resource_principal_fallback sh test/dns_oci_mock.sh` - passed
- `CASE=le_test_oci_auth_api_key,le_test_oci_auth_oci_cli_config_file_primary,le_test_oci_auth_missing_reports_both_paths sh test/dns_oci_mock.sh` - passed
- `sh test/dns_oci_mock.sh` - passed
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh` - passed

## Self-Check: PASSED

- Complete API-key config wins when RP env is also complete.
- OCI CLI config-file values still configure API-key auth and reach PATCH.
- Resource-principal variable names and fixture values stay out of saved and cleared account-config captures.
- Saved API-key account config values survive RP fallback selection.
- Missing-all-auth diagnostics name both key-based and RP configuration problems.

## Next Phase Readiness

Ready for Plan 03-03 to complete the full public-path matrix and static validation.

---
*Phase: 03-authentication-selection-refactor*
*Completed: 2026-05-15*
