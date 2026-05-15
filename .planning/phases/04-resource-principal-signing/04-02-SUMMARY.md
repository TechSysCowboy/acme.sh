---
phase: 04-resource-principal-signing
plan: 02
subsystem: auth
tags: [oci, resource-principal, request-signing, dnsapi, shell-tests]

requires:
  - phase: 04-01
    provides: request-local resource-principal material loading
provides:
  - `_signed_request` dispatcher for API-key and resource-principal signing modes
  - Preserved API-key signer behavior behind `_signed_request_api_key`
  - Resource-principal GET and PATCH Authorization construction with `ST$` keyId shape
  - Exact mock proof for GET and PATCH signed headers, signing string, and normal-log cleanliness
affects: [dns_oci, phase-04, resource-principal-signing, secure-logging]

tech-stack:
  added: []
  patterns: [signed-request-dispatcher, st-security-token-key-id, body-header-signing-proof]

key-files:
  created: [.planning/phases/04-resource-principal-signing/04-02-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "API-key signing is preserved by moving the existing `_signed_request` body into `_signed_request_api_key` behind a dispatcher."
  - "Resource-principal Authorization uses the literal `ST$<rpst>` keyId shape for GET and PATCH requests."
  - "PATCH resource-principal signing uses the same body header order as the API-key signer: `(request-target) date host x-content-sha256 content-type content-length`."

patterns-established:
  - "Exact signer tests restore the real provider signer and stub only `_get`/`_post`, `_sign`, and `_mktemp`."
  - "Resource-principal signer writes the loaded private PEM to a temp file, signs, removes the file, and resets loaded material before returning."

requirements-completed: [RP-02]
requirements-partial: [RP-01, RP-04]

duration: 7min
completed: 2026-05-15
---

# Phase 04-02: Resource Principal Request Signing Summary

**OCI DNS GET and PATCH requests can now be signed with resource-principal session-token credentials using exact `ST$` Authorization headers.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-05-15T15:37:00+10:00
- **Completed:** 2026-05-15T15:44:13+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Added exact GET proof for `Authorization: Signature`, `keyId="ST$<rpst>"`, signed header list, signing string, temp PEM handling, and clean normal logs.
- Split `_signed_request` into a dispatcher plus `_signed_request_api_key`, preserving the existing API-key signing behavior.
- Added `_signed_request_resource_principal` for GET and PATCH, using loaded RP material from 04-01.
- Added exact PATCH proof for `x-content-sha256`, `content-type`, `content-length`, body signing string lines, `_H1` through `_H5`, and response preservation.

## Task Commits

1. **Task 1: Add exact GET resource-principal signing proof** - `22644ed5` (test)
2. **Task 2: Split `_signed_request` and implement RP GET signing** - `7da359f4` (feat)
3. **Task 3: Add PATCH body-header signing proof** - `623ee9fd` (test), `537d486f` (feat)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Adds the signing dispatcher, API-key helper, and resource-principal GET/PATCH signer.
- `test/dns_oci_mock.sh` - Adds exact GET/PATCH resource-principal signing tests with lower-boundary stubs.
- `.planning/phases/04-resource-principal-signing/04-02-SUMMARY.md` - Records Wave 2 execution results.

## Decisions Made

- Kept `_signed_request` as the single call boundary and selected the private signer from `_oci_auth_mode`.
- Preserved the API-key implementation by moving existing code under a helper rather than rewriting it.
- Used secure debug for resource-principal signing strings, bodies, and Authorization headers; normal log assertions prove the RPST, private PEM, `ST$` keyId, signature, and Authorization header are absent.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- The first GET implementation produced `ST<rpst>` instead of the required `ST$<rpst>` keyId; the exact GET test caught it before commit and the signer now emits the literal `ST$` shape.
- ShellCheck flagged literal-dollar test assertions and the exported PATCH Authorization header warning in touched lines; the assertions now escape literal `$` in double quotes and the RP PATCH branch documents the existing `_H*` export pattern.

## Verification

- `CASE=le_test_oci_rp_signs_get_with_st_key_id sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_rp_signs_patch_body_headers sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_auth_api_key,le_test_oci_auth_api_key_wins_over_resource_principal sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 04-03 can now focus on the remaining process-local and failure-path guarantees: path-backed material refresh between requests, no persistence across the public flow, and terminal auth failure behavior when loading or signing fails.

## Self-Check: PASSED

- All tasks from `04-02-PLAN.md` are complete.
- Plan-level verification commands passed.
- SUMMARY.md includes commits, decisions, deviations, issues, and next-plan readiness.

---
*Phase: 04-resource-principal-signing*
*Completed: 2026-05-15*
