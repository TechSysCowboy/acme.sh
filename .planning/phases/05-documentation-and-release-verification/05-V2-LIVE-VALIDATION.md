# Phase 5 V2 Live Validation Checklist

**Status:** Deferred from v1. This checklist is future live proof, not a Phase 5
pass/fail gate.

## Scope

The v1 milestone is complete with mocked/static proof. LIVE-01 and LIVE-02
remain deferred until maintainers choose to run live OCI checks with disposable
DNS resources and an OCI-hosted workload.

## LIVE-01: Disposable-Zone API-Key Smoke Test

- [ ] Create or select a disposable public OCI DNS zone such as
  `<zone-name>` in `<compartment-name>`.
- [ ] Configure a test user or group with scoped API-key auth.
- [ ] Grant only the needed DNS permissions for the disposable zone:
  `read dns-zones` and `use dns-records`.
- [ ] Run an `acme.sh --issue --dns dns_oci` smoke test for
  `<domain-name>` against the disposable zone.
- [ ] Run a delegated subzone issuance smoke test, for example
  `dev.<domain-name>`.
- [ ] Run a wildcard issuance smoke test, for example `*.<domain-name>`.
- [ ] Confirm TXT records are created and removed in OCI.
- [ ] Capture cleanup proof showing temporary TXT records and any disposable
  test zone resources were removed.

## LIVE-02: OCI-Hosted Resource Principal Smoke Test

- [ ] Create or select an OCI-hosted workload that receives resource principal
  v2.2 material.
- [ ] Place that workload in `<dynamic-group-name>`.
- [ ] Grant the dynamic group `read dns-zones` and `use dns-records` only for
  the needed compartment, zone, and TXT record scope.
- [ ] Ensure no complete API-key config is present so resource principal auth is
  selected.
- [ ] Confirm the workload has:
  - `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`
  - `OCI_RESOURCE_PRINCIPAL_RPST`
  - `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`
  - `OCI_RESOURCE_PRINCIPAL_REGION`
- [ ] If testing encrypted private PEM material, provide
  `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE`.
- [ ] Run `acme.sh --issue --dns dns_oci` from the OCI-hosted workload.
- [ ] Confirm delegated and wildcard challenge names work from the OCI-hosted
  resource principal path.
- [ ] Confirm cleanup removes temporary TXT records.

## Secret And Persistence Checks

- [ ] Confirm RPST, private PEM, passphrase, signing strings, request
  signatures, and OCI authorization headers are absent from normal logs.
- [ ] Confirm RPST, private PEM, passphrase, and Authorization material are not
  persisted to acme.sh account config or domain config.
- [ ] Confirm secure debug, when intentionally enabled, contains only the
  expected signing diagnostics and still excludes passphrase values.
- [ ] Record the exact compartment, zone, and dynamic group policy shape used,
  with secrets redacted.

## Deferred Verdict

Live OCI validation is intentionally deferred from v1. Completing this checklist
can support a future v2 release note, but failure to run these items does not
change the Phase 5 v1 verdict.
