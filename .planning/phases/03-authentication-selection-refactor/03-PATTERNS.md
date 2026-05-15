# Phase 03 Pattern Map

**Generated:** 2026-05-15
**Status:** Ready for planning

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `dnsapi/dns_oci.sh` | DNS provider hook | request-signing auth selection | existing `_oci_config`, `_get_oci_zone`, `_signed_request` in `dnsapi/dns_oci.sh` | exact |
| `test/dns_oci_mock.sh` | shell test harness | public add/remove fixtures and provider-boundary stubs | existing `le_test_oci_auth_*`, `_install_oci_mock_stubs`, temp-backed captures in `test/dns_oci_mock.sh` | exact |

## Pattern Assignments

### `dnsapi/dns_oci.sh` (provider hook, request-signing auth selection)

**Analog:** existing `dnsapi/dns_oci.sh`

**Config loading pattern:**

- `_oci_config` reads `OCI_CLI_CONFIG_FILE`, `OCI_CLI_PROFILE`,
  `OCI_CLI_TENANCY`, `OCI_CLI_USER`, `OCI_CLI_REGION`, `OCI_CLI_KEY_FILE`, and
  `OCI_CLI_KEY`.
- Durable API-key settings are saved through `_saveaccountconf_mutable`.
- Defaults are cleared through `_clearaccountconf_mutable`.
- Missing required API-key pieces return `1` after stable `_err` lines.

**Selector insertion point:**

- `_get_oci_zone` currently calls `_oci_config` before zone lookup.
- Phase 3 should replace that direct call with a selector helper, while keeping
  `_oci_config` API-key focused.
- `_signed_request` remains the provider boundary for zone GET and record PATCH.

**Signing pattern:**

- `_signed_request` builds API-key signature headers from `OCI_CLI_TENANCY`,
  `OCI_CLI_USER`, `OCI_CLI_REGION`, and `OCI_CLI_KEY`.
- Sensitive body/signature/header data goes through `_secure_debug3`.
- Phase 3 should add only a top-level mode guard for
  `_oci_auth_mode=resource_principal`; actual RP signing remains Phase 4.

### `test/dns_oci_mock.sh` (shell harness, public-path proof)

**Analog:** existing `test/dns_oci_mock.sh`

**Harness pattern:**

- Use `_reset_oci_mocks` to reset temp-backed capture files and env variables.
- Use `_install_oci_mock_stubs` after sourcing `dnsapi/dns_oci.sh` so stubs
  replace provider functions.
- Capture side effects in files under `$_DNS_OCI_MOCK_DIR`; refresh public
  variables via `_dns_oci_mock_refresh_captures`.

**Test pattern:**

- Public-path tests call `dns_oci_add` or `dns_oci_rm`.
- Assertions use stable substrings via `_assert_contains` and
  `_assert_not_contains`.
- The `CASE=` selector supports focused task verification without running the
  full suite each time.

**Auth fixture pattern:**

- Current `le_test_oci_auth_api_key`, `le_test_oci_auth_missing`, and
  `le_test_oci_auth_resource_principal_current_state` already cover the Phase 1
  auth surface.
- Phase 3 should rename or supersede the current-state RP characterization with
  selector-boundary tests once the fallback path exists.

## Shared Patterns

### Process-Local Globals

Use private globals for facts that must survive helper calls in the same shell:
`_oci_auth_mode`, `_oci_zone_lookup_authz_error`, `_domain`, `_domain_id`,
`_oci_record_domain`, and mock capture variables.

### No Secret Persistence

Only API-key account config values use `_saveaccountconf_mutable`. Resource
principal variables should never be saved or cleared through account config
helpers.

### Stable Diagnostics

Tests should assert hook-owned substrings:

- variable names such as `OCI_CLI_TENANCY` and `OCI_RESOURCE_PRINCIPAL_RPST`;
- mode facts such as `_oci_auth_mode=resource_principal`;
- boundary text such as `resource principal` and `signing is not implemented`;
- absence of `PATCH|/20180115/zones/` for pre-signing failures.

## Landmines

- Do not make `_oci_config` a generic all-auth function.
- Do not let command substitution hide `_oci_auth_mode` assignments.
- Do not save RPST, private PEM, region, version, token, or key material.
- Do not make resource principal preferred when API-key auth is complete.
- Do not change `_signed_request` API-key signature construction in Phase 3.
- Do not assert exact Oracle-owned error prose.

---

*Phase: 03-authentication-selection-refactor*
