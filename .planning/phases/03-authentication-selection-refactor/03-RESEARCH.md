# Phase 3: Authentication Selection Refactor - Research

**Researched:** 2026-05-15
**Status:** Ready for planning

## User Constraints

### Locked Decisions from CONTEXT.md

- **D-01:** Use a small auth-mode selector boundary. Phase 3 should introduce a
  private selected-mode variable, such as `_oci_auth_mode`, plus helper(s) that
  decide between API-key auth and resource-principal fallback.
- **D-02:** Keep `_oci_config` API-key focused. It should continue to load,
  validate, and persist OCI CLI / `OCI_CLI_*` settings rather than becoming a
  generic all-auth configuration function.
- **D-03:** Store the selected mode in a private global instead of returning it
  through command substitution. This matches the existing shell style and avoids
  losing side effects in subshells.
- **D-04:** Keep the current API-key `_signed_request` implementation unchanged
  in Phase 3. Add only the mode gate needed to fail cleanly when
  `resource_principal` is selected before Phase 4 signing exists.
- **D-05:** Consider resource-principal fallback only after the complete API-key
  path fails to configure.
- **D-06:** Partial API-key configuration should not block resource-principal
  fallback when a valid resource-principal environment is present. The hook must
  keep a clear diagnostic that names the missing key-based pieces.
- **D-07:** Resource-principal fallback should require a supported
  `OCI_RESOURCE_PRINCIPAL_VERSION` plus the expected token, private-key, and
  region signals before marking the mode available.
- **D-08:** Phase 3 should verify the exact current OCI resource-principal
  environment variable shape against official Oracle docs before finalizing the
  implementation. The discussion-time docs pointed to version `2.2` with
  `OCI_RESOURCE_PRINCIPAL_REGION`, `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_RPST`.
- **D-09:** When resource-principal fallback is selected in Phase 3, public
  add/remove calls should fail before signing or PATCH with a stable diagnostic
  that resource principal was detected but signing is not implemented yet.
- **D-10:** Preserve existing saved `OCI_CLI_*` account configuration when a run
  falls back to resource principal. Do not clear saved key config just because
  the current operation uses fallback.
- **D-11:** Save nothing resource-principal-related to account config. Version,
  region, token paths, private-key paths, tokens, keys, and detection booleans
  all remain process-local.
- **D-12:** Keep key-path failure diagnostics process-local. They may be emitted
  in the failure/fallback path, but must not be persisted.
- **D-13:** When complete API-key config and complete resource-principal env are
  both present, API-key auth wins. Preserve current API-key persistence behavior
  and do not normal-log or persist resource-principal presence.
- **D-14:** Phase 3 public-path proof should cover API-key success,
  partial-key-to-resource-principal boundary, missing-all-auth failure, and
  API-key-wins-over-resource-principal behavior.
- **D-15:** Use `dns_oci_add` as the main public matrix path and add one focused
  `dns_oci_rm` smoke case to prove remove also runs through auth selection.
- **D-16:** Resource-principal fallback tests should assert public failure before
  PATCH plus internal mode/log facts, including `_oci_auth_mode=resource_principal`
  and no resource-principal persistence.
- **D-17:** Diagnostic assertions should use stable substrings, not exact full
  messages. The tests should protect durable facts such as missing key field
  names, resource-principal detection, and signing-not-implemented wording.

### the agent's Discretion

The planner may choose exact helper names and whether the selector is one helper
or a small helper cluster. The planner may choose the exact stable diagnostic
phrases as long as AUTH-03 remains testable without brittle full-message
matches. The planner should verify the latest official OCI documentation before
locking exact supported resource-principal version handling.

### Deferred Ideas

- Actual resource-principal Authorization header construction and signing belong
  to Phase 4.
- Live OCI resource-principal smoke testing remains deferred to later UAT/final
  verification, not Phase 3 completion.

## RESEARCH COMPLETE

Phase 3 should be planned as a narrow auth-selector refactor. The existing
API-key `_signed_request` path should remain the primary signing path, while a
new process-local `_oci_auth_mode` selector records either `api_key` or
`resource_principal`. Resource-principal mode is only a Phase 3 boundary: it
detects the official environment shape and then fails before signing or PATCH
with stable diagnostics for Phase 4 to replace with real signing.

## Current Reference Snapshot

- Oracle Functions docs currently name `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`,
  `OCI_RESOURCE_PRINCIPAL_RPST`, `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_REGION` for resource-principal access. [VERIFIED:
  Oracle Functions docs, 2026-05-15]
- Oracle Big Data Service docs also document the same version/token/key/region
  environment variables for resource-principal session token consumption.
  [VERIFIED: Oracle Big Data Service docs, 2026-05-15]
- Oracle Python SDK latest signing docs expose token/private-key signers, with
  default generic headers `date`, `(request-target)`, and `host`, and body
  headers `content-length`, `content-type`, and `x-content-sha256`. That aligns
  with the current OCI API-key signing shape, but Phase 3 must not implement the
  token signer yet. [VERIFIED: Oracle Python SDK latest docs, 2026-05-15]
- Oracle request-signature docs still describe Signature version `1` and the
  request header syntax used by the existing API-key path. [VERIFIED: Oracle
  API docs, 2026-05-15]
- Local ShellCheck is `0.11.0`; current upstream ShellCheck latest is `v0.11.0`.
  Local `shfmt` is `3.13.1`; current upstream `shfmt` latest is `v3.13.1`.
  [VERIFIED: local CLI plus official GitHub releases, 2026-05-15]

## Standard Stack

- Runtime code remains POSIX `sh` in `dnsapi/dns_oci.sh`; no Bash arrays,
  Python, Node, OCI SDK, package manager, or live OCI calls.
- Test proof remains `test/dns_oci_mock.sh`, using `le_test_*` cases,
  `CASE=` filtering, temp-backed captures, and provider-boundary stubs.
- Static gates remain `sh test/dns_oci_mock.sh`, `shellcheck -e SC2181 -e SC2089
  test/dns_oci_mock.sh dnsapi/dns_oci.sh`, and `shfmt -l -w -i 2
  test/dns_oci_mock.sh dnsapi/dns_oci.sh` when formatting is part of execution.
- No new dependency is needed for Phase 3. The latest relevant verifier versions
  were checked above to satisfy the repo instruction before planning.

## Architecture Patterns

### Auth Selection Boundary

Use a selector helper cluster with process-local globals rather than command
substitution. A good shape is:

- `_oci_auth_mode=""` reset at the start of selection.
- `_oci_select_auth` calls `_oci_config` first.
- If `_oci_config` succeeds, set `_oci_auth_mode="api_key"` and continue.
- If `_oci_config` fails, retain key-path diagnostic facts in process-local
  variables or logs, then evaluate `_oci_resource_principal_configured`.
- If the resource-principal env shape is complete and version is supported, set
  `_oci_auth_mode="resource_principal"`.
- If neither path is usable, return failure with diagnostics that mention both
  the key-based problem and missing/incomplete resource-principal variables.

### API-Key Preservation

Keep `_oci_config` responsible for OCI CLI config, `OCI_CLI_*` values, key-file
loading, key decoding, and durable account config persistence. Do not make it
read or persist resource-principal variables. If extra diagnostic capture is
needed, use private `_oci_api_key_config_error`-style variables or stable `_err`
lines.

### Resource-Principal Phase 3 Boundary

Do not attempt Phase 4 signing. When `_oci_auth_mode=resource_principal`, the
public add/remove path should fail before any OCI DNS mutation. The most direct
place is a guard at the top of `_signed_request`, because all zone lookup and
PATCH calls already pass through it. The guard should emit a stable diagnostic
such as `resource principal auth detected but signing is not implemented yet`
and return non-zero without constructing API-key Authorization headers.

### Persistence and Logging

Resource-principal version, RPST, private PEM, and region are ephemeral runtime
inputs. They must not go through `_saveaccountconf_mutable`,
`_clearaccountconf_mutable`, normal `_debug`, or `_info`. The tests should
assert resource-principal strings never appear in saved keys, cleared keys,
normal debug, or normal info output.

## Do Not Hand-Roll

- Do not build an OCI SDK substitute in Phase 3.
- Do not parse or sign RPST tokens in Phase 3; Phase 4 owns token/private-key
  loading and signature construction.
- Do not build a full OCI simulator in `test/dns_oci_mock.sh`.
- Do not add a generic credential framework across providers.
- Do not change zone discovery, TXT payload construction, JSON escaping, or
  API-key signing beyond the auth-mode gate needed for Phase 3.

## Common Pitfalls

- Returning selected mode from a helper through command substitution loses shell
  side effects in the same way earlier harness observations did. Use globals.
- Letting `_oci_config` fail early can hide the resource-principal fallback path.
  The selector must call `_oci_config`, observe failure, then decide whether RP
  is complete.
- Partial API-key config plus complete RP env is not the same as missing all
  auth. Tests must distinguish this from true missing-all-auth.
- Complete API-key config plus complete RP env must stay on the API-key path.
- `OCI_RESOURCE_PRINCIPAL_RPST` may be a path or raw token in some Oracle
  surfaces, but the Phase 3 detector only needs to prove the expected signal is
  present. Phase 4 will decide file/raw token loading behavior.
- Diagnostics should use stable hook-owned substrings and variable names; do
  not assert exact Oracle-owned prose.

## Code Examples

```sh
# Selector shape only; exact names can vary during execution.
_oci_select_auth() {
  _oci_auth_mode=""
  if _oci_config; then
    _oci_auth_mode="api_key"
    return 0
  fi

  if _oci_resource_principal_configured; then
    _oci_auth_mode="resource_principal"
    return 0
  fi

  _err "Error: OCI API-key authentication is incomplete."
  _err "Error: OCI resource principal authentication is incomplete."
  return 1
}
```

```sh
_signed_request() {
  if [ "$_oci_auth_mode" = "resource_principal" ]; then
    _err "Error: resource principal auth detected but signing is not implemented yet."
    return 1
  fi

  # Existing API-key signing remains below.
}
```

## Validation Architecture

### Automated Commands

- Full baseline: `sh test/dns_oci_mock.sh`
- Selector smoke: `CASE=le_test_oci_auth_api_key,le_test_oci_auth_resource_principal_detected_boundary sh test/dns_oci_mock.sh`
- Fallback and missing auth: `CASE=le_test_oci_auth_partial_key_falls_back_to_resource_principal,le_test_oci_auth_missing_reports_both_paths sh test/dns_oci_mock.sh`
- Persistence: `CASE=le_test_oci_auth_api_key_wins_over_resource_principal,le_test_oci_auth_resource_principal_does_not_persist,le_test_oci_auth_oci_cli_config_file_primary sh test/dns_oci_mock.sh`
- Remove smoke: `CASE=le_test_oci_rm_uses_auth_selector sh test/dns_oci_mock.sh`
- Static: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- Formatting: `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`

### Sampling

- After every task commit: run the task-specific `CASE=... sh test/dns_oci_mock.sh`.
- After every plan wave: run `sh test/dns_oci_mock.sh`.
- Before phase closeout: run full harness, ShellCheck, and shfmt.
- Max feedback latency: under 10 seconds for mocked shell tests.

### Security Validation

- No test may require real OCI config, real key files, RPST files, private PEM
  files, or live OCI DNS.
- Resource-principal values must not be saved to account config.
- Resource-principal values must not appear in normal debug/info/error logs
  except for variable names and non-secret diagnostics.
- API-key signing must remain first and must not normal-log resource-principal
  presence when API-key config is complete.

## Sources

- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm`
- `https://docs.oracle.com/en-us/iaas/Content/bigdata/manage-cluster-resource-principal-access-token-env-var.htm`
- `https://docs.oracle.com/en-us/iaas/tools/python/latest/api/signing.html`
- `https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm`
- `https://github.com/koalaman/shellcheck/releases`
- `https://github.com/mvdan/sh`

---

*Phase: 03-authentication-selection-refactor*
*Research completed: 2026-05-15*
