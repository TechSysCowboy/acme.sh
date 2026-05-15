# OCI DNS Subzones and Resource Principal Auth

## What This Is

This project extends the existing `dnsapi/dns_oci.sh` provider hook in `acme.sh`.
It makes OCI DNS-01 issuance work when the correct target zone is a delegated
subzone such as `x.domain.com` for a certificate request like `*.x.domain.com`,
and it adds OCI resource principal authentication for workloads running inside
OCI without long-lived user API keys.

The work is for acme.sh users who already use OCI DNS, especially operators
issuing wildcard or delegated-subdomain certificates from compute, functions, or
other OCI-hosted automation.

## Core Value

OCI DNS validation must choose the right zone and authenticate safely without
breaking existing key-based OCI users.

## Current Milestone: v1.0 OCI DNS Subzones and Resource Principal Auth

**Goal:** Make the existing OCI DNS hook correctly handle delegated subzones and
support keyless OCI resource-principal authentication without regressing current
OCI CLI/API-key users.

**Target features:**
- Longest matching accessible OCI DNS zone discovery for delegated subzones.
- Correct TXT add/remove payloads relative to the selected OCI DNS zone.
- Authentication selection that keeps OCI CLI/API-key auth first and falls back
  to resource principal auth only when key-based configuration is unavailable.
- Secure resource principal request signing that avoids persisting ephemeral
  token or private-key material.
- User-facing documentation and mocked shell-level proof for the new behavior.

## Requirements

### Validated

- ✓ acme.sh supports DNS-01 challenge hooks via `dnsapi/*.sh` with provider
  functions named `dns_<provider>_add` and `dns_<provider>_rm` — existing
- ✓ acme.sh supports wildcard certificates and passes `_acme-challenge` FQDNs
  into DNS provider hooks for TXT add/remove operations — existing
- ✓ The OCI DNS hook can add and remove TXT records through the OCI DNS REST API
  using OCI CLI config or `OCI_CLI_*` environment variables — existing
- ✓ The OCI DNS hook signs OCI API requests in POSIX shell using OpenSSL,
  shared `_get`/`_post` HTTP helpers, and `_secure_debug*` for sensitive
  signing material — existing
- ✓ Provider credentials are read from environment/account config and persisted
  with `_readaccountconf_mutable` and `_saveaccountconf_mutable` patterns —
  existing
- ✓ Project validation relies on ShellCheck, shfmt, GitHub Actions, and external
  acmetest-style integration workflows rather than an in-repo unit test runner
  — existing
- ✓ Mocked shell-level tests cover zone discovery, TXT payload construction,
  auth selection, and signing-path branching without requiring live OCI DNS
  resources — validated in Phase 1
- ✓ OCI DNS zone discovery selects the longest matching accessible OCI DNS
  zone for delegated subzone challenge FQDNs — validated in Phase 2
- ✓ OCI TXT add/remove payloads use the selected zone and preserve correct
  `_acme-challenge` behavior for parent, delegated, and wildcard names —
  validated in Phase 2
- ✓ Existing OCI CLI config and `OCI_CLI_*` API-key authentication remains the
  primary path when configured — validated in Phase 3
- ✓ Resource-principal fallback selection is attempted only after key-based
  configuration fails, remains process-local, and stops before signing in Phase
  3 — validated in Phase 3
- ✓ Missing or incomplete auth configuration distinguishes key-based problems
  from resource-principal configuration problems — validated in Phase 3

### Active

- [ ] Resource principal request signing avoids persisting ephemeral session
  material in acme.sh account config and keeps tokens, private keys, and
  authorization headers out of normal debug logs.
- [ ] The OCI hook documents the supported authentication order, required OCI
  policies, and delegated-subzone behavior in provider metadata and user-facing
  docs.

### Out of Scope

- Rewriting the generic DNS provider hook system — this project should stay
  scoped to `dnsapi/dns_oci.sh` and narrowly needed test/docs support.
- Making resource principal auth preferred over explicit key/config auth —
  existing configured users must keep their current behavior.
- Requiring a live OCI DNS smoke test for v1 completion — useful later, but the
  readiness bar is mocked shell-level proof with no live OCI calls.
- Adding a new runtime language, SDK, or package manager — acme.sh runtime hooks
  must remain POSIX shell and use existing project helpers.
- Solving unrelated provider concerns discovered in the codebase map — these may
  be captured separately but should not expand this project.

## Context

The existing OCI hook is `dnsapi/dns_oci.sh`. It currently reads tenancy, user,
region, and API signing key data from OCI CLI config or `OCI_CLI_*` environment
variables, finds a zone by probing candidate zone names, and signs OCI DNS REST
requests directly in shell.

The relevant runtime architecture is the acme.sh DNS hook plugin layer:
`acme.sh` sources `dnsapi/dns_oci.sh`, calls `dns_oci_add` to create the
challenge TXT record, and later calls `dns_oci_rm` to remove it. The hook must
therefore keep the public add/remove function contract stable and should place
new behavior behind private helpers.

The existing `_get_zone` helper already walks labels in the challenge FQDN and
stops at the first OCI zone endpoint that returns an id. The active subzone
requirement makes that behavior explicit: the first successful match must be the
most specific accessible zone and the derived `_sub_domain` must remain correct
for both add and remove payloads.

The existing authentication path requires API signing key material. Resource
principal auth changes that only when the existing path cannot be configured.
The implementation will likely need to discover OCI resource-principal metadata
or environment values, obtain/use ephemeral signing material, and construct the
correct OCI authorization headers without saving session secrets to account
configuration.

The repo is portability-sensitive. Runtime code targets POSIX `sh`, uses
two-space `shfmt` formatting, avoids `local`, communicates failure through
explicit return status, and uses `_err`, `_debug*`, and `_secure_debug*` logging
helpers. ShellCheck currently does not cover the root `acme.sh` entrypoint by
default, so verification for this project should explicitly include the changed
OCI hook and any local test harness.

## Constraints

- **Compatibility**: Existing `OCI_CLI_*` and OCI CLI config authentication must
  keep working — users may already rely on persisted account configuration.
- **Security**: Resource principal session tokens, private keys, derived
  signatures, and authorization headers must not be logged through normal debug
  helpers or persisted to account/domain config.
- **Portability**: Runtime changes must remain POSIX shell and avoid adding SDKs
  or a language package manager — acme.sh runs across many shells and operating
  systems.
- **Scope**: Changes should stay focused on `dnsapi/dns_oci.sh`, related docs,
  and the smallest practical mocked test support — the provider system as a
  whole is not being refactored.
- **Verification**: v1 proof is mocked shell-level coverage for the new behavior
  plus shell lint/format checks — live OCI credentials are not required to
  finish this project.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use the longest matching accessible OCI DNS zone for delegated subzones | `*.x.domain.com` should target `x.domain.com` when that zone exists and is accessible, not accidentally mutate the parent `domain.com` zone | Validated in Phase 2 |
| Keep OCI CLI key/config auth first and use resource principal auth as fallback | Preserves current user behavior while enabling keyless OCI-hosted automation | Selection boundary validated in Phase 3; RP signing remains Phase 4 |
| Use mocked shell-level tests as the readiness bar | Validates zone discovery and auth branching without requiring live OCI resources or secrets in CI | Validated through Phase 3 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-15 after Phase 3 verification*
