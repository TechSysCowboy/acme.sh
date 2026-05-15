# Phase 3: Authentication Selection Refactor - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase refactors `dnsapi/dns_oci.sh` so OCI authentication mode selection is
separate from request signing. Existing OCI CLI / `OCI_CLI_*` API-key
authentication remains the primary path, and resource-principal authentication
gets a clear fallback boundary for Phase 4 to implement signing.

This phase does not implement resource-principal request signing. If the
resource-principal environment is detected, Phase 3 should prove selection and
then fail at an explicit "resource principal signing is not implemented yet"
boundary before any OCI DNS record mutation is attempted.

</domain>

<decisions>
## Implementation Decisions

### Auth Boundary Shape
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

### Fallback Conditions
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

### Persistence Rules
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

### Mock Proof Matrix
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and Milestone Scope
- `.planning/PROJECT.md` - Project scope, constraints, active requirements, and key decisions.
- `.planning/REQUIREMENTS.md` - Phase 3 requirements AUTH-01, AUTH-02, and AUTH-03.
- `.planning/ROADMAP.md` - Phase 3 goal, success criteria, and planned work split.
- `.planning/STATE.md` - Current milestone and session state.
- `.planning/phases/01-oci-hook-characterization-and-test-harness/01-CONTEXT.md` - Harness decisions and current auth/security characterization expectations.
- `.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-CONTEXT.md` - Decisions that auth-mode behavior stayed untouched in Phase 2 and must not regress zone/TXT behavior.

### Existing Code and Tests
- `dnsapi/dns_oci.sh` - OCI DNS provider implementation under change.
- `test/dns_oci_mock.sh` - Mocked shell harness to extend for auth-selection public-path proof.
- `.planning/codebase/STACK.md` - POSIX shell runtime, dependency, and verification constraints.
- `.planning/codebase/ARCHITECTURE.md` - Hook plugin architecture, DNS-01 flow, logging, persistence, and provider boundaries.
- `.planning/codebase/INTEGRATIONS.md` - DNS provider, OCI, GitHub Actions, and acmetest integration context.

### External OCI References
- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsenvironmentvariables.htm` - OCI Functions resource-principal environment variable names.
- `https://docs.oracle.com/en-us/iaas/Content/bigdata/manage-cluster-resource-principal-access-token-env-var.htm` - Oracle resource-principal token/key/region/version environment variable setup.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dnsapi/dns_oci.sh`: `_oci_config` currently owns OCI CLI config/env loading
  and account config persistence. Phase 3 should preserve that role for API-key
  auth.
- `dnsapi/dns_oci.sh`: `_get_oci_zone` calls `_oci_config` before zone lookup;
  the selector boundary likely connects at or just above this point.
- `dnsapi/dns_oci.sh`: `_signed_request` currently implements API-key request
  signing and should remain the API-key path in Phase 3.
- `test/dns_oci_mock.sh`: Existing auth tests cover API-key success, missing
  auth, resource-principal-only current failure, persistence, and secure-debug
  boundaries.

### Established Patterns
- Runtime code stays POSIX shell, uses existing acme.sh helpers, and avoids SDKs
  or package managers.
- Provider credentials are read from environment/account config and persisted
  through existing account config helpers only when durable.
- Sensitive values belong behind `_secure_debug*`; normal debug/info/error logs
  must not expose tokens, private keys, signatures, or Authorization headers.
- Mocked shell-level proof is the readiness bar for v1 auth-selection behavior;
  live OCI validation remains deferred.

### Integration Points
- `dns_oci_add` and `dns_oci_rm` must both use the selected auth mode before any
  zone lookup or PATCH depends on signing.
- The public hook contract remains `dns_oci_add <fqdn> <txt>` and
  `dns_oci_rm <fqdn> <txt>`.
- Phase 4 will implement actual resource-principal signing using the Phase 3
  selector boundary.

</code_context>

<specifics>
## Specific Ideas

- Prefer a private `_oci_auth_mode` global because command substitution has
  already caused side-effect loss in this harness.
- Preserve current API-key behavior for users with complete OCI CLI config or
  complete `OCI_CLI_*` env/account settings.
- Resource-principal fallback is a real runtime path in Phase 3, but it stops
  before signing until Phase 4.
- The current Oracle documentation checked during discussion points to
  `OCI_RESOURCE_PRINCIPAL_VERSION=2.2` with `OCI_RESOURCE_PRINCIPAL_REGION`,
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and `OCI_RESOURCE_PRINCIPAL_RPST`.

</specifics>

<deferred>
## Deferred Ideas

- Actual resource-principal Authorization header construction and signing belong
  to Phase 4.
- Live OCI resource-principal smoke testing remains deferred to later UAT/final
  verification, not Phase 3 completion.

</deferred>

---

*Phase: 3-Authentication Selection Refactor*
*Context gathered: 2026-05-15*
