---
phase: 03-authentication-selection-refactor
status: passed
score: 10/10
verified: 2026-05-15
requirements_verified: [AUTH-01, AUTH-02, AUTH-03]
human_verification: []
overrides_applied: 0
---

# Phase 3 Verification: Authentication Selection Refactor

**Verdict:** Passed. Phase 3 achieved its goal: OCI DNS authentication selection is separated from request signing, API-key auth remains primary, resource-principal fallback is explicit and process-local, and Phase 3 stops before RP signing or DNS mutation.

## Goal Check

**Phase goal:** Preserve current OCI API-key auth while creating a clean fallback point for resource principal auth.

**Result:** PASS

- `_get_oci_zone` now calls `_oci_select_auth` instead of calling `_oci_config` directly.
- `_oci_config` remains API-key focused; RP detection is handled by `_oci_resource_principal_configured`.
- `_oci_auth_mode` is process-local and records `api_key` or `resource_principal`.
- `_signed_request` refuses `resource_principal` mode before `_fingerprint "$OCI_CLI_KEY"` and before any API-key signature construction.
- Mocked public-path tests prove API-key success, API-key-wins-over-RP, partial-key RP fallback, missing-all-auth diagnostics, saved config survival, no RP persistence, and remove-path selector behavior.

## Requirements

| Requirement | Status | Evidence |
|-------------|--------|----------|
| AUTH-01 | PASS | `le_test_oci_auth_api_key`, `le_test_oci_auth_oci_cli_config_file_primary`, `le_test_oci_auth_api_key_wins_over_resource_principal`, and `le_test_oci_rm_uses_auth_selector` pass. |
| AUTH-02 | PASS | `le_test_oci_auth_resource_principal_detected_boundary`, `le_test_oci_auth_partial_key_falls_back_to_resource_principal`, and `le_test_oci_auth_saved_config_survives_resource_principal_fallback` pass. |
| AUTH-03 | PASS | `le_test_oci_auth_missing_reports_both_paths` and `le_test_oci_auth_partial_key_falls_back_to_resource_principal` pass with stable variable-name diagnostics for both auth paths. |

## Must-Have Checks

| Check | Status | Evidence |
|-------|--------|----------|
| API-key auth remains primary | PASS | Complete API-key env reaches PATCH and wins even when complete RP env is also present. |
| OCI CLI config-file auth still works | PASS | Mock `_readini` returns DEFAULT-profile tenancy, user, region, and key_file values; public add reaches PATCH through `api_key` mode. |
| RP fallback happens only after API-key failure | PASS | RP-only and partial-key cases select `_oci_auth_mode=resource_principal`; API-key-wins case stays `api_key`. |
| RP mode fails before signing or mutation | PASS | `_signed_request` guard is before `_fingerprint`; RP tests assert no PATCH capture. |
| Saved API-key config survives RP fallback | PASS | Saved config path and tenancy remain saved in `le_test_oci_auth_saved_config_survives_resource_principal_fallback`. |
| RP values are never persisted | PASS | RP tests assert no `OCI_RESOURCE_PRINCIPAL_` names or fixture values in saved/cleared account config captures. |
| Add and remove paths use selector | PASS | Add matrix covers all auth branches; remove smoke proves `dns_oci_rm` selects `api_key` and preserves no-TTL REMOVE payload. |
| Static validation passes | PASS | ShellCheck and shfmt gates passed for `dnsapi/dns_oci.sh` and `test/dns_oci_mock.sh`. |
| Live OCI remains deferred | PASS | All verification is mocked shell-level proof; no command requires real OCI config, RPST, private PEM, or live DNS. |

## Automated Checks

- PASS: `CASE=le_test_oci_auth_api_key,le_test_oci_auth_resource_principal_detected_boundary sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_auth_partial_key_falls_back_to_resource_principal sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_auth_api_key_wins_over_resource_principal,le_test_oci_auth_resource_principal_does_not_persist,le_test_oci_auth_saved_config_survives_resource_principal_fallback sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_auth_api_key,le_test_oci_auth_oci_cli_config_file_primary,le_test_oci_auth_missing_reports_both_paths sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_rm_uses_auth_selector sh test/dns_oci_mock.sh`
- PASS: `sh test/dns_oci_mock.sh`
- PASS: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- PASS: `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- PASS: `git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`

## Code Review Gate

- PASS: `03-REVIEW.md` status is `clean`.

## Regression Gate

- PASS: Prior Phase 1 and Phase 2 verification commands are covered by the full `sh test/dns_oci_mock.sh` suite, which passed after Phase 3 changes.

## Drift Gates

- PASS: Schema drift check reported no drift.
- PASS: Codebase drift check reported no action required.

## Gaps

None.

## Human Verification

None required for Phase 3. Live OCI DNS and OCI-hosted resource-principal smoke checks remain intentionally deferred outside v1 Phase 3 automated verification.
