---
phase: 05-documentation-and-release-verification
plan: 02
subsystem: docs
tags: [oci, dns, wiki, resource-principal, policy]

requires:
  - phase: 05-01
    provides: current provider metadata and stale-prose cleanup
provides:
  - Wiki-ready OCI DNS operator guide
  - API-key and resource-principal setup recipes
  - Adaptable OCI DNS policy examples and troubleshooting guidance
affects: [dns_oci, phase-05, documentation, release-verification, v2-live-validation]

tech-stack:
  added: []
  patterns: [wiki-ready-doc-artifact, placeholder-only-secret-docs, docs-scope-guard]

key-files:
  created:
    - .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md
    - .planning/phases/05-documentation-and-release-verification/05-02-SUMMARY.md
  modified: []

key-decisions:
  - "Detailed OCI DNS setup guidance lives in a Phase 5 wiki-ready artifact, not in `README.md` or `dnsapi/README.md`."
  - "Policy examples use `read dns-zones` and `use dns-records` as adaptable starting points, with optional TXT/domain scoping."
  - "The guide explicitly separates v1 mocked/static proof from future v2 live OCI validation."

patterns-established:
  - "Provider-specific long-form DNS docs should be copy-ready wiki artifacts when the repo docs already point users to the wiki."
  - "Secret examples use placeholders only and avoid real-looking private-key, RPST, passphrase, signature, or authorization material."

requirements-completed: [DOC-02, DOC-01]

duration: 4min
completed: 2026-05-15
---

# Phase 05-02: OCI DNS Wiki Guide Summary

**Wiki-ready OCI DNS guidance now covers delegated subzones, API-key setup, resource-principal fallback, policy examples, secret handling, and v1 validation scope.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-15T17:06:00+10:00
- **Completed:** 2026-05-15T17:10:00+10:00
- **Tasks:** 3
- **Files modified:** 1 docs artifact, 1 summary file

## Accomplishments

- Created `.planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md` as copy-ready guidance for the upstream OCI DNS wiki page.
- Documented delegated subzone selection, parent fallback on ambiguous misses, API-key auth, resource-principal auth, and API-key precedence.
- Added OCI policy examples for API-key groups and resource-principal dynamic groups using `read dns-zones`, `use dns-records`, `target.dns-record.type`, and `target.dns-domain.name`.
- Added troubleshooting for missing auth, API-key precedence, unsupported RP version, unreadable RP material, zone/permission ambiguity, and deferred live validation.
- Left `README.md` and `dnsapi/README.md` unchanged because the existing wiki-pointer shape remains sufficient.

## Task Commits

1. **Tasks 1-3: Wiki-ready guide, policy guidance, and self-check** - `acbb1fac` (docs)

## Files Created/Modified

- `.planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md` - Wiki-ready OCI DNS setup and troubleshooting guide.
- `.planning/phases/05-documentation-and-release-verification/05-02-SUMMARY.md` - Records Wave 2 execution and verification evidence.

## Decisions Made

- Used placeholder-only examples such as `<domain-name>`, `<compartment-name>`, and `<RP_PRIVATE_PEM_CONTENTS>`.
- Kept the guide honest that live OCI validation was not run for v1.
- Refreshed official Oracle docs during execution for DNS policy resource types/conditions and resource-principal v2.2 environment names.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Verification

- `test -s .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md`
- `rg -n "read dns-zones|use dns-records|target\\.dns-record\\.type|target\\.dns-domain\\.name|dynamic-group|API-key|resource principal|OCI_RESOURCE_PRINCIPAL_VERSION=2.2" .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md`
- `rg -n "OCI_RESOURCE_PRINCIPAL_VERSION|OCI_RESOURCE_PRINCIPAL_RPST|OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM|OCI_RESOURCE_PRINCIPAL_REGION|OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE|delegated|subzone|API-key|resource principal|read dns-zones|use dns-records" .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md`
- `! rg -n "OCI_RESOURCE_PRINCIPAL_VERSION=3|live OCI validation passed|BEGIN PRIVATE KEY|Authorization: Signature" .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

05-03 can run final mocked/static release verification, record freshness evidence, and create the separate v2 live-validation checklist.

## Self-Check: PASSED

- All tasks from `05-02-PLAN.md` are complete.
- Plan-level content and negative checks passed.
- No unnecessary README churn was introduced.

---
*Phase: 05-documentation-and-release-verification*
*Completed: 2026-05-15*
