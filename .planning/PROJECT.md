# OCI DNS Subzones and Resource Principal Auth

## What This Is

This project extends the existing `dnsapi/dns_oci.sh` provider hook in `acme.sh`.
It makes OCI DNS-01 issuance work when the correct target zone is a delegated
subzone such as `x.domain.com` for a certificate request like `*.x.domain.com`,
and it adds OCI resource-principal authentication for workloads running inside
OCI without long-lived user API keys.

The work is for acme.sh users who already use OCI DNS, especially operators
issuing wildcard or delegated-subdomain certificates from compute, functions, or
other OCI-hosted automation.

## Core Value

OCI DNS validation must choose the right zone and authenticate safely without
breaking existing key-based OCI users.

## Milestone Status

v1.0 OCI DNS Subzones and Resource Principal Auth shipped on 2026-05-15.

**Delivered:**
- Longest matching accessible OCI DNS zone discovery for delegated subzones.
- TXT add/remove payload behavior tied to the selected OCI DNS zone.
- Authentication selection that keeps OCI CLI/API-key auth first and falls back
  to resource principal auth only when key-based configuration is unavailable.
- Resource-principal request signing without persisting ephemeral session
  tokens, private keys, passphrases, signatures, or authorization headers.
- Provider metadata, wiki-ready documentation, mocked shell proof, ShellCheck,
  shfmt, and explicit v2 live-validation deferral.

## Requirements

### Validated

- [x] acme.sh supports DNS-01 challenge hooks via `dnsapi/*.sh` with provider
  functions named `dns_<provider>_add` and `dns_<provider>_rm` - existing.
- [x] acme.sh supports wildcard certificates and passes `_acme-challenge` FQDNs
  into DNS provider hooks for TXT add/remove operations - existing.
- [x] The OCI DNS hook can add and remove TXT records through the OCI DNS REST
  API using OCI CLI config or `OCI_CLI_*` environment variables - existing.
- [x] The OCI DNS hook signs OCI API requests in POSIX shell using OpenSSL,
  shared `_get`/`_post` HTTP helpers, and `_secure_debug*` for sensitive
  signing material - existing.
- [x] Provider credentials are read from environment/account config and
  persisted with `_readaccountconf_mutable` and `_saveaccountconf_mutable`
  patterns - existing.
- [x] Project validation relies on ShellCheck, shfmt, GitHub Actions, and
  external acmetest-style integration workflows rather than an in-repo unit test
  runner - existing.
- [x] Mocked shell-level tests cover zone discovery, TXT payload construction,
  auth selection, and signing-path branching without requiring live OCI DNS
  resources - v1.0 Phase 1.
- [x] OCI DNS zone discovery selects the longest matching accessible OCI DNS
  zone for delegated subzone challenge FQDNs - v1.0 Phase 2.
- [x] OCI TXT add/remove payloads use the selected zone and preserve correct
  `_acme-challenge` behavior for parent, delegated, and wildcard names - v1.0
  Phase 2.
- [x] Existing OCI CLI config and `OCI_CLI_*` API-key authentication remains the
  primary path when configured - v1.0 Phase 3.
- [x] Resource-principal fallback selection is attempted only after key-based
  configuration fails and remains process-local - v1.0 Phase 3.
- [x] Missing or incomplete auth configuration distinguishes key-based problems
  from resource-principal configuration problems - v1.0 Phase 3.
- [x] Resource-principal request signing reads session token, private key,
  region, version, and optional passphrase material from OCI-provided
  environment values or referenced files - v1.0 Phase 4.
- [x] OCI DNS GET and PATCH requests can be signed with resource-principal
  session-token credentials using the `ST$` key ID shape - v1.0 Phase 4.
- [x] Resource-principal tokens, private keys, passphrases, signatures, and
  authorization headers are not persisted to acme.sh account/domain config or
  normal debug logs - v1.0 Phase 4.
- [x] The OCI hook documents supported authentication order, required OCI
  policies, delegated-subzone behavior, supported resource-principal variables,
  and v1 validation scope - v1.0 Phase 5.

### Active

- [ ] Decide whether a future milestone should run optional live OCI DNS
  validation against a disposable zone (`LIVE-01`).
- [ ] Decide whether a future milestone should run OCI-hosted
  resource-principal validation during release qualification (`LIVE-02`).
- [ ] Decide whether shared provider conformance coverage belongs in this repo,
  upstream acmetest, or a separate provider-quality milestone (`PROV-01`,
  `PROV-02`).

### Out of Scope

- Rewriting the generic DNS provider hook system - this project stayed scoped to
  `dnsapi/dns_oci.sh` and narrowly needed test/docs support.
- Making resource-principal auth preferred over explicit key/config auth -
  existing configured users must keep their current behavior.
- Requiring a live OCI DNS smoke test for v1 completion - useful later, but the
  v1 readiness bar was mocked shell-level proof with no live OCI calls.
- Adding a new runtime language, SDK, or package manager - acme.sh runtime hooks
  must remain POSIX shell and use existing project helpers.
- Solving unrelated provider concerns discovered in the codebase map - these may
  be captured separately but should not expand this completed project.

## Context

The OCI hook is `dnsapi/dns_oci.sh`. It reads tenancy, user, region, and API
signing key data from OCI CLI config or `OCI_CLI_*` environment variables, finds
the most specific accessible OCI zone by probing candidate zone names, and signs
OCI DNS REST requests directly in shell.

The runtime architecture remains the acme.sh DNS hook plugin layer: `acme.sh`
sources `dnsapi/dns_oci.sh`, calls `dns_oci_add` to create the challenge TXT
record, and later calls `dns_oci_rm` to remove it. The public add/remove
contract stayed stable; new behavior lives behind private helpers.

The v1.0 release added `test/dns_oci_mock.sh`, a POSIX shell mock harness with
38 `le_test_*` cases. The harness covers parent/delegated zone discovery,
ambiguous fallback, hard authz failure, wildcard names, TXT JSON escaping,
API-key auth, resource-principal fallback, resource-principal GET/PATCH signing,
passphrase-backed keys, no-persistence checks, and secure logging boundaries.

The repo is portability-sensitive. Runtime code targets POSIX `sh`, uses
two-space `shfmt` formatting, avoids `local`, communicates failure through
explicit return status, and uses `_err`, `_debug*`, and `_secure_debug*` logging
helpers. v1.0 final verification passed the full mock suite, ShellCheck, shfmt,
and provider documentation checks.

## Constraints

- **Compatibility**: Existing `OCI_CLI_*` and OCI CLI config authentication must
  keep working because users may already rely on persisted account configuration.
- **Security**: Resource-principal session tokens, private keys, passphrases,
  derived signatures, and authorization headers must not be logged through
  normal debug helpers or persisted to account/domain config.
- **Portability**: Runtime changes must remain POSIX shell and avoid adding SDKs
  or a language package manager.
- **Scope**: Changes should stay focused on `dnsapi/dns_oci.sh`, related docs,
  and the smallest practical mocked test support unless a new milestone expands
  the provider-quality surface.
- **Verification**: v1 proof is mocked shell-level coverage plus shell
  lint/format checks. Live OCI credentials remain optional future release
  qualification work.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use the longest matching accessible OCI DNS zone for delegated subzones | `*.x.domain.com` should target `x.domain.com` when that zone exists and is accessible, not accidentally mutate the parent `domain.com` zone | Validated in v1.0 Phase 2 |
| Keep OCI CLI key/config auth first and use resource-principal auth as fallback | Preserves current user behavior while enabling keyless OCI-hosted automation | Selection validated in Phase 3; signing validated in Phase 4 |
| Use mocked shell-level tests as the v1 readiness bar | Validates zone discovery, auth branching, signing, and logging without requiring live OCI resources or secrets in CI | Validated across Phases 1-5 |
| Treat ambiguous `NotAuthorizedOrNotFound` zone lookup as parent-fallback eligible | OCI can hide inaccessible zones behind ambiguous lookup responses, so falling back preserves parent-zone issuance | Validated in Phase 2 |
| Fail hard on clear authorization or permission signals | A visible authz failure should not mutate a parent zone by accident | Validated in Phase 2 |
| Keep OCI PATCH `RecordDetails.domain` as the full FQDN | The selected-zone contract is satisfied by zone/owner selection without changing OCI's expected payload shape | Validated in Phase 2 |
| Keep resource-principal material request-local | Path-backed RPST/private PEM data can rotate and must not be cached or persisted | Validated in Phase 4 |
| Stop zone fallback after resource-principal signing failure | Signing failure is an auth failure, not a missing-zone signal | Validated in Phase 4 |
| Support passphrase-backed resource-principal private keys via temp passphrase files | Allows OpenSSL `-passin file:` without logging or persisting passphrase material | Validated in Phase 4 |
| Keep v1 scoped to OCI resource-principal v2.2 | Oracle documentation shows newer RP surfaces, but Functions/Terraform v2.2 is the locked v1 contract | Validated in Phase 4 and documented in Phase 5 |
| Defer live OCI DNS mutation and OCI-hosted resource-principal smoke tests to v2 | v1 has credential-free proof; live validation needs separate disposable-zone/operator setup | Tracked in `05-V2-LIVE-VALIDATION.md` |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason.
2. Requirements validated? Move to Validated with phase reference.
3. New requirements emerged? Add to Active.
4. Decisions to log? Add to Key Decisions.
5. "What This Is" still accurate? Update if drifted.

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections.
2. Core Value check: still the right priority?
3. Audit Out of Scope: reasons still valid?
4. Update Context with current state.

---
*Last updated: 2026-05-15 after v1.0 milestone close*
