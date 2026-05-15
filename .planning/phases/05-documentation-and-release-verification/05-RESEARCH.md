# Phase 5 Research: Documentation and Release Verification

**Date:** 2026-05-15
**Status:** Complete

## Scope

Phase 5 closes the v1 OCI DNS milestone by documenting the behavior already
implemented in Phases 2-4 and recording the final mocked/static release proof.
The research focus was deliberately narrow:

- Current OCI resource-principal environment contracts.
- Current OCI DNS policy resource types and minimal permissions for zone lookup
  and TXT record mutation.
- Current local and upstream tooling versions for ShellCheck, shfmt, OpenSSL,
  Node, and GSD.
- Existing repo documentation conventions for DNS provider guidance.

## Findings

### OCI Resource Principal Contract

Oracle's OCI Functions documentation still documents the custom resource
principal v2.2 environment surface used by this hook:

- `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`
- `OCI_RESOURCE_PRINCIPAL_RPST`
- `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`
- `OCI_RESOURCE_PRINCIPAL_REGION`

It also describes custom provider code that reads RPST and private PEM values
from paths, creates an OCI request signature, and uses an `ST$<rpst>` key id
shape for resource-principal signing.

Oracle's Big Data Service resource-principal page independently documents the
same required environment variable names and example v2.2 values, with RPST and
private PEM as absolute file paths.

**Planning impact:** Phase 5 docs should state the hook supports the v2.2
environment contract, path-first inline fallback, and optional
`OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` because that optional
passphrase is an implementation extension already covered by Phase 4 tests.
The docs should not claim RP v3 support.

### OCI DNS Policy Contract

Oracle's DNS policy reference lists `dns-zones` and `dns-records` as individual
DNS resource types. It documents:

- `read dns-zones` covers `GetZone` and `GetZoneRecords`.
- `use dns-records` covers record mutation APIs including
  `PatchDomainRecords`, `UpdateDomainRecords`, `PatchRRSet`,
  `UpdateRRSet`, `UpdateZoneRecords`, and `PatchZoneRecords`.
- `target.dns-zone.name`, `target.dns-record.type`, and
  `target.dns-domain.name` can be used to narrow policy conditions.

**Planning impact:** The wiki-ready guide should use conservative starting
policies such as `read dns-zones` plus `use dns-records`, and frame any
`target.*` conditions as optional scoping examples operators must adapt to
their tenancy, compartment, public/private DNS scope, and zone model.

### Tool Freshness

Local versions checked during planning:

| Tool | Local version | Current-source check |
|------|---------------|----------------------|
| ShellCheck | `0.11.0` | GitHub latest release is `v0.11.0`. |
| shfmt | `3.13.1` | `mvdan/sh` latest release is `v3.13.1`. |
| OpenSSL | `3.6.2` | OpenSSL source table lists `3.6.2` as latest 3.6 release and `4.0.0` as newest upstream series. |
| Node | `v26.0.0` | `brew outdated --quiet shellcheck shfmt node` reported no outdated formulae. |
| npm | `11.12.1` | Recorded for reproducibility; no runtime npm dependency is introduced. |
| GSD | `1.42.2` | `node .codex/get-shit-done/bin/check-latest-version.cjs` reported `1.42.2`. |

`brew outdated --quiet shellcheck shfmt node` produced no outdated package
names. The attempted formula check for `get-shit-done-cc` returned "No
available formula"; GSD freshness is therefore checked through the repo's
`check-latest-version.cjs` helper instead.

**Planning impact:** Phase 5 should record these versions again in the final
verification artifact and should not require an OpenSSL 4 upgrade. The hook
continues to use `${ACME_OPENSSL_BIN:-openssl}`.

### Repo Documentation Pattern

`dnsapi/README.md` remains a lightweight pointer to the acme.sh DNS API wiki.
Provider-specific OCI guidance is already represented by the `Docs:` field in
`dns_oci_info`, which points at the upstream OCI DNS wiki page.

**Planning impact:** Keep detailed OCI setup guidance as a Phase 5 wiki-ready
artifact, not as a large `dnsapi/README.md` expansion. Update provider metadata
and stale inline comments in `dnsapi/dns_oci.sh`; add test coverage so metadata
drift is visible in the local harness.

## Sources

- Oracle Functions resource principal docs:
  https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm
- Oracle Big Data Service resource principal environment docs:
  https://docs.oracle.com/en-us/iaas/Content/bigdata/manage-cluster-resource-principal-access-token-env-var.htm
- Oracle DNS policy reference:
  https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/dnspolicyreference.htm
- Oracle DNS zone management docs:
  https://docs.oracle.com/en-us/iaas/Content/DNS/Tasks/managingdnszones.htm
- ShellCheck releases:
  https://github.com/koalaman/shellcheck/releases
- shfmt releases:
  https://github.com/mvdan/sh/releases
- OpenSSL source releases:
  https://mirror.openssl-library.org/source/

