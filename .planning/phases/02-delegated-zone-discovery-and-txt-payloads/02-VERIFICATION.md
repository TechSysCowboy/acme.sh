---
phase: 02-delegated-zone-discovery-and-txt-payloads
status: passed
score: 10/10
verified: 2026-05-15
requirements_verified: [ZONE-01, ZONE-02, ZONE-03, TXT-01, TXT-02, TXT-03]
human_verification: []
overrides_applied: 0
---

# Phase 2 Verification: Delegated Zone Discovery and TXT Payloads

**Verdict:** Passed. Phase 2 achieved its goal: `dns_oci.sh` now selects the most specific accessible OCI zone, falls back safely when candidates are ambiguous, uses shared add/remove record-domain computation, and proves the behavior through credential-free shell tests.

## Goal Check

**Phase goal:** Make `_get_zone`, `dns_oci_add`, and `dns_oci_rm` select the longest accessible OCI DNS zone and construct TXT record names relative to that selected zone.

**Result:** PASS

- `_get_zone` walks candidate zones and now parses full lookup bodies for id/status/code signal.
- Ambiguous `NotAuthorizedOrNotFound`/no-id responses continue to parent candidates; clear authz/permission signals fail before PATCH.
- `_get_zone` computes `_oci_record_domain` once, and both `dns_oci_add` and `dns_oci_rm` consume it.
- Per Phase 2 context decision D-08, OCI PATCH `RecordDetails.domain` remains the full FQDN; the "relative" contract is satisfied by selected-zone/owner computation rather than changing OCI payload shape.
- No verification command requires live OCI DNS, real OCI config, real private key files, or resource-principal files.

## Requirements

| Requirement | Status | Evidence |
|-------------|--------|----------|
| ZONE-01 | PASS | `le_test_oci_delegated_zone_add` and `le_test_oci_delegated_wildcard_add` pass and assert PATCHes to `/20180115/zones/dev.example.com/records`. |
| ZONE-02 | PASS | `le_test_oci_parent_fallback` and `le_test_oci_lookup_ambiguous_404_falls_back` pass and assert PATCHes to `/20180115/zones/example.com/records`. |
| ZONE-03 | PASS | `le_test_oci_no_zone_failure` and `le_test_oci_lookup_visible_authz_fails_hard` pass and assert no PATCH occurs. |
| TXT-01 | PASS | ADD payload tests cover parent, delegated, apex wildcard, delegated wildcard, fallback, and JSON escaping. |
| TXT-02 | PASS | `le_test_oci_add_remove_symmetry` passes and asserts ADD/REMOVE use the same record domain; ADD has TTL and REMOVE does not. |
| TXT-03 | PASS | Success-message, no-zone, PATCH-failure, debug, and secure-debug tests pass without secret leakage in normal debug. |

## Must-Have Checks

| Check | Status | Evidence |
|-------|--------|----------|
| Longest accessible zone wins | PASS | `le_test_oci_delegated_zone_add` passes with `MOCK_OCI_ZONES="dev.example.com example.com"` and asserts delegated-zone PATCH target. |
| Parent fallback works for inaccessible/ambiguous delegated zone | PASS | `le_test_oci_parent_fallback` and `le_test_oci_lookup_ambiguous_404_falls_back` pass. |
| Clear authz signal fails hard | PASS | `le_test_oci_lookup_visible_authz_fails_hard` passes and asserts no parent fallback and no PATCH. |
| No-zone failure remains explicit | PASS | `le_test_oci_no_zone_failure` passes and asserts the original not-found error plus the read-permission hint. |
| Add/remove share selected record-domain computation | PASS | `dnsapi/dns_oci.sh` sets `_oci_record_domain` during `_get_zone`; both add and remove use it before PATCH. |
| OCI payload shape and TTL behavior preserved | PASS | ADD still sends `"ttl": 30`; REMOVE has no TTL; OCI `domain` remains full FQDN by design. |
| Wildcard behavior covered without wildcard branch | PASS | Apex and delegated wildcard cases pass; no runtime `*` branch was introduced. |
| JSON escaping is local and focused | PASS | `_oci_json_escape` is local to `dnsapi/dns_oci.sh`; TXT quote/backslash test passes. |
| Debug behavior is factual and non-secret | PASS | Debug assertions check candidate/status/fallback/selected-zone facts and absence of Authorization/private-key/RPST fixtures in normal debug. |
| Static validation passes | PASS | ShellCheck passed for `test/dns_oci_mock.sh` and `dnsapi/dns_oci.sh`. |

## Automated Checks

- PASS: `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_add_remove_symmetry,le_test_oci_apex_wildcard_add,le_test_oci_delegated_wildcard_add sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_txt_value_json_escape,le_test_oci_record_domain_json_escape sh test/dns_oci_mock.sh`
- PASS: `CASE=le_test_oci_lookup_ambiguous_404_falls_back,le_test_oci_lookup_visible_authz_fails_hard,le_test_oci_no_zone_failure,le_test_oci_patch_failure_hints sh test/dns_oci_mock.sh`
- PASS: `sh test/dns_oci_mock.sh`
- PASS: `shellcheck -e SC2181 -e SC2089 test/dns_oci_mock.sh dnsapi/dns_oci.sh`
- PASS: `shellcheck --version` reported `0.11.0`.
- SKIPPED: `shfmt` because no local `shfmt` binary is installed; `.github/workflows/shellcheck.yml` still pins shfmt `v3.1.2`, and formatter dependency cleanup remains outside Phase 2.

## Code Evidence

- `dnsapi/dns_oci.sh` lines 40-42 and 64-66 escape and use shared JSON-ready `domain`/`rdata` values for ADD and REMOVE.
- `dnsapi/dns_oci.sh` lines 210-220 parse zone lookup response bodies, select `_domain`, and compute `_oci_record_domain`.
- `dnsapi/dns_oci.sh` lines 228-232 hard-fail on clear authz/permission signal.
- `test/dns_oci_mock.sh` includes Phase 2 cases for delegated zone, parent fallback, ambiguous 404 fallback, visible authz hard-fail, no-zone, patch-failure hints, add/remove symmetry, apex wildcard, delegated wildcard, TXT escaping, and record-domain payload proof.

## Gaps

None.

## Human Verification

None required for Phase 2. Live OCI DNS smoke remains intentionally deferred UAT evidence and is not part of the automated Phase 2 gate.
