# Phase 5: Documentation and Release Verification - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase finishes the v1 OCI DNS subzones and resource-principal milestone by
documenting the provider surface and capturing release verification. It updates
the OCI DNS provider metadata in `dnsapi/dns_oci.sh`, produces wiki-ready
operator guidance for delegated subzones, API-key auth, resource-principal
fallback, OCI policy expectations, and known validation boundaries, then runs
the final mocked/static verification suite for the changed OCI hook and local
test harness.

This phase does not change runtime authentication behavior, require live OCI DNS
or OCI-hosted resource-principal credentials, broaden verification to unrelated
shell files, or expand `dnsapi/README.md` beyond its existing pointer role.
Live OCI validation remains deferred from v1 and should be captured as a future
v2 checklist rather than a Phase 5 completion gate.

</domain>

<decisions>
## Implementation Decisions

### Documentation Shape
- **D-01:** Update the `dns_oci_info` provider metadata in `dnsapi/dns_oci.sh`
  so acme.sh's provider metadata describes API-key auth, resource-principal
  fallback, delegated subzone support, and policy expectations accurately.
- **D-02:** Produce a concise wiki-ready OCI DNS guide in the Phase 5 release or
  verification artifacts. The guide should be suitable for maintainers to copy
  into the upstream wiki page referenced by `dns_oci_info`.
- **D-03:** Keep `dnsapi/README.md` in its current lightweight pointer role.
  Do not add long provider-specific documentation there unless planning proves a
  tiny pointer adjustment is necessary.
- **D-04:** Avoid a broad README rewrite. Main repo `README.md` already points
  DNS API users to the wiki and should not become the OCI provider guide.

### Resource Principal Setup Wording
- **D-05:** Document resource-principal setup as an operator recipe, not only an
  environment variable list.
- **D-06:** State the authentication order plainly: complete OCI CLI /
  `OCI_CLI_*` API-key configuration is primary; resource principal auth is used
  only when key-based auth cannot be configured and the resource-principal
  environment is complete.
- **D-07:** Document the supported resource-principal version as
  `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`.
- **D-08:** Document required resource-principal values:
  `OCI_RESOURCE_PRINCIPAL_RPST`, `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
  `OCI_RESOURCE_PRINCIPAL_REGION`; document
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` as optional.
- **D-09:** Explain that RPST, private PEM, and optional passphrase values use
  the implementation's path-first, inline-fallback contract. If the value names
  a readable file, the hook reads the current file contents for the signed
  request; otherwise it treats the value as inline material.
- **D-10:** Include safe, minimal OCI policy examples for DNS zone read and
  record mutation. The examples should be framed as starting points operators
  must adapt to their compartment/zone model, not as universal tenancy policy.
- **D-11:** Make the secret-handling contract visible: resource-principal token,
  private key, passphrase, Authorization header, signing string, and signatures
  are not persisted to account/domain config or emitted through normal logs.

### Verification Bar
- **D-12:** Treat touched-scope gates plus a freshness audit as the Phase 5
  release bar.
- **D-13:** Run the full mocked OCI hook suite with `sh test/dns_oci_mock.sh`.
- **D-14:** Run ShellCheck against the changed OCI hook and local test harness:
  `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`.
- **D-15:** Run shfmt on the changed shell files and require a clean diff:
  `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`.
- **D-16:** Verify docs and provider metadata content directly. The release
  record should name the metadata/doc artifacts checked and the facts they
  cover rather than relying only on shell tests.
- **D-17:** Record current tool versions and latest-version checks for
  ShellCheck, shfmt, OpenSSL, and GSD. The Phase 5 record may note that local
  OpenSSL `3.6.2` is the latest 3.6 release while OpenSSL `4.0.0` is the newest
  upstream series; the hook should continue using `${ACME_OPENSSL_BIN:-openssl}`
  and not require an OpenSSL major-version upgrade.
- **D-18:** Do not let unrelated repo-wide shell or CI issues block v1 release
  verification unless they affect `dnsapi/dns_oci.sh`, `test/dns_oci_mock.sh`,
  or the generated docs/metadata. Record unrelated problems if discovered, but
  keep the Phase 5 gate scoped.

### Deferred Live Validation
- **D-19:** State that v1 completion does not require live OCI credentials, a
  disposable OCI DNS zone, or an OCI-hosted resource-principal workload.
- **D-20:** Capture a concrete v2 live-validation checklist covering an
  optional disposable-zone DNS smoke test for API-key auth, an OCI-hosted
  resource-principal smoke test, wildcard/delegated-subzone issuance, cleanup
  proof, and confirmation that no RP secrets are persisted or normal-logged in a
  real run.
- **D-21:** Keep the v2 live checklist separate from the Phase 5 pass/fail
  verdict so v1 remains honest: mocked/static proof is sufficient for this
  milestone, live OCI proof is intentionally deferred.

### the agent's Discretion
The planner may choose the exact shape and filename of the wiki-ready release
guidance artifact inside the Phase 5 directory. The planner may choose the exact
policy wording and examples after checking current Oracle docs, as long as the
examples stay minimal, safe, and clearly adaptable. The planner may include a
small direct `dns_oci_info` metadata assertion in `test/dns_oci_mock.sh` or a
separate docs check if that is the cleanest way to make metadata drift
testable.

</decisions>

<specifics>
## Specific Ideas

- Keep the user-facing docs practical: "use API key config if you already have
  it; use resource principal for OCI-hosted automation when no complete API-key
  config is available."
- The wiki-ready guide should explain delegated subzone behavior in operator
  terms: the hook chooses the most specific accessible OCI DNS zone for the
  `_acme-challenge` FQDN and falls back to an accessible parent when the
  delegated candidate is unavailable.
- Policy examples should be minimal and careful, for example starting from DNS
  zone read plus record update permissions scoped to the relevant compartment.
- The release verification should name any live OCI checks not run and point to
  the v2 checklist rather than implying they passed.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and Milestone Scope
- `.planning/PROJECT.md` - Project scope, constraints, active requirements, and
  key decisions.
- `.planning/REQUIREMENTS.md` - Phase 5 requirements DOC-01, DOC-02, and
  TEST-03.
- `.planning/ROADMAP.md` - Phase 5 goal, success criteria, and planned work
  split.
- `.planning/STATE.md` - Current milestone and session state.
- `.planning/phases/04-resource-principal-signing/04-VERIFICATION.md` - Phase 4
  proof, final mocked/static commands, and deferred live-validation boundary.
- `.planning/phases/04-resource-principal-signing/04-CONTEXT.md` - Locked
  resource-principal signing, logging, and verification decisions that docs must
  describe accurately.
- `.planning/phases/03-authentication-selection-refactor/03-CONTEXT.md` - Locked
  API-key-first fallback and no-resource-principal-persistence decisions.
- `.planning/phases/02-delegated-zone-discovery-and-txt-payloads/02-CONTEXT.md`
  - Locked delegated-zone, wildcard, fallback, and TXT payload behavior.

### Existing Code, Docs, and Tests
- `dnsapi/dns_oci.sh` - OCI DNS provider implementation and `dns_oci_info`
  metadata under change.
- `test/dns_oci_mock.sh` - Mocked shell harness and final Phase 5 regression
  target.
- `dnsapi/README.md` - DNS API docs pointer; should stay lightweight unless a
  minimal pointer adjustment is required.
- `README.md` - Main user guide; already points DNS API users to the wiki and
  should not become the OCI provider guide.
- `.github/workflows/shellcheck.yml` - Existing ShellCheck/shfmt CI pattern and
  upstream-pinned shfmt version context.
- `.planning/codebase/CONVENTIONS.md` - POSIX shell style, provider metadata,
  logging, and linting conventions.
- `.planning/codebase/STRUCTURE.md` - Docs, DNS hook, test harness, and workflow
  file locations.

### External References
- `https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsaccessingociresources.htm`
  - OCI Functions resource-principal v2.2 environment variables and `ST$`
  security-token signing example.
- `https://docs.oracle.com/en-us/iaas/Content/bigdata/manage-cluster-resource-principal-access-token-env-var.htm`
  - Oracle resource-principal environment variable setup for RPST/private PEM
  paths and region.
- `https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/policygetstarted.htm`
  - OCI policy syntax and policy-writing reference for safe operator guidance.
- `https://docs.oracle.com/en-us/iaas/Content/DNS/Tasks/managingdnszones.htm`
  - OCI DNS zone management context for policy and delegated-zone wording.
- `https://github.com/acmesh-official/acme.sh/wiki/How-to-use-Oracle-Cloud-Infrastructure-DNS`
  - Existing upstream OCI DNS wiki page referenced by provider metadata.
- `https://github.com/koalaman/shellcheck/releases` - ShellCheck latest release
  reference for the freshness audit.
- `https://github.com/mvdan/sh` - shfmt latest release reference for the
  freshness audit.
- `https://mirror.openssl-library.org/source/` - OpenSSL release table for the
  freshness audit.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dnsapi/dns_oci.sh`: Top-level `dns_oci_info` metadata already contains site,
  docs, options, issue, and author fields. Phase 5 should update this small
  block rather than inventing a separate provider registry.
- `dnsapi/dns_oci.sh`: Runtime behavior already includes API-key-first auth
  selection, resource-principal v2.2 loading/signing, delegated-zone selection,
  wildcard coverage, and secure logging boundaries from Phases 2-4.
- `test/dns_oci_mock.sh`: Full mocked suite reported 37 cases in Phase 4 and is
  the right regression target for Phase 5.
- `dnsapi/README.md`: This file currently only links to the DNS API wiki, so
  detailed OCI docs should live as wiki-ready text instead of bloating the
  pointer.

### Established Patterns
- Runtime hook code stays POSIX `sh`, uses two-space `shfmt`, and avoids new
  SDKs, package managers, or live credential dependencies.
- Provider metadata lives in each DNS hook's `dns_*_info` variable and may use a
  ShellCheck `SC2034` suppression because metadata variables are consumed
  indirectly by acme.sh.
- Sensitive values belong behind `_secure_debug*`; normal logs and planning
  docs must not include real tokens, keys, passphrases, signatures, or
  Authorization headers.
- acme.sh documentation usually points provider-specific DNS setup to the wiki
  instead of large in-repo provider guides.

### Integration Points
- `dns_oci_info` is the in-repo metadata surface users and maintainers can
  inspect directly.
- The wiki-ready guide should match the existing docs URL in `dns_oci_info` so
  maintainers can update the same upstream page without hunting for a target.
- Final verification should record both behavioral proof (`test/dns_oci_mock.sh`)
  and documentation proof (metadata plus wiki-ready guidance covers DOC-01 and
  DOC-02).

</code_context>

<deferred>
## Deferred Ideas

- Live OCI DNS disposable-zone smoke testing is deferred to v2.
- OCI-hosted resource-principal smoke testing is deferred to v2.
- Broader DNS provider conformance or acmetest integration is deferred to a
  future provider-quality phase, not Phase 5.

</deferred>

---

*Phase: 5-documentation-and-release-verification*
*Context gathered: 2026-05-15*
