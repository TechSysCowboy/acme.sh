# Phase 4: Resource Principal Signing - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase implements OCI resource-principal request signing in `dnsapi/dns_oci.sh`
at the Phase 3 auth-selection boundary. Existing API-key auth remains primary.
When `_oci_auth_mode=resource_principal`, OCI DNS zone `GET` and records `PATCH`
requests must be signed with OCI resource-principal session-token credentials
instead of tenancy/user/fingerprint API-key credentials.

This phase covers resource-principal material loading, Authorization header
construction, secure logging boundaries, and mocked shell-level proof. It does
not add user-facing documentation, change delegated-zone or TXT payload behavior,
prefer resource-principal auth over complete API-key auth, add an SDK/runtime
dependency, or require live OCI resource-principal smoke testing.

</domain>

<decisions>
## Implementation Decisions

### Material Loading Contract
- **D-01:** Support `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`,
  `OCI_RESOURCE_PRINCIPAL_REGION`, `OCI_RESOURCE_PRINCIPAL_RPST`,
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE`.
- **D-02:** Load `OCI_RESOURCE_PRINCIPAL_RPST`,
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` with a path-first,
  inline-fallback contract. If the environment value points to an existing file,
  read that file; otherwise treat the value as the inline token, PEM, or
  passphrase content.
- **D-03:** Read path-backed resource-principal material per signed request. Do
  not cache RPST, private PEM, or passphrase values in long-lived globals.
- **D-04:** Passphrase support is in scope for Phase 4. It should follow the
  same path-first, inline-fallback contract as RPST and private PEM.
- **D-05:** Normal operator errors for loading failures may name the relevant
  environment variable and failure class, but must not print environment values,
  filesystem paths, token fragments, private key material, passphrases, signing
  strings, signatures, or Authorization headers.

### Signer Shape
- **D-06:** Keep `_signed_request` as the single request boundary used by zone
  `GET` and record `PATCH`. Replace the Phase 3 not-implemented guard with a
  dispatcher to private helpers for API-key signing and resource-principal
  signing.
- **D-07:** Preserve existing API-key signing behavior behind a private helper,
  such as `_signed_request_api_key`. Add resource-principal signing behind a
  private helper, such as `_signed_request_resource_principal`.
- **D-08:** Resource-principal Authorization uses `keyId="ST$<rpst>"`.
  Do not parse RPST claims to derive a custom key identifier, and do not reuse
  the tenancy/user/fingerprint API-key shape for resource-principal requests.
- **D-09:** Sign the same standard OCI header set the current signer uses:
  `date`, `(request-target)`, and `host` for `GET`; add `x-content-sha256`,
  `content-type`, and `content-length` for requests with a JSON body such as
  `PATCH`.
- **D-10:** Reuse the existing temp-key-file and OpenSSL signing pattern. The
  implementation should write ephemeral PEM material to `_mktemp`, sign, and
  remove the temp file immediately.

### Failure And Logging Policy
- **D-11:** Resource-principal material loading or signing failures during zone
  lookup are terminal auth failures. Set a private auth/signing error flag so
  `_get_zone` stops walking parent labels and does not emit misleading
  "zone not found" diagnostics after a signing failure.
- **D-12:** Normal logs may reveal mode and variable names only, such as
  `resource principal`, `_oci_auth_mode=resource_principal`, and relevant
  `OCI_RESOURCE_PRINCIPAL_*` names. They must not reveal values, paths, private
  key material, passphrases, derived Authorization headers, signatures, or
  signing strings.
- **D-13:** `_secure_debug*` may capture sensitive signing internals needed for
  deep troubleshooting, including RPST, private PEM material, signing string,
  and Authorization header. Passphrase handling should be limited to presence or
  comparable non-value diagnostics unless a narrower implementation need proves
  otherwise.
- **D-14:** Passphrase failures should get an env-name-only diagnostic naming
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` and the failure class. Do not
  include passphrase value, path, or raw OpenSSL error detail in normal logs.

### Verification Bar
- **D-15:** Mocked exact header/request proof is sufficient for Phase 4. Live OCI
  resource-principal smoke testing remains out of scope for this phase.
- **D-16:** Tests must assert the `ST$` keyId shape, signed header list, signing
  string, body hash and length, `GET` and `PATCH` flow, no RP persistence, and
  clean normal logs.
- **D-17:** Tests must cover both path-backed and inline RP material, including
  passphrase behavior.
- **D-18:** Tests must prove per-request refresh by simulating file contents
  changing between zone `GET` and records `PATCH` and asserting the later request
  uses the updated RPST and key material.
- **D-19:** Passphrase tests must cover both success and failure: an
  encrypted/passphrase-backed signing path succeeds through the mocked signer
  path, and wrong or missing passphrase fails with clean env-name-only
  diagnostics.

### the agent's Discretion
The planner may choose exact private helper names, the exact private auth error
flag name, and the smallest helper decomposition that keeps `_signed_request` as
the public request boundary. If current `_sign` cannot support passphrase-backed
private keys directly, the planner may add a local wrapper or minimal helper
around the same existing temp-file/OpenSSL pattern, as long as no new runtime
dependency is introduced and secret/path logging rules stay intact.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and Milestone Scope
- `.planning/PROJECT.md` - Project scope, constraints, active requirements, and
  key decisions.
- `.planning/REQUIREMENTS.md` - Phase 4 requirements RP-01, RP-02, RP-03, and
  RP-04; also v1 out-of-scope boundary for live OCI credentials.
- `.planning/ROADMAP.md` - Phase 4 goal, success criteria, dependencies, and
  planned work split.
- `.planning/STATE.md` - Current milestone and session state.
- `.planning/phases/03-authentication-selection-refactor/03-CONTEXT.md` - Locked
  Phase 3 decisions for API-key primacy, `_oci_auth_mode`, no RP persistence,
  and the Phase 4 signing boundary.
- `.planning/phases/03-authentication-selection-refactor/03-VERIFICATION.md` -
  Evidence that Phase 3 leaves RP mode at a clean not-implemented signing
  boundary.

### Existing Code and Tests
- `dnsapi/dns_oci.sh` - OCI DNS provider implementation under change.
- `test/dns_oci_mock.sh` - Mocked shell harness to extend for exact
  resource-principal signing proof.
- `.planning/codebase/STACK.md` - POSIX shell runtime, dependency, and
  verification constraints.
- `.planning/codebase/ARCHITECTURE.md` - Hook plugin architecture, DNS-01 flow,
  logging, persistence, and provider boundaries.
- `.planning/codebase/INTEGRATIONS.md` - DNS provider, OCI, GitHub Actions, and
  acmetest integration context.

### External OCI References
- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm` -
  OCI Functions resource-principal v2.2 environment variables, file-backed RPST
  and private PEM, and custom signer example using `ST$`.
- `https://docs.oracle.com/en-us/iaas/tools/java/latest/com/oracle/bmc/auth/ResourcePrincipalAuthenticationDetailsProvider.html` -
  Current Java SDK v2.2 contract for path-first vs inline RPST/private PEM and
  optional passphrase, including file-backed refresh behavior.
- `https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm` -
  OCI request signing header requirements, RSA-SHA256 algorithm, signature
  version, and body-header requirements.
- `https://docs.oracle.com/en-us/iaas/tools/ruby/2.21.0/OCI/Auth/Signers/SecurityTokenSigner.html` -
  OCI security-token signer behavior for `ST$<security_token>`, passphrase, and
  generic/body header sets.
- `https://docs.oracle.com/en-us/iaas/tools/python/latest/api/signing.html` -
  Current Python SDK signing reference for cross-checking OCI signer behavior.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dnsapi/dns_oci.sh`: `_oci_select_auth` already sets `_oci_auth_mode` to
  `api_key` or `resource_principal`, with API-key config preferred.
- `dnsapi/dns_oci.sh`: `_signed_request` is currently the shared request boundary
  for zone lookup `GET` and records `PATCH`.
- `dnsapi/dns_oci.sh`: `_signed_request` already builds `date`, `host`,
  `(request-target)`, body hash/type/length headers, signing string, and
  Authorization for API-key mode.
- `dnsapi/dns_oci.sh`: `_digest`, `_sign`, `_mktemp`, and `_secure_debug3` are
  already used by the API-key signing path.
- `dnsapi/dns_oci.sh`: `_get_zone` already has `_oci_zone_lookup_authz_error` to
  stop misleading zone fallback on authorization-like failures; Phase 4 can add
  an RP load/sign failure signal beside that pattern.
- `test/dns_oci_mock.sh`: The harness already captures normal debug, secure
  debug, errors, signed requests, saved keys, cleared keys, and readini calls.

### Established Patterns
- Runtime code stays POSIX shell and uses existing acme.sh helpers; no SDK,
  package manager, Python runtime, or OCI CLI signer is added.
- API-key auth remains primary when complete; resource principal is fallback
  only after API-key config cannot be completed.
- Durable API-key config may be persisted through existing account config
  helpers. Resource-principal version, region, token, private key, passphrase,
  paths, derived headers, and signing state remain process-local only.
- Sensitive values belong behind `_secure_debug*`; normal debug/info/error logs
  protect tokens, keys, signatures, passphrases, and Authorization headers.
- Mocked shell-level proof is the readiness bar for v1. Live OCI validation is a
  later release/UAT concern.

### Integration Points
- `_oci_resource_principal_configured` is the existing detector and may need to
  account for optional passphrase without making passphrase required.
- `_signed_request` is the dispatch point to preserve the provider boundary for
  both add and remove flows.
- `_get_zone` must treat RP load/sign errors as terminal auth failures and avoid
  continuing the label walk after a signing problem.
- `dns_oci_add` and `dns_oci_rm` must continue to use the selected zone and TXT
  payload behavior from Phase 2.
- `test/dns_oci_mock.sh` should extend the existing public-path tests rather
  than introducing live OCI dependencies.

</code_context>

<specifics>
## Specific Ideas

- Use `keyId="ST$<rpst>"` for the resource-principal Authorization header.
- Prefer file-backed RPST/private PEM/passphrase reads when the env value names
  an existing file, because that allows token/key refresh between signed
  requests.
- Keep path names out of normal logs even though paths can help operators debug
  mounts; the user chose the stricter secret-handling contract.
- Exact test proof should include changed file contents between `GET` and
  `PATCH`, not just static fixtures.
- Passphrase support is in scope now, so planning should not defer encrypted-key
  behavior to a later phase.

</specifics>

<deferred>
## Deferred Ideas

- Live OCI resource-principal validation inside an OCI-hosted workload remains
  deferred to later release qualification/UAT.
- User-facing documentation for API-key auth, resource-principal auth, delegated
  subzones, and OCI policy expectations remains Phase 5 scope.
- Broader DNS-provider conformance coverage remains outside this OCI-specific
  phase.

</deferred>

---

*Phase: 4-Resource Principal Signing*
*Context gathered: 2026-05-15*
