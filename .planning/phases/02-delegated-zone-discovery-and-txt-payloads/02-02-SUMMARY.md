---
phase: 02-delegated-zone-discovery-and-txt-payloads
plan: 02
subsystem: dns
tags: [oci, dnsapi, txt-records, wildcard, json-escaping]

requires:
  - phase: 02-01
    provides: full-body OCI zone lookup and fallback/error signal
provides:
  - Apex and delegated wildcard public behavior coverage
  - Shared selected-zone record FQDN computation for add and remove
  - Local OCI JSON escaping for TXT record domain and rdata payload fields
affects: [dns_oci, phase-02, txt-payloads, wildcard-validation]

tech-stack:
  added: []
  patterns: [shared-record-domain-global, local-json-escape-helper, wildcard-public-tests]

key-files:
  created: [.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-02-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "ADD and REMOVE keep separate payload strings but consume the same _oci_record_domain selected during zone lookup."
  - "OCI PATCH RecordDetails.domain remains a full FQDN; Phase 2 did not switch to a relative domain payload."
  - "JSON escaping is local to dns_oci.sh and covers quote/backslash handling for domain and TXT rdata values."

patterns-established:
  - "Wildcard behavior is proven through normal hook FQDN inputs, with no runtime wildcard branch."
  - "Payload escaping tests stay separate from delegated-zone selection tests."

requirements-completed: [ZONE-01, ZONE-02, TXT-01, TXT-02, TXT-03]

duration: 20min
completed: 2026-05-15
---

# Phase 02-02: TXT Payload Summary

**ADD and REMOVE now share the selected record FQDN, preserve OCI's full-domain payload shape, and escape JSON-sensitive TXT values locally.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-05-15T06:03:15+10:00
- **Completed:** 2026-05-15T06:06:34+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Added apex wildcard and delegated wildcard add coverage using normal ACME hook FQDNs.
- Refactored selected-zone output so `_get_zone` computes `_oci_record_domain` once for both add and remove.
- Preserved ADD `ttl: 30`, preserved REMOVE with no TTL, and pinned both behaviors in the symmetry test.
- Added focused quote/backslash TXT value coverage and fixed the JSON payload construction with a small OCI-local escape helper.
- Kept OCI PATCH `domain` as the full FQDN and avoided wildcard-specific runtime branching.

## Task Commits

1. **Task 1: Add apex and delegated wildcard proof** - `5fafdf1c` (test)
2. **Task 2: Share selected-zone and owner computation** - `68faaf58` (refactor)
3. **Task 3: Add focused JSON escaping proof and minimal fix** - `51737935` (fix)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Adds `_oci_record_domain`, reuses it in add/remove payloads and messages, and escapes JSON string values locally.
- `test/dns_oci_mock.sh` - Adds wildcard coverage, TTL/no-TTL assertions, success-message assertions, and focused JSON escaping tests.
- `.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-02-SUMMARY.md` - Records Wave 2 execution results.

## Decisions Made

- Kept add/remove payload bodies separate to match upstream style while sharing only selected-zone/record-owner computation.
- Treated wildcard validation as ordinary FQDN handling; no `*` branch was added.
- Implemented `_oci_json_escape` in `dnsapi/dns_oci.sh` rather than adding a repo-wide JSON utility.

## Deviations from Plan

None - plan executed as written. The TXT escape test exposed a real quote/backslash gap, and the local helper was the planned minimal fix path.

## Issues Encountered

- The first targeted escaping run failed on unescaped TXT quote/backslash input; `_oci_json_escape` fixed the captured payload.
- `shfmt` is not installed locally. Per research, upstream latest is `v3.13.1` while repo CI still pins `v3.1.2`; no formatter was installed or updated during this plan.

## Verification

- `CASE=le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_add_remove_symmetry,le_test_oci_parent_zone_add,le_test_oci_delegated_zone_add,le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_txt_value_json_escape,le_test_oci_record_domain_json_escape sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_add_remove_symmetry,le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02-03 can focus on consolidating the full delegated/wildcard/fallback matrix and final debug/no-PATCH assertions. The runtime path already has shared record-domain computation and local JSON escaping.

---
*Phase: 02-delegated-zone-discovery-and-txt-payloads*
*Completed: 2026-05-15*
