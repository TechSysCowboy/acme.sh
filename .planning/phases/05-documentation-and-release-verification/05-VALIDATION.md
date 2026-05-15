# Phase 5 Validation Plan

**Date:** 2026-05-15
**Status:** Ready for execution

## Required Gates

### Mocked behavior

```sh
sh test/dns_oci_mock.sh
```

Expected result: all OCI mock cases pass. Phase 4 reported 37 `ok` cases; Phase
5 may add a metadata case, so the exact count can increase.

### Focused metadata/docs checks

```sh
CASE=le_test_oci_provider_metadata_documents_current_behavior sh test/dns_oci_mock.sh
```

Expected result: provider metadata covers API-key primary auth,
resource-principal fallback, delegated zone behavior, policy expectations, and
supported RP env variables.

```sh
rg -n "OCI_RESOURCE_PRINCIPAL_VERSION|OCI_RESOURCE_PRINCIPAL_RPST|OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM|OCI_RESOURCE_PRINCIPAL_REGION|OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE|delegated|subzone|API-key|resource principal|read dns-zones|use dns-records" \
  .planning/phases/05-documentation-and-release-verification/05-OCI-DNS-WIKI.md
```

Expected result: wiki-ready guide contains the documented auth, zone, and policy
surface.

```sh
! rg -n "passphrase is not supported|signing is not implemented|before Phase 3/4 fallback|Phase 3 signing boundary" dnsapi/dns_oci.sh test/dns_oci_mock.sh
```

Expected result: stale implementation/comment text is gone from the changed
hook and current test harness prose.

### Static shell validation

```sh
shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh
```

Expected result: exit 0.

```sh
shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh
```

Expected result: shfmt exits 0 and leaves no shell-file diff.

### Freshness audit

```sh
shellcheck --version
shfmt --version
openssl version
node --version
npm --version
node .codex/get-shit-done/bin/check-latest-version.cjs
brew outdated --quiet shellcheck shfmt node || true
```

Expected result: final verification records actual output. A blank
`brew outdated --quiet shellcheck shfmt node` result means Homebrew reports no
outdated formulae for those scoped dependencies.

### Decision coverage

```sh
if command -v gsd-sdk >/dev/null 2>&1; then
  gsd-sdk query check.decision-coverage-verify \
    .planning/phases/05-documentation-and-release-verification \
    .planning/phases/05-documentation-and-release-verification/05-CONTEXT.md
else
  printf '%s\n' "SKIP: gsd-sdk unavailable; decision coverage was checked during planning and must be recorded as skipped in 05-VERIFICATION.md."
fi
```

Expected result: the checker passes when `gsd-sdk` is available. If it is not
available in an execution environment, the executor must record the skip reason
in `05-VERIFICATION.md`; mocked/static/docs gates remain the unconditional
Phase 5 release bar.

## Release Evidence

Plan 05-03 must create:

- `05-VERIFICATION.md`: final verdict, command output summary, requirement
  mapping, tool versions, and explicit live-validation deferral.
- `05-V2-LIVE-VALIDATION.md`: future checklist for disposable-zone API-key
  smoke testing and OCI-hosted resource-principal smoke testing.

## Out of Scope

- Live OCI DNS mutation.
- OCI-hosted resource-principal execution.
- Repo-wide shell lint beyond touched OCI hook/test files.
- New SDKs, package managers, or runtime dependencies.
