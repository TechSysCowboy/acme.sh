# Phase 1: OCI Hook Characterization and Test Harness - Research

**Researched:** 2026-05-15
**Status:** Ready for planning

## RESEARCH COMPLETE

Phase 1 should build a repo-local POSIX shell harness that behaves like a small
acmetest script while staying deterministic and credential-free. The harness can
source `acme.sh` and `dnsapi/dns_oci.sh` by using a no-op positional argument
guard before sourcing `acme.sh`, then overriding provider-boundary helpers such
as `_signed_request`, account config helpers, and debug helpers after both files
are loaded.

## Current Reference Snapshot

- `acmesh-official/acmetest` current `master`/`HEAD`: `d63b75bc5d02df13ccccef70e3f0a53dc6ef9b8e`.
- Local ShellCheck: `0.11.0`, which matches the latest release found during research.
- Local `shfmt`: not installed. The repo CI downloads `shfmt` `v3.1.2`; current upstream `mvdan/sh` release is `v3.13.1`, so any future formatter dependency change should update that pin deliberately.
- `gsd` local and npm version were already checked as `1.41.2`.

## Findings

### acmetest Shape

The upstream acmetest script model is intentionally plain shell:

- Test cases are functions named `le_test_*`.
- `CASE` selects one or more case functions.
- `RUN_SCRIPT` lets `rundocker.sh` and `runplat.sh` run a custom script.
- Assertions are shell exit status plus simple `_assert*` helpers.
- DNS API live coverage uses `TEST_DNS`, `TestingDomain`, `TEST_DNS_NO_WILDCARD`, `TEST_DNS_NO_SUBDOMAIN`, and `TEST_DNS_SLEEP`.

For this repo, the portable form is `test/dns_oci_mock.sh`. acmetest can invoke
it later with `RUN_SCRIPT=acme.sh/test/dns_oci_mock.sh` after this repository is
copied into the acmetest working tree.

### Safe Local Sourcing

`acme.sh` ends by calling `main "$@"`, so the harness cannot source it naked.
The safe pattern is:

1. Save the test script's original positional arguments.
2. Define a no-op function, for example `__dns_oci_test_noop() { :; }`.
3. Temporarily set `set -- __dns_oci_test_noop`.
4. Source `./acme.sh`.
5. Restore the test script arguments.
6. Source `./dnsapi/dns_oci.sh`.
7. Override helpers needed for mocks and assertions.

This keeps the harness close to runtime behavior without running install, issue,
or other CLI commands during test bootstrap.

### Mock Boundary

The provider-boundary mock should replace `_signed_request`, not `_get` and
`_post`, for most Phase 1 tests. That lets `dns_oci_add`, `dns_oci_rm`,
`_get_oci_zone`, `_oci_config`, and `_get_zone` run through the same public hook
entry points used by acme.sh while avoiding real OCI calls and OpenSSL signing.

The harness should keep scenario state in plain shell variables:

- `MOCK_OCI_ZONES`: whitespace-separated accessible zone names.
- `MOCK_SIGNED_REQUESTS`: append-only capture of `METHOD|TARGET|BODY|FIELD`.
- `MOCK_SAVED_KEYS`, `MOCK_CLEARED_KEYS`: account config persistence captures.
- `MOCK_DEBUG_LOG`, `MOCK_SECURE_DEBUG_LOG`: normal-vs-secure debug captures.

### Coverage Priorities

Phase 1 should prove the current surface before delegated-zone and resource
principal implementation changes land:

- Parent-zone lookup and payload construction through `dns_oci_add`.
- Delegated-zone fixture coverage shaped for Phase 2, even if current behavior
already selects the most specific accessible zone.
- Fallback to parent when a subzone is inaccessible.
- No-zone failure that does not attempt a PATCH.
- Add/remove symmetry for method, path, domain, TXT value, and operation.
- API-key config path succeeds without reading real files.
- Missing auth fails with user-facing errors and without a signed request.
- Resource-principal-only env is characterized as a current failure or pending
fixture until Phase 3/4 flips the expectation to fallback success.
- Secrets and Authorization-like values appear only in secure debug captures.

### Existing Code Concern

`dnsapi/dns_oci.sh` line 293 currently appends a literal `)` to the sanitized
response in the `_signed_request` return-field branch:

```sh
_response="$(echo "$_response" | sed 's/\\\"//g'))"
```

`sh -n dnsapi/dns_oci.sh` passes because this is not a syntax error; it is a
runtime string artifact after command substitution. Since this directly affects
the provider under test, Phase 1 should add a focused characterization check and
then remove the stray literal `)` in the same plan.

## Validation Architecture

### Automated Commands

- Quick harness run: `CASE=le_test_oci_harness_bootstrap sh test/dns_oci_mock.sh`
- Zone/payload run: `CASE=le_test_oci_parent_zone_add,le_test_oci_delegated_zone_add,le_test_oci_parent_fallback,le_test_oci_no_zone_failure,le_test_oci_add_remove_symmetry sh test/dns_oci_mock.sh`
- Auth/security run: `CASE=le_test_oci_auth_api_key,le_test_oci_auth_missing,le_test_oci_auth_resource_principal_current_state,le_test_oci_secure_debug_boundaries sh test/dns_oci_mock.sh`
- Full local suite: `sh test/dns_oci_mock.sh`
- Lint: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- Formatting when `shfmt` is available: `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`

### Sampling

- After every task commit: run the relevant `CASE=... sh test/dns_oci_mock.sh`.
- After every plan: run `sh test/dns_oci_mock.sh`.
- Before phase closeout: run full harness plus ShellCheck. Run shfmt only if the
  executor installs or already has an available `shfmt` binary; record the
  local absence otherwise and leave the repo CI pin update to Phase 5.

### Security Validation

- No test may require real OCI credentials, real OCI config, real RPST files, or
  real private keys.
- Normal debug captures must not contain dummy private key material, RPST-like
  tokens, `Authorization:`, or `ST$`.
- Secure debug captures may contain signed headers or request bodies only when
  a test intentionally exercises that boundary.

## Sources

- `https://github.com/acmesh-official/acmetest` at `d63b75bc5d02df13ccccef70e3f0a53dc6ef9b8e`
- `https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm`
- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm`
- `https://docs.oracle.com/en-us/iaas/tools/go/latest/dns/index.html`
- `https://docs.oracle.com/en-us/iaas/tools/typescript/latest/modules/_dns_lib_model_record_operation_.recordoperation.html`
- `https://github.com/mvdan/sh/releases`

---

*Phase: 01-oci-hook-characterization-and-test-harness*
*Research completed: 2026-05-15*
