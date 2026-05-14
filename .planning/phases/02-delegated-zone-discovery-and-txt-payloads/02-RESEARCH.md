# Phase 2: Delegated Zone Discovery and TXT Payloads - Research

**Researched:** 2026-05-15
**Status:** Ready for planning

## RESEARCH COMPLETE

Phase 2 should be planned as a small, upstream-friendly shell change centered on
one shared selected-zone/record-owner computation and a focused extension of the
existing mocked harness. The main planning risk is exposing enough OCI lookup
status/error signal to support truthful fallback/debug behavior without turning
this phase into the Phase 3/4 authentication refactor.

## Current Reference Snapshot

- OCI API errors docs confirm `404 NotAuthorizedOrNotFound` can mean either a
  URI resource was not found or the caller is not authorized to access it. The
  same page also documents distinct `401 NotAuthenticated` and `403
  NotAuthorized` cases, so Phase 2 should treat clearly visible auth failures as
  hard failures but keep ambiguous 404/no-id results eligible for parent probing.
- OCI DNS record model docs describe `RecordDetails.domain` as the fully
  qualified domain name where the record can be located. That supports keeping
  the current OCI PATCH `domain` payload shape unless local tests prove it wrong.
- OCI request-signing docs still use Signature Version 1. GET requests require
  `(request-target)`, `host`, and `date`/`x-date`; requests with bodies require
  `x-content-sha256`, `content-type`, and `content-length`. Phase 2 should not
  broaden signing behavior beyond response/status plumbing needed by lookups.
- Local ShellCheck is `0.11.0`; current upstream ShellCheck latest found during
  research is also `0.11.0`.
- Local `shfmt` is absent. Current upstream `shfmt` latest found during research
  is `v3.13.1`; existing repo CI still pins `v3.1.2`, so Phase 2 should not
  install or update formatter dependencies.

## Findings

### Selected-Zone Computation

`_get_zone` already walks labels from most-specific to least-specific and stops
when `_signed_request "GET" "/20180115/zones/$candidate" "" "id"` returns an
id. The Phase 2 change should preserve that shape while making the selected
zone/record-owner result a shared computation for `dns_oci_add` and
`dns_oci_rm`.

The safest plan shape is:

1. Add or reshape a private helper that takes the hook FQDN and sets the same
   globals the existing code expects, such as `_domain`, `_sub_domain`, and
   `_domain_id`, or very close equivalents.
2. Keep `dns_oci_add` and `dns_oci_rm` payload bodies separate.
3. Preserve current normal success text and current PATCH failure hints.
4. Add only a small no-zone hint line.

### OCI Lookup Signal

The current `_signed_request` return-field path returns only the extracted field.
That is enough for current zone discovery but not enough to prove the desired
distinction between:

- usable zone id,
- no usable id / ambiguous miss,
- visible hard auth failure,
- transport/signing failure.

Phase 2 can introduce a narrow lookup-only plumbing mechanism if needed. Good
options include setting private globals after each `_signed_request` call, for
example `_oci_last_http_status`, `_oci_last_error_code`, and
`_oci_last_error_message`, or adding a small lookup wrapper around
`_signed_request` that captures the full response before extracting `id`.

The plan should forbid broad signing refactors and forbid any auth-mode
selection change. The plumbing must remain compatible with later resource
principal signing work, but Phase 2 must not implement RP fallback.

### Fallback Rule

Best-effort parent probing is appropriate for headless automation. The planner
should encode this contract:

- If a candidate returns a usable id, select it.
- If a candidate returns no usable id, malformed JSON, or ambiguous 404/no-id,
  try the parent candidate.
- If a candidate exposes a clear authorization/permission failure, stop and fail
  hard.
- If all candidates are exhausted, fail with the existing no-zone error plus the
  one extra existence/permission hint.
- No no-zone or hard-fail authorization path may attempt a PATCH.

Debug output should report stable facts controlled by the hook or harness:
candidate zone, status/code if available, selected zone, and next candidate.
Tests should not assert exact OCI-owned prose.

### TXT Payload and JSON Escaping

Current `dns_oci.sh` sends a fully qualified `"domain"` value to OCI. Oracle's
model docs support this, and the user confirmed current behavior works for
apex/wildcard apex cases. Do not change that JSON field shape unless execution
proves the current payload is wrong.

The real fix is the selected-zone-relative owner computation that feeds the
current full-FQDN payload. Keep ADD `ttl: 30`; keep REMOVE without TTL.

The existing string-built JSON should be tested for realistic escaping gaps in
`rdata` and record domain values. If a real gap is reproducible, implement a
minimal OCI-local escaping helper or inline escaping. Do not create shared JSON
utilities across acme.sh in this phase.

### Mock Harness Extension

`test/dns_oci_mock.sh` is already the right proof surface. Extend it in the
same acmetest-shaped style:

- keep `le_test_*` cases and `CASE` selection;
- keep provider-boundary stubbing at `_signed_request`;
- extend the mock model just enough to represent status/body/id;
- avoid a mini OCI simulator;
- assert public `dns_oci_add`/`dns_oci_rm` behavior first;
- use helper-level assertions only if public captured requests are too indirect.

## Validation Architecture

### Automated Commands

- Full baseline: `sh test/dns_oci_mock.sh`
- Delegated/wildcard suite: `CASE=le_test_oci_parent_zone_add,le_test_oci_delegated_zone_add,le_test_oci_parent_fallback,le_test_oci_no_zone_failure,le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh`
- Lookup signal suite: `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard sh test/dns_oci_mock.sh`
- Escaping suite: `CASE=le_test_oci_txt_value_json_escape,le_test_oci_record_domain_json_escape sh test/dns_oci_mock.sh`
- Safety suite: `CASE=le_test_oci_no_zone_failure,le_test_oci_lookup_visible_authz_fails_hard sh test/dns_oci_mock.sh`
- Lint: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- Formatting when locally available: `shfmt -l -w -i 2 test/dns_oci_mock.sh dnsapi/dns_oci.sh && git diff --exit-code -- test/dns_oci_mock.sh dnsapi/dns_oci.sh`

### Sampling

- After every task commit: run the task-specific `CASE=... sh test/dns_oci_mock.sh`.
- After every plan wave: run `sh test/dns_oci_mock.sh`.
- Before phase closeout: run full harness plus ShellCheck. Run shfmt only if
  available locally; record absence instead of installing a formatter.
- Max feedback latency: under 10 seconds for mocked shell tests.

### Security Validation

- No test may require real OCI credentials, real OCI config, RPST files, or live
  OCI DNS.
- Normal output and normal debug must not expose tokens, private keys, or
  Authorization headers.
- `_debug2` may be used for non-PII sensitive details such as zone OCIDs.
- `_debug3` should not be used for routine probe facts that do not need deepest
  trace level.

## Sources

- `https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm`
- `https://docs.oracle.com/en-us/iaas/Content/API/Concepts/signingrequests.htm`
- `https://docs.oracle.com/en-us/iaas/Content/DNS/Tasks/record-add.htm`
- `https://docs.oracle.com/en-us/iaas/tools/python/latest/api/dns/models/oci.dns.models.RecordDetails.html`
- `https://github.com/acmesh-official/acmetest`
- `https://github.com/mvdan/sh/releases`
- `https://sourceforge.net/projects/shellcheck.mirror/files/`

---

*Phase: 02-delegated-zone-discovery-and-txt-payloads*
*Research completed: 2026-05-15*
