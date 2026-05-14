---
phase: 02-delegated-zone-discovery-and-txt-payloads
plan: 01
subsystem: dns
tags: [oci, dnsapi, delegated-zones, fallback, shell-tests]

requires: []
provides:
  - OCI zone lookup mock fixtures for status, code, id, and response body
  - Ambiguous delegated lookup fallback to a parent zone
  - Visible authorization or permission hard-fail before mutation
  - No-zone existence/read-permission hint
affects: [dns_oci, phase-02, delegated-zone-discovery, resource-principal-planning]

tech-stack:
  added: []
  patterns: [mocked-shell-provider-tests, full-body-zone-lookup, factual-debug]

key-files:
  created: [.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-01-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "Zone discovery now inspects full lookup response bodies so it can parse ids and stable error signal without changing signing or auth-mode selection."
  - "NotAuthorizedOrNotFound remains ambiguous and falls through to parent candidates; clear status/code/message authorization signals fail hard."
  - "Zone OCIDs moved to debug2 while routine probe status stays in normal debug."

patterns-established:
  - "Mock zone responses are configured with candidate zone, HTTP-like status, code, id, and message while preserving MOCK_OCI_ZONES happy-path fixtures."
  - "Public add behavior proves fallback and no-PATCH safety before relying on helper-level details."

requirements-completed: [ZONE-01, ZONE-02, ZONE-03, TXT-03]

duration: 45min
completed: 2026-05-15
---

# Phase 02-01: Lookup Fallback Summary

**OCI zone lookup now treats ambiguous delegated misses as parent-fallback candidates and clear authorization failures as no-mutation hard failures.**

## Performance

- **Duration:** 45 min
- **Started:** 2026-05-15T05:15:00+10:00
- **Completed:** 2026-05-15T06:01:27+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Extended `test/dns_oci_mock.sh` so zone GET fixtures can carry candidate status, code, id, and body signal.
- Updated `_get_zone` to parse full zone lookup responses, continue on ambiguous misses, and fail hard on clear authz/permission signal before any PATCH.
- Added public behavior tests for ambiguous `404`/`NotAuthorizedOrNotFound` fallback and visible authz no-PATCH safety.
- Preserved existing API-key auth setup behavior and current normal success output.
- Kept the existing no-zone error and added the planned hint to check zone existence and read permission.

## Task Commits

1. **Task 1: Extend OCI lookup mock signal** - `74aed197` (test)
2. **Task 2: Add fallback and hard-fail lookup cases** - `4cfdaf4b` (fix, includes tests and implementation)
3. **Task 3: Implement minimal lookup fallback behavior** - `4cfdaf4b` (fix, same commit as Task 2)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Parses full lookup bodies, detects clear authz failures, adds factual fallback debug, and adds the no-zone hint.
- `test/dns_oci_mock.sh` - Adds lookup response fixtures and the ambiguous fallback / visible authz hard-fail tests.
- `.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-01-SUMMARY.md` - Records Wave 1 execution results.

## Decisions Made

- Kept `_signed_request` signing, headers, host, and auth selection unchanged; `_get_zone` now asks for the full response body and parses the fields it needs locally.
- Treated `NotAuthorizedOrNotFound` as ambiguous even though it contains the word `NotAuthorized`, matching the OCI 404 behavior discussed for this phase.
- Used status `401`/`403`, non-ambiguous code markers, or clear permission wording as hard-fail signal; tests avoid matching OCI-owned prose exactly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 4 - Plan coherence] Combined Task 2 tests with Task 3 implementation**
- **Found during:** Task 2 (Add fallback and hard-fail lookup cases)
- **Issue:** The visible-authz test cannot pass until production lookup parses error/status signal, so committing Task 2 as test-only would leave the required verification red.
- **Fix:** Added the two public behavior tests and the minimal production lookup change in the same task commit.
- **Files modified:** `dnsapi/dns_oci.sh`, `test/dns_oci_mock.sh`
- **Verification:** Targeted lookup cases, parent/no-zone cases, full harness, and ShellCheck all passed.
- **Committed in:** `4cfdaf4b`

---

**Total deviations:** 1 auto-fixed (plan coherence)
**Impact on plan:** Scope stayed inside 02-01. The combined commit kept every checkpoint green and did not change auth-mode selection.

## Issues Encountered

- `shfmt` is not installed locally. Per research, upstream latest is `v3.13.1` while repo CI still pins `v3.1.2`; no formatter was installed or updated during this plan.

## Verification

- `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard,le_test_oci_parent_fallback,le_test_oci_no_zone_failure sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_parent_zone_add,le_test_oci_parent_fallback,le_test_oci_no_zone_failure sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02-02 can build on the selected-zone behavior now that delegated misses, hard-fail authz paths, and no-zone no-PATCH safety are covered by shell tests. Resource-principal auth remains untouched and available for later phases.

---
*Phase: 02-delegated-zone-discovery-and-txt-payloads*
*Completed: 2026-05-15*
