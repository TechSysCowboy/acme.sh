# Phase 1: OCI Hook Characterization and Test Harness - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase creates the proof surface for `dnsapi/dns_oci.sh`. It does not
implement delegated-zone selection or resource principal signing yet; it builds
the local shell harness and required mocked cases so later phases can change the
OCI hook with fast regression proof and a clear live-UAT path.

</domain>

<decisions>
## Implementation Decisions

### Harness Shape
- **D-01:** Build a repo-local, acmetest-style shell harness first.
- **D-02:** Shape the harness so its cases can later be ported into `acmesh-official/acmetest`.
- **D-03:** Follow the current acmetest model: shell-only, `le_test_*` case functions, `CASE` selection, `RUN_SCRIPT` compatibility, and no runtime package manager.
- **D-04:** Treat live OCI DNS smoke as a UAT checkpoint, not the automated gate.

### Mock Boundary
- **D-05:** Use provider-boundary mocked tests: source `acme.sh` and `dnsapi/dns_oci.sh`, then stub `_signed_request` plus account config helpers.
- **D-06:** The harness should exercise the public DNS hook path through `dns_oci_add` and `dns_oci_rm`, plus private behavior reached through that path such as `_get_zone`, auth selection, and payload construction.
- **D-07:** Avoid an HTTP-boundary test in Phase 1. `_get`/`_post` and private-key/OpenSSL signing setup can be covered later if needed, but they would make the characterization harness more brittle than useful.

### Proof Matrix
- **D-08:** Use a core-plus-edge proof matrix for Phase 1.
- **D-09:** Required mocked zone/payload cases: parent zone, delegated subzone, fallback to parent, no-zone failure, and add/remove symmetry.
- **D-10:** Required mocked auth/security cases: API-key auth first, resource-principal fallback, missing-auth failure, and secure-log checks.
- **D-11:** Live proof should be acmetest-compatible and may use a sacrificial domain/subzone supplied by the operator. It is evidence for UAT/final signoff, not the normal automated regression path.

### the agent's Discretion
The planner may choose the exact local filename and helper layout, but the
result should remain small, POSIX-shell friendly, acmetest-shaped, and easy to
copy or adapt into upstream acmetest.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and Milestone Scope
- `.planning/PROJECT.md` — Project scope, constraints, active requirements, and key decisions.
- `.planning/REQUIREMENTS.md` — Phase 1 requirement mapping for TEST-01 and TEST-02.
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, and planned work split.
- `.planning/STATE.md` — Current milestone and session state.

### Existing Code and Patterns
- `dnsapi/dns_oci.sh` — OCI DNS provider under test.
- `.planning/codebase/ARCHITECTURE.md` — Hook plugin architecture and DNS-01 flow.
- `.planning/codebase/STACK.md` — Shell runtime, dependency, and verification constraints.
- `.planning/codebase/STRUCTURE.md` — Directory layout and where hook/test/support code belongs.
- `.planning/codebase/CONVENTIONS.md` — POSIX shell style, logging, secure-debug, and provider conventions.
- `.planning/codebase/TESTING.md` — Existing acmetest/GitHub Actions verification model.

### External Test Reference
- `https://github.com/acmesh-official/acmetest` — Canonical acme.sh unit/integration test project. Current checked `master` SHA during discussion: `d63b75bc5d02df13ccccef70e3f0a53dc6ef9b8e`. The relevant shape is `letest.sh` with `le_test_*` cases and `CASE` selection, plus `rundocker.sh`/`runplat.sh` support for `RUN_SCRIPT`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dnsapi/dns_oci.sh`: Public functions `dns_oci_add` and `dns_oci_rm` are the right harness entry points.
- `dnsapi/dns_oci.sh`: Private `_get_zone` already walks labels and calls `_signed_request "GET" "/20180115/zones/$h" "" "id"`, which makes `_signed_request` a clean mocked provider boundary.
- `dnsapi/dns_oci.sh`: `_oci_config` currently owns OCI CLI config/env loading and account config persistence; tests need stubs for `_readaccountconf_mutable`, `_saveaccountconf_mutable`, `_clearaccountconf_mutable`, and `_readini`.
- `acme.sh`: Shared helpers provide `_initpath`, logging, config helpers, `_digest`, `_base64`, `_dbase64`, `_mktemp`, `_upper_case`, and `_lower_case`.

### Established Patterns
- Runtime and test support should remain POSIX shell and use two-space shfmt formatting.
- DNS hooks are dynamically sourced provider modules; tests should exercise the same public add/remove contract used by acme.sh.
- Sensitive values must be logged only through `_secure_debug*`; normal `_debug*` output is not acceptable for tokens, keys, signatures, or Authorization headers.
- Existing repository CI relies on external acmetest for integration behavior, so local tests should complement that pattern and remain portable to it.

### Integration Points
- Later implementation phases will change `dnsapi/dns_oci.sh`; Phase 1 should give them stable mocked assertions before those edits begin.
- Live UAT should map to the existing acmetest DNS API flow with `TEST_DNS=dns_oci`, `TestingDomain`, optional subdomain/wildcard controls, and operator-supplied OCI credentials.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly pointed to `https://github.com/acmesh-official/acmetest` as the reference home for acme.sh unit tests.
- The user is willing to use one of their domains as a sacrificial live-test domain for infrequent OCI smoke testing.
- Live proof is useful, but the default development loop should stay mocked and deterministic.

</specifics>

<deferred>
## Deferred Ideas

- Upstreaming the local OCI mocked case into `acmesh-official/acmetest` is desirable after the repo-local shape proves useful.
- Deeper HTTP-boundary or signing-boundary tests can be considered after Phase 4 if provider-boundary coverage leaves a real gap.
- Live OCI DNS smoke execution is deferred to UAT/final verification rather than Phase 1 automated completion.

</deferred>

---

*Phase: 1-OCI Hook Characterization and Test Harness*
*Context gathered: 2026-05-15*
