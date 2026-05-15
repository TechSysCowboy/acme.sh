---
phase: 04-resource-principal-signing
plan: 01
subsystem: auth
tags: [oci, resource-principal, dnsapi, shell-tests, secrets]

requires:
  - phase: 03-authentication-selection-refactor
    provides: API-key-first auth selection and resource-principal fallback boundary
provides:
  - Request-local resource-principal material globals for RPST, private PEM, optional passphrase, and region
  - Path-first inline fallback loader for OCI resource-principal v2.2 material
  - Env-name-only missing and unsupported-version diagnostics for resource-principal material load failures
affects: [dns_oci, phase-04, resource-principal-signing, secure-logging]

tech-stack:
  added: []
  patterns: [path-first-inline-fallback, request-local-secret-material, env-name-only-diagnostics]

key-files:
  created: [.planning/phases/04-resource-principal-signing/04-01-SUMMARY.md]
  modified: [dnsapi/dns_oci.sh, test/dns_oci_mock.sh]

key-decisions:
  - "Resource-principal auth selection remains detection-only; material loading is available to the future signing path rather than `_oci_select_auth`."
  - "RPST, private PEM, and optional passphrase values use `[ -f \"$value\" ]` for path mode and inline values otherwise."
  - "Phase 4 plan 01 rejects unsupported resource-principal versions with `OCI_RESOURCE_PRINCIPAL_VERSION=2.2` diagnostics and no user-supplied values."

patterns-established:
  - "Loaded resource-principal material lives only in `_oci_rp_*` request-local globals and can be cleared with `_oci_reset_resource_principal_material`."
  - "Normal load failures name env vars and failure classes only; token, key, passphrase, region, and path values stay out of normal logs."

requirements-completed: [RP-01]
requirements-partial: [RP-03, RP-04]

duration: 6min
completed: 2026-05-15
---

# Phase 04-01: Resource Principal Material Loading Summary

**OCI resource-principal v2.2 material now loads into request-local shell state with path-first inline fallback and non-secret diagnostics.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-15T15:28:00+10:00
- **Completed:** 2026-05-15T15:34:13+10:00
- **Tasks:** 3
- **Files modified:** 2 production/test files, 1 summary file

## Accomplishments

- Added focused mock tests for inline and path-backed RPST, private PEM, optional passphrase, and region loading.
- Implemented `_oci_load_resource_principal_material`, `_oci_read_resource_principal_value`, and `_oci_reset_resource_principal_material`.
- Added explicit missing-material and unsupported-version tests proving normal errors name env vars and failure classes without leaking fixture values or paths.
- Preserved `_oci_resource_principal_configured` as detection-only so later signing work can load path-backed material per request.

## Task Commits

1. **Task 1: Add inline and path-backed RP material loader tests** - `d8e2e92f` (test)
2. **Task 2: Implement RP material loading helpers** - `ffa173b7` (feat)
3. **Task 3: Add missing and unsupported-version diagnostics** - `3b856c97` (test)

## Files Created/Modified

- `dnsapi/dns_oci.sh` - Adds request-local RP material globals plus reset, read, and load helpers for v2.2 resource-principal material.
- `test/dns_oci_mock.sh` - Adds RP material loader, reset, missing-material, and unsupported-version tests.
- `.planning/phases/04-resource-principal-signing/04-01-SUMMARY.md` - Records Wave 1 execution results.

## Decisions Made

- Kept resource-principal detection separate from material loading; `_oci_select_auth` still does not read token or key file contents.
- Used `[ -f "$value" ]` as the only path-mode test, matching the phase pattern map and preserving inline fallback for all non-files.
- Treated `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` as optional material with the same path-first inline-fallback shape as RPST and private PEM.
- Kept RP v3.0 out of scope for this phase and reported the supported `OCI_RESOURCE_PRINCIPAL_VERSION=2.2` contract without echoing the supplied value.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- `requirements.mark-complete` marked RP-03/RP-04 complete because they appear in the plan frontmatter, but those phase-level requirements still include future Authorization-header behavior. `REQUIREMENTS.md` was corrected to keep RP-03/RP-04 pending while recording this plan's no-persistence/no-normal-log loader coverage here.

## Verification

- `CASE=le_test_oci_rp_loads_inline_material,le_test_oci_rp_loads_path_material sh test/dns_oci_mock.sh`
- `CASE=le_test_oci_rp_missing_material_reports_env_names,le_test_oci_rp_unsupported_version_reports_env_name sh test/dns_oci_mock.sh`
- `sh test/dns_oci_mock.sh`
- `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 04-02 can wire the loader into resource-principal request signing. The loader contract now provides per-request RPST, private PEM, optional passphrase, and region material while keeping `_oci_select_auth` detection-only.

## Self-Check: PASSED

- All tasks from `04-01-PLAN.md` are complete.
- Plan-level verification commands passed.
- SUMMARY.md includes commits, decisions, deviations, issues, and next-plan readiness.

---
*Phase: 04-resource-principal-signing*
*Completed: 2026-05-15*
