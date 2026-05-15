---
phase: 04-resource-principal-signing
plan: 03
subsystem: auth
tags: [oci, resource-principal, secret-handling, failure-paths, shell-tests]

requires:
  - phase: 04-02
    provides: resource-principal GET and PATCH request signing
provides:
  - Public-path proof that path-backed RPST/private PEM material refreshes between GET and PATCH
  - Public-path proof that RP names, paths, values, signatures, and Authorization headers stay out of account config and normal logs
  - Terminal resource-principal signing failure handling during zone lookup
affects: [dns_oci, phase-04, resource-principal-signing, secure-logging]

tech-stack:
  added: []
  patterns: [per-request-material-refresh, no-rp-persistence-public-path, terminal-rp-auth-failure]

key-files:
  created: [.planning/phases/04-resource-principal-signing/04-03-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "Resource-principal signing failures during zone lookup are treated as terminal auth failures, not DNS zone misses."
  - "The public add path proves path-backed RPST/private PEM refresh by mutating files after zone GET and before records PATCH."
  - "ShellCheck SC2329 is disabled for the mock harness because real-provider tests intentionally define lower-boundary stubs invoked indirectly."

patterns-established:
  - "Public resource-principal tests restore real `_signed_request` and stub only lower HTTP/signing/temp-file boundaries."
  - "RP signing failure detection uses empty signature output as the stable failure signal and emits env-name/failure-class-safe normal errors."

requirements-completed: [RP-03]
requirements-partial: [RP-01, RP-04]

duration: 5min
completed: 2026-05-15
---

# Phase 04-03: Resource Principal Public Path Hardening Summary

**Resource-principal public add now refreshes file-backed material per request, avoids persistence/normal-log leaks, and stops zone fallback on signing failure.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-15T15:46:00+10:00
- **Completed:** 2026-05-15T15:50:46+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Added public-path proof that a path-backed RPST/private PEM file is read separately for zone GET and records PATCH.
- Added public-path proof that RP names, values, paths, signatures, `ST$` keyIds, and Authorization headers are absent from saved/cleared account config and normal logs.
- Added terminal signing-failure behavior so `_get_zone` stops immediately on resource-principal signing failure and `_get_oci_zone` avoids generic zone-not-found guidance.
- Kept sensitive signing internals in secure debug while ensuring passphrase values are not secure-logged.

## Task Commits

1. **Task 1: Prove path-backed material refresh between GET and PATCH** - `2d100a80` (test)
2. **Task 2: Prove no persistence or normal logging through public path** - `2d100a80` (test, same public-path coverage commit)
3. **Task 3: Make RP signing failures terminal during zone lookup** - `5043e9cc` (fix)
4. **ShellCheck harness follow-up** - `80032281` (test)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Adds a resource-principal auth-error flag, signing-failure detection, and terminal zone-lookup handling.
- `test/dns_oci_mock.sh` - Adds public-path refresh, persistence/logging, and signing-failure tests; documents indirect signer stubs for ShellCheck.
- `.planning/phases/04-resource-principal-signing/04-03-SUMMARY.md` - Records Wave 3 execution results.

## Decisions Made

- Treated empty signature output as a signing failure, covering failed `_sign` and failed temp-key signing without logging raw OpenSSL output.
- Set the terminal RP auth flag from `_get_zone` based on the failed `_signed_request` status, because command substitution prevents helper-local state from propagating back to the caller shell.
- Left RP-04 pending for the final passphrase/full-matrix plan even though this plan proves the public-path normal-log boundary.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- Shell command substitution means private globals set inside `_signed_request_resource_principal` do not propagate to `_get_zone`. The fix records terminal RP auth failure in `_get_zone` from the failed `_signed_request` status, while still setting the helper-local flag for direct callers.
- ShellCheck reported indirect test stubs as unused; the harness now disables SC2329 at file scope because those stubs are invoked by the sourced provider.

## Verification

- `CASE=le_test_oci_rp_refreshes_path_material_between_requests sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_rp_does_not_persist_or_normal_log_material sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_rp_signing_failure_stops_zone_fallback sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 04-04 can complete the remaining passphrase success/failure and full exact-signing matrix coverage, then Phase 4 can close if static and mocked verification remain green.

## Self-Check: PASSED

- All tasks from `04-03-PLAN.md` are complete.
- Plan-level verification commands passed.
- SUMMARY.md includes commits, decisions, deviations, issues, and next-plan readiness.

---
*Phase: 04-resource-principal-signing*
*Completed: 2026-05-15*
