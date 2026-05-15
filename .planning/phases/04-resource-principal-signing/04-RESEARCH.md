# Phase 4: Resource Principal Signing - Research

**Researched:** 2026-05-15
**Status:** Ready for planning

## User Constraints

### Locked Decisions from CONTEXT.md

- **D-01:** Support `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`,
  `OCI_RESOURCE_PRINCIPAL_REGION`, `OCI_RESOURCE_PRINCIPAL_RPST`,
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE`.
- **D-02:** Load RPST, private PEM, and passphrase with a path-first,
  inline-fallback contract. Existing readable files win; otherwise the env
  value is treated as the direct token, PEM, or passphrase value.
- **D-03:** Read path-backed material per signed request. Do not cache RPST,
  private PEM, or passphrase values in globals.
- **D-04:** Passphrase support is in scope now.
- **D-05:** Normal load/signing errors may name env vars and failure classes,
  but must not print values, paths, token fragments, private keys, passphrases,
  signing strings, signatures, or Authorization headers.
- **D-06:** Keep `_signed_request` as the single request boundary and dispatch
  to private API-key and resource-principal signing helpers.
- **D-07:** Preserve existing API-key signing behind a private helper.
- **D-08:** Resource-principal Authorization uses `keyId="ST$<rpst>"`.
- **D-09:** Sign the same OCI header set the API-key path uses: `date`,
  `(request-target)`, and `host` for `GET`; add `x-content-sha256`,
  `content-type`, and `content-length` when a JSON body is present.
- **D-10:** Reuse the existing temp-key-file and OpenSSL signing pattern, with a
  minimal passphrase-capable wrapper if `_sign` is insufficient.
- **D-11:** RP load/sign failures during zone lookup are terminal auth failures;
  `_get_zone` must not continue walking labels and then report a misleading
  zone-not-found error.
- **D-12:** Normal logs may reveal only mode and variable names, not secret
  values, paths, headers, signing strings, or signatures.
- **D-13:** `_secure_debug*` may capture RPST, private PEM material, signing
  string, and Authorization header for deep troubleshooting. Passphrase logging
  should stay to presence or non-value diagnostics.
- **D-14:** Passphrase failures get env-name-only diagnostics naming
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` and the failure class.
- **D-15:** Mocked exact header/request proof is sufficient for Phase 4.
- **D-16:** Tests must assert `ST$` keyId shape, signed header list, signing
  string, body hash/length, `GET` and `PATCH` flow, no RP persistence, and
  clean normal logs.
- **D-17:** Tests must cover path-backed and inline RP material, including
  passphrase behavior.
- **D-18:** Tests must prove per-request refresh by changing file contents
  between zone `GET` and records `PATCH`.
- **D-19:** Passphrase tests must cover success and failure.

### the agent's Discretion

The planner may choose exact helper names and the smallest helper decomposition
that keeps `_signed_request` as the public request boundary. A minimal
passphrase-specific signing helper may call OpenSSL directly with the same
temp-file pattern if the existing `_sign` helper cannot pass a passphrase.

## RESEARCH COMPLETE

Phase 4 should be implemented as a narrow signer replacement at the Phase 3
boundary. Keep `_signed_request` as a dispatcher, move the existing API-key
logic into `_signed_request_api_key`, and add `_signed_request_resource_principal`
that loads RP material per request, builds the same signing string/header set,
uses `keyId="ST$<rpst>"`, signs with the ephemeral PEM, and routes sensitive
details only through `_secure_debug*`.

## Current Reference Snapshot

- Oracle Functions docs still document resource-principal v2.2 environment
  variables for functions: `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`,
  `OCI_RESOURCE_PRINCIPAL_RPST`, `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_REGION`. They describe loading the RPST and private
  key from the paths and then using them to create OCI request signatures.
  [VERIFIED: Oracle Functions docs, 2026-05-15]
- Oracle Java SDK latest docs currently permit several RP versions, including
  `3.0`, but the v2.2 contract still matches this phase: `RPST` and
  `PRIVATE_PEM` may each be an existing file path or an inline value, file mode
  supports refresh, `PRIVATE_PEM_PASSPHRASE` is optional and may also be a path
  or value, and `REGION` identifies the local region. Phase 4 intentionally
  supports v2.2 only because the context locked that scope.
  [VERIFIED: Oracle Java SDK latest docs, 2026-05-15]
- Oracle Terraform provider docs also describe resource-principal auth using
  version `2.2`, RPST raw content or absolute path, private PEM path, and
  region. This confirms that raw RPST is a supported surface, while the hook
  remains provider-independent and must not add Terraform as a dependency.
  [VERIFIED: Oracle Terraform provider docs, 2026-05-15]
- Oracle request-signature docs still require Signature authorization, RSA-SHA256,
  version `1`, `date` or `x-date`, `host`, and `(request-target)` for GET-like
  requests; requests with bodies must include `x-content-sha256`,
  `content-type`, and `content-length`.
  [VERIFIED: Oracle API signing docs, 2026-05-15]
- Oracle Python SDK latest docs are at `oci 2.174.0` and document
  `SecurityTokenSigner(token, private_key, generic_headers=['date',
  '(request-target)', 'host'], body_headers=['content-length', 'content-type',
  'x-content-sha256'])`. This matches the header set chosen in D-09.
  [VERIFIED: Oracle Python SDK latest docs, 2026-05-15]
- Oracle Ruby SDK `SecurityTokenSigner` wraps the token key identifier as
  `ST$#{security_token}` and accepts an optional private-key passphrase. This
  confirms D-08 and D-19.
  [VERIFIED: Oracle Ruby SDK docs, 2026-05-15]
- Local OpenSSL is `OpenSSL 3.6.2 7 Apr 2026`. The official OpenSSL download
  table currently lists `4.0.0` as the newest series and `3.6.2` as the latest
  3.6 release. acme.sh should keep using `${ACME_OPENSSL_BIN:-openssl}` and not
  require an upgrade; local `openssl dgst -help` confirms `-passin` is available
  for passphrase-backed signing.
  [VERIFIED: local OpenSSL plus OpenSSL download table, 2026-05-15]
- Local ShellCheck is `0.11.0`, and GitHub marks `v0.11.0` as latest. Local
  shfmt is `3.13.1`, and the `mvdan/sh` GitHub release list marks `v3.13.1` as
  latest. Phase 4 can keep the established static gates without installing
  tools.
  [VERIFIED: local CLI plus official GitHub releases, 2026-05-15]

## Standard Stack

- Runtime code remains POSIX `sh` in `dnsapi/dns_oci.sh`.
- No OCI SDK, OCI CLI signer, Python, Node, package manager, or live OCI DNS
  dependency is added.
- Tests remain in `test/dns_oci_mock.sh`, using `le_test_*` discovery, `CASE=`
  filtering, temp-backed captures, and lower HTTP/signing stubs.
- Verification remains mocked shell-level proof plus ShellCheck/shfmt gates.

## Architecture Patterns

### Material Loading

Use a helper cluster that reads material only inside the RP signing path:

- `_oci_read_resource_principal_value VAR_NAME required_flag` reads the current
  env value, treats it as a file path only if `[ -f "$value" ]`, and otherwise
  returns the inline value.
- `_oci_load_resource_principal_material` fills request-local globals such as
  `_rpst`, `_rp_private_pem`, and `_rp_private_pem_passphrase` immediately before
  signing. These globals may exist only for the duration of the request and
  should be reset after the signing attempt.
- Missing required values return 1 with env-name-only diagnostics.
- Optional passphrase missing is not an error.

### Signer Dispatch

Keep `_signed_request` as:

```sh
_signed_request() {
  case "$_oci_auth_mode" in
  resource_principal) _signed_request_resource_principal "$@" ;;
  *) _signed_request_api_key "$@" ;;
  esac
}
```

Move the current body of `_signed_request` into `_signed_request_api_key`
unchanged except for function name and local helper extraction needed to avoid
duplication.

### Shared Header Construction

The API-key and RP helpers should share the current ordering and semantics:

- signing string order: `(request-target)`, `date`, `host`, body hash, body type,
  body length;
- Authorization `headers` field: `(request-target) date host` plus
  `x-content-sha256 content-type content-length` when body is present;
- exported `_H1`..`_H5` layout remains compatible with `_get` and `_post`.

### Passphrase Signing

`acme.sh` `_sign` accepts only a key file and hash algorithm. Add the smallest
OCI-local wrapper, for example `_oci_sign_with_private_key_file`, that:

- delegates to `_sign "$keyfile" sha256` when no passphrase is provided;
- runs `${ACME_OPENSSL_BIN:-openssl} dgst -sha256 -sign "$keyfile" -passin
  file:"$passphrase_file"` (or equivalent shell-safe option order) when a
  passphrase is provided;
- base64-encodes the binary signature with `_base64`;
- writes passphrase content to a temp file and removes both temp files before
  returning.

Do not pass a passphrase value directly on the command line.

### Terminal Auth Failure

Add a private `_oci_signing_auth_error` or equivalent flag. If RP material
loading or signing fails during zone lookup, `_get_zone` should stop immediately
and `_get_oci_zone` should return 1 without emitting the generic zone-not-found
message.

## Do Not Hand-Roll

- Do not parse RPST claims for tenancy or compartment in Phase 4.
- Do not support RP v3.0 in this phase despite the latest Java SDK listing it.
- Do not change API-key auth precedence.
- Do not persist RP env names, paths, token values, PEM material, passphrases,
  signatures, or Authorization headers.
- Do not make normal debug/error logs include paths or secret-derived values.
- Do not introduce a generic credential framework across DNS providers.

## Common Pitfalls

- A readable file path must be re-read for each signed request; reading once
  during auth selection will fail D-03 and D-18.
- Command substitution can hide side effects. Use process-local globals only for
  intentionally local request facts, and reset them after use.
- `_get_zone` currently treats empty signing responses like lookup misses. RP
  load/sign failures need a separate terminal-auth signal.
- Existing tests override `_signed_request`; Phase 4 tests that assert exact
  Authorization headers must restore the real `_signed_request` and stub only
  `_get`, `_post`, `_sign`, `_mktemp`, and OpenSSL-dependent lower edges.
- OpenSSL passphrase diagnostics can include values or paths. Normal hook errors
  must replace them with env-name-only messages.

## Validation Architecture

### Automated Commands

- Loader cases:
  `CASE=le_test_oci_rp_loads_inline_material,le_test_oci_rp_loads_path_material sh test/dns_oci_mock.sh`
- GET/PATCH signer cases:
  `CASE=le_test_oci_rp_signs_get_with_st_key_id,le_test_oci_rp_signs_patch_body_headers sh test/dns_oci_mock.sh`
- Refresh and persistence cases:
  `CASE=le_test_oci_rp_refreshes_path_material_between_requests,le_test_oci_rp_does_not_persist_or_normal_log_material sh test/dns_oci_mock.sh`
- Passphrase cases:
  `CASE=le_test_oci_rp_passphrase_success,le_test_oci_rp_passphrase_failure_is_clean sh test/dns_oci_mock.sh`
- Full mocked suite:
  `sh test/dns_oci_mock.sh`
- Static:
  `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- Formatting:
  `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`

### Security Validation

- No test uses real OCI config, live OCI DNS, live RPST, or live private key
  material.
- Normal logs may contain resource-principal mode and env var names only.
- Secure debug may contain signing internals, but passphrase value assertions
  must stay negative unless execution proves a narrower need.
- Failure tests must check both return status and absence of PATCH mutation.

## Sources

- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm`
- `https://docs.oracle.com/en-us/iaas/tools/java/latest/com/oracle/bmc/auth/ResourcePrincipalAuthenticationDetailsProvider.html`
- `https://docs.oracle.com/en-us/iaas/Content/dev/terraform/configuring.htm`
- `https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm`
- `https://docs.oracle.com/en-us/iaas/tools/python/latest/api/signing.html`
- `https://docs.oracle.com/en-us/iaas/tools/ruby/2.21.0/OCI/Auth/Signers/SecurityTokenSigner.html`
- `https://mirror.openssl-library.org/source/`
- `https://github.com/koalaman/shellcheck/releases/tag/v0.11.0`
- `https://github.com/mvdan/sh/releases/tag/v3.13.1`

---

*Phase: 04-resource-principal-signing*
*Research completed: 2026-05-15*
