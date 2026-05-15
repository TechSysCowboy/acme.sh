---
phase: 05-documentation-and-release-verification
plan: 01
subsystem: docs
tags: [oci, dnsapi, metadata, resource-principal, mock-harness]

requires:
  - phase: 04-resource-principal-signing
    provides: resource-principal signing, passphrase support, and secure logging proof
provides:
  - Current OCI provider metadata for API-key primary auth and resource-principal fallback
  - Metadata regression coverage in the local OCI mock harness
  - Stale Phase 3/4 RP signing and passphrase prose cleanup
affects: [dns_oci, phase-05, documentation, release-verification]

tech-stack:
  added: []
  patterns: [provider-metadata-regression, stale-prose-guard, mock-harness-doc-check]

key-files:
  created: [.planning/phases/05-documentation-and-release-verification/05-01-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "Provider metadata states API-key auth remains primary and resource-principal auth is a fallback only when API-key auth is incomplete."
  - "Detailed setup remains out of README files; `dns_oci_info` is the concise in-repo provider metadata surface."
  - "The mock harness protects metadata and stale-prose drift without requiring live OCI credentials."

patterns-established:
  - "Metadata drift is checked by a named `test/dns_oci_mock.sh` case rather than a loose release-time grep only."
  - "Stale prose assertions avoid embedding exact forbidden phrases so the release grep remains meaningful."

requirements-completed: [DOC-01]

duration: 8min
completed: 2026-05-15
---

# Phase 05-01: OCI Provider Metadata Summary

**OCI provider metadata now reflects API-key primary auth, resource-principal fallback, delegated subzones, policy expectations, and supported RP variables.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-15T16:58:00+10:00
- **Completed:** 2026-05-15T17:06:00+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Updated `dns_oci_info` to document API-key auth precedence, resource-principal fallback, delegated subzone selection, DNS policy expectations, and RP v2.2 env names.
- Replaced stale inline passphrase wording now that Phase 4 supports passphrase-backed resource-principal private keys.
- Added `le_test_oci_provider_metadata_documents_current_behavior` to make metadata drift visible in the existing POSIX mock harness.
- Reworded the remaining mock resource-principal failure fixture and assertions away from old "not implemented" Phase 3/4 wording.

## Task Commits

1. **Tasks 1-3: Metadata regression, provider metadata, and stale prose cleanup** - `81a899ea` (docs/test)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Updates provider metadata and comments for current OCI auth and delegated-zone behavior.
- `test/dns_oci_mock.sh` - Adds metadata regression coverage and current resource-principal failure prose.
- `.planning/phases/05-documentation-and-release-verification/05-01-SUMMARY.md` - Records Wave 1 execution and verification evidence.

## Decisions Made

- Kept provider metadata concise and left detailed setup guidance for the 05-02 wiki-ready artifact.
- Kept API-key auth wording primary to avoid surprising existing users.
- Used split forbidden-phrase assembly in the metadata regression so the release grep still proves stale prose is absent.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- The first metadata regression run failed because the metadata used `Delegated` while the test intentionally asserted the lowercase literal `delegated`. The metadata was adjusted to the planned literal.
- The first stale-prose grep caught the new test embedding exact forbidden phrases. The test now assembles those phrases without storing them verbatim in source.

## Verification

- `CASE=le_test_oci_provider_metadata_documents_current_behavior sh test/dns_oci_mock.sh`
- `! rg -n "passphrase is not supported|signing is not implemented|before Phase 3/4 fallback|Phase 3 signing boundary" dnsapi/dns_oci.sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

05-02 can build the wiki-ready OCI DNS guide from current provider metadata and Phase 4 verification evidence. `DOC-01` remains pending in `REQUIREMENTS.md` until the final Phase 5 release gates close the documentation and verification set.

## Self-Check: PASSED

- All tasks from `05-01-PLAN.md` are complete.
- Plan-level verification commands passed.
- SUMMARY.md includes decisions, deviations, issues, verification, and next-plan readiness.

---
*Phase: 05-documentation-and-release-verification*
*Completed: 2026-05-15*
