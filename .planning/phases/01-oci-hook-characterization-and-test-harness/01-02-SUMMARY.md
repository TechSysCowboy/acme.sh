---
phase: 01-oci-hook-characterization-and-test-harness
plan: 02
subsystem: testing
tags: [oci, dns, shell, txt, zone-discovery]
requires:
  - phase: 01-oci-hook-characterization-and-test-harness
    provides: Minimal OCI DNS mock harness
provides:
  - Mocked parent-zone, delegated-zone, parent-fallback, no-zone, and add/remove symmetry coverage
  - Focused _signed_request return-field parser fixture
  - Minimal dnsapi/dns_oci.sh parser artifact fix
affects: [dnsapi/dns_oci.sh, Phase 2, Phase 3, Phase 4]
tech-stack:
  added: []
  patterns: [provider-boundary request capture, public dns_oci_add and dns_oci_rm characterization]
key-files:
  created: []
  modified: [test/dns_oci_mock.sh, dnsapi/dns_oci.sh]
key-decisions:
  - "Zone and TXT payload cases drive public dns_oci_add and dns_oci_rm paths, then assert captured _signed_request calls."
  - "The return-field artifact fix is limited to the response sanitation command substitution line."
patterns-established:
  - "Mock zone availability is controlled through MOCK_OCI_ZONES."
  - "Request assertions use captured GET and PATCH calls rather than private helper state."
requirements-completed: [TEST-01]
duration: 4 min
completed: 2026-05-14
---

# Phase 1 Plan 2: Zone and TXT Characterization Summary

**Mocked OCI DNS zone discovery and TXT add/remove payload coverage with a one-line return-field parser fix**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-14T17:39:30Z
- **Completed:** 2026-05-14T17:43:16Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Added public-path mocked coverage for parent-zone add, delegated-zone add, parent fallback, no-zone failure, and add/remove symmetry.
- Asserted `_signed_request "GET" "/20180115/zones/$candidate" "" "id"` and PATCH `/20180115/zones/${_domain}/records` behavior through captured request lines.
- Added a focused `_signed_request` return-field parser fixture.
- Removed the stray literal `)` from the `_signed_request` response sanitation assignment in `dnsapi/dns_oci.sh`.

## Task Commits

1. **Task 1: Add zone discovery and TXT payload cases** - `6d7fa491` (test)
2. **Task 2: Characterize and fix return-field parse artifact** - `4f32f544` (fix)
3. **Task 3: Run full zone suite and lint touched shell files** - no code commit; verification only

**Plan metadata:** pending metadata commit

## Files Created/Modified

- `test/dns_oci_mock.sh` - Adds zone/TXT behavior cases and reinstalls stubs after sourcing the real hook.
- `dnsapi/dns_oci.sh` - Removes the stray `)` in the `_return_field` branch response sanitation line.

## Decisions Made

- Kept all zone and TXT mutation tests on the public `dns_oci_add` and `dns_oci_rm` entry points.
- Did not install `shfmt`; local `shfmt` is absent and Phase 5 already owns formatter pin cleanup.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The original harness stub definitions were being overwritten when `dnsapi/dns_oci.sh` was sourced. The harness now installs provider-boundary stubs after sourcing the real hook.

## Verification

- PASS: `CASE=le_test_oci_parent_zone_add,le_test_oci_delegated_zone_add,le_test_oci_parent_fallback,le_test_oci_no_zone_failure,le_test_oci_add_remove_symmetry sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_signed_request_return_field sh test/dns_oci_mock.sh`
- PASS: `sh test/dns_oci_mock.sh`
- PASS: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- SKIPPED: `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh` because local `shfmt` is absent.

## Self-Check: PASSED

- Parent-zone, delegated-zone, parent-fallback, no-zone, and add/remove symmetry cases all pass.
- `dnsapi/dns_oci.sh` no longer contains `sed 's/\\\"//g'))`.
- The return-field parser fixture returns exactly `ocid1.dns-zone.oc1..example`.
- No request signing, header, method, host, or body logic changed outside the one-line parser artifact fix.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Plan 01-03 to add key-based auth, missing-auth, resource-principal current-state, and secure-debug boundary fixtures.

---
*Phase: 01-oci-hook-characterization-and-test-harness*
*Completed: 2026-05-14*
