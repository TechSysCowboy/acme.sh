# Phase 02 Pattern Map

**Generated:** 2026-05-15
**Status:** Ready for planning

## Target Files

| File | Role | Closest Analog | Notes |
|------|------|----------------|-------|
| `dnsapi/dns_oci.sh` | OCI DNS provider implementation | Existing `dnsapi/dns_oci.sh` helpers | Keep upstream-friendly POSIX shell style; add shared selected-zone/owner computation without changing auth selection. |
| `test/dns_oci_mock.sh` | Mocked proof harness | Phase 1 `test/dns_oci_mock.sh` cases | Extend the existing acmetest-shaped harness with status/body/id lookup signal, wildcard cases, debug assertions, and escaping cases. |

## Patterns To Reuse

### Public Hook First

Drive behavior through `dns_oci_add` and `dns_oci_rm`, then assert captured
`_signed_request` calls. Use helper-level assertions only when the public
request capture cannot prove a selected-zone/owner invariant.

### Shared Private Computation

Add a private helper or equivalent shared block so add/remove use the same
selected zone, zone id, and record owner calculation. Keep ADD and REMOVE JSON
payload strings separate.

### Provider Boundary Mock

Keep `_signed_request` as the main mock boundary. Extend its fixture data just
enough to represent:

- requested method/path/body/return field;
- candidate zone status;
- candidate response body;
- extracted id value.

### Factual Debug

Use debug output for stable facts controlled by the hook or harness: candidate
zone, status/code if available, selected zone, and next candidate. Avoid
asserting exact OCI-owned prose.

## Data Flow

```text
dns_oci_add / dns_oci_rm
  -> _get_oci_zone
  -> _oci_config
  -> shared selected-zone/owner computation
  -> _signed_request GET /20180115/zones/$candidate
  -> selected zone + record owner
  -> _signed_request PATCH /20180115/zones/$selected/records
  -> captured request assertions
```

## Landmines

- Do not change auth-mode selection in Phase 2.
- Do not change the OCI PATCH `domain` field shape unless a test proves current
  behavior is wrong.
- Do not introduce Bash-only syntax, Bats, Python, Node, SDKs, or package
  managers.
- Do not persist or log OCI secrets in normal output/debug.
- Do not build a full OCI simulator inside the mock harness.
- Do not rely on exact OCI error-message phrasing in assertions.

---

*Phase: 02-delegated-zone-discovery-and-txt-payloads*
