# Phase 01 Pattern Map

**Generated:** 2026-05-15
**Status:** Ready for planning

## Target Files

| File | Role | Closest Analog | Notes |
|------|------|----------------|-------|
| `test/dns_oci_mock.sh` | Repo-local acmetest-style mocked harness | `/tmp/acmetest-gsd-ref/letest.sh` | Use `le_test_*` functions, `CASE` selection, exit-status assertions, and plain POSIX shell. |
| `dnsapi/dns_oci.sh` | OCI provider under test | `dnsapi/dns_oci.sh` current code | Phase 1 should only make the minimal verified `_signed_request` return-field artifact fix after adding proof. |

## Patterns To Reuse

### acmetest Runner

- Define cases as `le_test_*`.
- If `$1` is present, treat it as `CASE`.
- Iterate over test function names and run only selected cases.
- Return a summed non-zero result when any case fails.
- Use simple assertion helpers that return `1` on failure.

### Safe `acme.sh` Sourcing

`acme.sh` calls `main "$@"` at EOF. The harness needs a no-op positional guard
before sourcing, then should restore its original arguments before running the
test case loop.

### Provider Boundary Stubs

Override these helpers after sourcing `dnsapi/dns_oci.sh`:

- `_signed_request`
- `_readaccountconf_mutable`
- `_saveaccountconf_mutable`
- `_clearaccountconf_mutable`
- `_readini`
- `_debug`, `_debug2`, `_debug3`
- `_secure_debug`, `_secure_debug2`, `_secure_debug3`

Leave core helper functions such as `_math`, `_lower_case`, `_upper_case`,
`_digest`, `_base64`, `_dbase64`, `_egrep_o`, and `_head_n` from `acme.sh`
available unless a specific test needs a narrower stub.

## Data Flow

```text
le_test_* case
  -> setup mock OCI auth + zone fixtures
  -> dns_oci_add / dns_oci_rm
  -> _get_oci_zone
  -> _oci_config
  -> _get_zone
  -> mocked _signed_request
  -> captured request assertions
```

## Landmines

- Do not source `acme.sh` without the no-op positional guard.
- Do not require real `$HOME/.oci/config`, real key files, RPST files, or live OCI DNS.
- Do not add a package manager, Bats, Python test runner, or Node test runner.
- Do not put resource principal token or private key dummy values into normal debug captures.
- Keep the local live smoke path as documentation or UAT evidence only; it is not part of the default mocked harness.

---

*Phase: 01-oci-hook-characterization-and-test-harness*
