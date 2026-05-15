# Phase 04 Pattern Map

**Generated:** 2026-05-15
**Status:** Ready for planning

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `dnsapi/dns_oci.sh` | DNS provider hook | resource-principal material loading and request signing | existing `_signed_request`, `_oci_config`, `_get_zone`, `_digest`, `_sign`, `_mktemp`, `_secure_debug3` | exact |
| `test/dns_oci_mock.sh` | shell test harness | public add/remove fixtures plus exact signed-header assertions | existing auth matrix, return-field parser fixture, temp-backed captures | exact |

## Pattern Assignments

### `dnsapi/dns_oci.sh` (provider hook, RP signer)

**Analog:** existing API-key `_signed_request`.

**Current signing pattern:**

- `_signed_request` receives method, target, body, and optional return field.
- It builds `date`, `(request-target)`, `host`, body hash/type/length headers,
  signing string, Authorization header, exported `_H*` headers, and then calls
  `_get` or `_post`.
- Sensitive body and Authorization values use `_secure_debug3`.
- It writes private key material to `_mktemp`, signs through `_sign`, and
  removes the temp file.

**Phase 4 insertion point:**

- Keep `_signed_request` as the dispatcher.
- Move the existing API-key body into `_signed_request_api_key`.
- Add `_signed_request_resource_principal` with the same call signature.
- Use request-local material loading before signing.
- Add a private signing/auth failure flag for terminal zone-lookup failures.

**Do not change:**

- `dns_oci_add` / `dns_oci_rm` public signatures.
- Phase 2 selected-zone and full-FQDN TXT payload behavior.
- API-key auth precedence or persistence.
- The `_get` / `_post` header export contract.

### `test/dns_oci_mock.sh` (mock harness, exact signing proof)

**Analog:** existing `le_test_oci_signed_request_return_field` and Phase 3
auth tests.

**Harness pattern:**

- Use `_reset_oci_mocks` for baseline env/captures.
- Use temp files under `$_DNS_OCI_MOCK_DIR` for RPST, PEM, passphrase, and
  captured signing inputs.
- Use `CASE=` for task-specific verification.
- Use stable substring assertions, not full error text.

**Exact signer pattern:**

- For legacy zone/payload tests, keep the current `_signed_request` stub.
- For Phase 4 exact signer tests, re-source `dnsapi/dns_oci.sh` to restore the
  real `_signed_request`, then stub `_get`, `_post`, `_sign`, `_mktemp`, and
  any lower OpenSSL boundary needed by the test.
- Capture exported `_H1`..`_H5`, signing strings, temp key contents, and normal
  versus secure logs.

## Shared Patterns

### Path-First Inline Fallback

Use `[ -f "$value" ]` as the only file-mode test. If true, read that path.
Otherwise use the env value as inline material. Do not require absolute paths
because the Java SDK contract says "existing file path", while OCI Functions
normally supplies absolute paths.

### Per-Request Refresh

Do not load RP material in `_oci_select_auth`. Selection only proves the env
shape is complete. `_signed_request_resource_principal` must load material for
each GET and each PATCH so a path-backed RPST/private PEM change between
requests is observable.

### Secret Boundaries

Allowed in normal logs:

- `resource principal`
- `_oci_auth_mode=resource_principal`
- env variable names such as `OCI_RESOURCE_PRINCIPAL_RPST`
- non-value failure classes such as `missing`, `unreadable`, or `signing failed`

Allowed only in secure debug:

- RPST token values
- private PEM material
- signing string
- Authorization header
- signature

Never log normally or persist:

- RPST value or path
- private PEM value or path
- passphrase value or path
- `ST$<rpst>` keyId
- Authorization header
- signing string or signature

### Terminal Auth Failure

Follow `_oci_zone_lookup_authz_error`: set a private flag before returning from
`_signed_request_resource_principal` on load/sign failures. `_get_zone` should
see that flag and return immediately, and `_get_oci_zone` should not emit the
generic zone-not-found message.

## Landmines

- Existing `_sign` does not accept a passphrase. Do not force passphrases into
  command-line arguments; use a temp passphrase file or equivalent OpenSSL
  `-passin` source.
- Existing tests that override `_signed_request` will not exercise real
  Authorization construction. New signer tests need a separate real-signer
  harness path.
- Do not clear or save `OCI_RESOURCE_PRINCIPAL_*` names. Even clearing calls are
  persisted side effects in the mock captures.
- Do not support Java SDK RP v3.0 in this phase unless the phase context is
  explicitly reopened.
- Do not make a failed RP load look like a missing DNS zone.

---

*Phase: 04-resource-principal-signing*
