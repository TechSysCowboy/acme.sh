# Phase 5 Patterns: Documentation and Release Verification

**Date:** 2026-05-15
**Status:** Ready for execution

## Documentation Patterns

- Keep `dnsapi/README.md` in its existing wiki-pointer role.
- Treat `dns_oci_info` in `dnsapi/dns_oci.sh` as the in-repo provider metadata
  contract.
- Put detailed user-facing OCI DNS setup guidance in a Phase 5 artifact that is
  ready to publish to the existing upstream wiki page referenced by
  `dns_oci_info`.
- Use placeholder names and OCIDs only. Do not include real tenancy, user,
  dynamic-group, RPST, private key, passphrase, signature, or Authorization
  material.
- Policy examples should be minimal starting points and must say operators
  should scope them to the relevant compartment, zone, and record names.

## Metadata Test Pattern

Add a harness case rather than a free-floating grep so metadata drift is tested
with the same local proof surface as the rest of the OCI hook.

The test should source the real hook through the existing harness and assert:

- `dns_oci_info` mentions delegated subzones or most-specific zone selection.
- `dns_oci_info` mentions API-key auth as primary.
- `dns_oci_info` mentions resource principal fallback.
- `dns_oci_info` lists the supported `OCI_RESOURCE_PRINCIPAL_*` variables,
  including optional `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE`.
- `dnsapi/dns_oci.sh` no longer contains the stale statement that encrypted
  private keys needing a passphrase are unsupported.

## Stale Test/Comment Cleanup Pattern

Phase 4 made resource-principal signing real, so any remaining Phase 3 boundary
comments or test descriptions that say signing is "not implemented" should be
renamed or reworded as current behavior:

- incomplete or unreadable RP material fails before PATCH;
- RP values still are not persisted;
- saved API-key config still survives RP fallback;
- complete API-key config still wins over RP env.

This is a documentation correctness fix inside test/support prose. Keep the
existing behavioral assertions unless execution discovers they are now false.

## Verification Pattern

Use touched-scope gates:

- Full mocked OCI suite: `sh test/dns_oci_mock.sh`
- ShellCheck:
  `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- shfmt:
  `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- Metadata/docs content checks against `dns_oci_info`,
  `05-OCI-DNS-WIKI.md`, and `05-V2-LIVE-VALIDATION.md`.
- Tool freshness capture for ShellCheck, shfmt, OpenSSL, Node, npm, and GSD.

Do not broaden Phase 5 to repo-wide shell files or live OCI tenancy checks.
If an unrelated problem is discovered, record it clearly; fix it only if it
affects `dnsapi/dns_oci.sh`, `test/dns_oci_mock.sh`, or the Phase 5 docs.

