# How to use Oracle Cloud Infrastructure DNS

This page describes using `acme.sh` with Oracle Cloud Infrastructure (OCI) DNS
through `dns_oci.sh`.

The hook supports both existing OCI API-key authentication and OCI resource
principal authentication for OCI-hosted automation. API-key configuration is
always primary when complete. Resource principal authentication is a fallback
only when API-key authentication cannot be configured and the resource principal
environment is complete.

The v1 release proof for this hook is mocked/static. Live OCI validation is
deferred to the v2 checklist tracked separately by the maintainers.

## Delegated subzones

`dns_oci.sh` chooses the most-specific accessible OCI DNS zone for the ACME TXT
challenge name.

For `_acme-challenge.www.dev.<domain-name>`, the hook probes candidate zones
from most-specific to parent:

```text
dev.<domain-name>
<domain-name>
```

If the delegated subzone is accessible, records are patched in that zone. If
OCI returns an ambiguous `NotAuthorizedOrNotFound` response for the delegated
candidate and an accessible parent exists, the hook falls back to the parent
zone. Clear authorization failures such as 401, 403, or explicit permission
errors fail immediately instead of falling through to the parent.

The hook sends TXT record mutations for the full challenge FQDN selected by
`acme.sh`, including wildcard challenge names such as
`_acme-challenge.<domain-name>`.

## API-key setup

Use API-key authentication when you already run `acme.sh` with a user API
signing key or OCI CLI configuration. This remains the preferred path for
existing users.

You can use an OCI CLI config file with a `DEFAULT` profile:

```ini
[DEFAULT]
tenancy=<tenancy-ocid>
user=<user-ocid>
region=<region>
key_file=<path-to-api-signing-key>
fingerprint=<api-key-fingerprint>
```

Or set the hook-owned environment variables:

```sh
export OCI_CLI_TENANCY="<tenancy-ocid>"
export OCI_CLI_USER="<user-ocid>"
export OCI_CLI_REGION="<region>"
export OCI_CLI_KEY_FILE="<path-to-api-signing-key>"
```

`OCI_CLI_KEY` can be used instead of `OCI_CLI_KEY_FILE` when the private API
signing key is supplied inline. Prefer file-backed keys for normal operation.

Issue a certificate with the OCI DNS hook:

```sh
acme.sh --issue --dns dns_oci -d "<domain-name>" -d "*.<domain-name>"
```

## Resource principal setup

Use resource principal authentication for OCI-hosted automation where the
workload receives resource principal session token material from OCI and no
complete API-key configuration is available.

The hook supports the OCI resource principal v2.2 environment contract:

```sh
export OCI_RESOURCE_PRINCIPAL_VERSION="2.2"
export OCI_RESOURCE_PRINCIPAL_RPST="<path-to-rpst-token-or-inline-rpst>"
export OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM="<path-to-private-pem-or-inline-pem>"
export OCI_RESOURCE_PRINCIPAL_REGION="<region>"
```

If the private PEM is encrypted and requires a passphrase, set:

```sh
export OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE="<path-to-passphrase-or-inline-passphrase>"
```

`OCI_RESOURCE_PRINCIPAL_RPST`, `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`, and
`OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` use path-first inline fallback:
if the value names a readable file, the hook reads the current file contents
for the signed request; otherwise it treats the value as inline material. A
private-key placeholder in documentation should look like
`<RP_PRIVATE_PEM_CONTENTS>`, not a real key block.

Before using the hook, place the OCI-hosted workload in a dynamic group such as
`<dynamic-group-name>` and grant that dynamic group DNS permissions for the
compartment and zones it needs.

Then run the normal DNS challenge command:

```sh
acme.sh --issue --dns dns_oci -d "<domain-name>" -d "*.<domain-name>"
```

## Auth precedence

When both auth modes are complete, API-key auth wins. This preserves existing
OCI CLI and `OCI_CLI_*` users.

Resource principal auth is selected only after API-key auth is unavailable or
incomplete and these values are present:

- `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`
- `OCI_RESOURCE_PRINCIPAL_RPST`
- `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`
- `OCI_RESOURCE_PRINCIPAL_REGION`

`OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE` is optional.

## OCI policy examples

These examples are starting points. Adapt them to your tenancy, compartment,
zone model, public/private DNS scope, and operational separation.

For an API-key user group:

```text
Allow group <group-name> to read dns-zones in compartment <compartment-name>
Allow group <group-name> to use dns-records in compartment <compartment-name>
```

For an OCI-hosted resource principal dynamic group:

```text
Allow dynamic-group <dynamic-group-name> to read dns-zones in compartment <compartment-name>
Allow dynamic-group <dynamic-group-name> to use dns-records in compartment <compartment-name>
```

To narrow mutation access to TXT records for a specific DNS name, adapt a
condition like this:

```text
Allow group <group-name> to use dns-records in compartment <compartment-name> where all {target.dns-record.type='TXT', target.dns-domain.name='<domain-name>'}
```

For a resource principal dynamic group, use the same condition shape:

```text
Allow dynamic-group <dynamic-group-name> to use dns-records in compartment <compartment-name> where all {target.dns-record.type='TXT', target.dns-domain.name='<domain-name>'}
```

The hook needs zone lookup and TXT record mutation. Oracle policy references
map this to `read dns-zones` for zone reads and `use dns-records` for record
updates. Depending on how your zones are arranged, you may also choose to scope
by `target.dns-zone.name`.

## Secret handling

The hook does not persist resource-principal values to acme.sh account or
domain config.

The hook keeps these values out of normal debug, info, and error logs:

- RPST token material
- private PEM material
- private PEM passphrase material
- signing strings
- request signatures
- OCI authorization headers

Signing internals that are useful for debugging are restricted to secure debug
helpers. Passphrase values are not emitted there either.

## Troubleshooting

### Missing API-key auth

If API-key authentication is incomplete, the hook reports the missing
`OCI_CLI_*` fields or missing key material. Complete the OCI CLI profile or set
the required environment variables.

### API-key wins over resource principal

If a complete OCI CLI config or complete `OCI_CLI_*` environment is present,
the hook uses API-key auth even when resource-principal variables are also set.
Unset the API-key config for a resource-principal-only run.

### Unsupported resource principal version

Set `OCI_RESOURCE_PRINCIPAL_VERSION=2.2`. Other versions are outside the current
hook contract.

### Missing or unreadable resource principal files

Check these values:

- `OCI_RESOURCE_PRINCIPAL_RPST`
- `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM`
- `OCI_RESOURCE_PRINCIPAL_PRIVATE_PEM_PASSPHRASE`

If a value points to a file, the file must be readable by the `acme.sh` process
at request-signing time.

### Zone not found or permission denied

A zone-not-found message can mean the zone does not exist, the wrong
compartment is being used, or the principal lacks DNS zone read permission.
Confirm the compartment, zone name, and `read dns-zones` permission.

A clear authorization or permission failure means the principal reached OCI but
does not have enough access for the probed zone or record mutation. Review the
`read dns-zones` and `use dns-records` policies and any
`target.dns-record.type`, `target.dns-domain.name`, or
`target.dns-zone.name` conditions.

### Live validation scope

The v1 milestone was verified with mocked DNS behavior, provider metadata
checks, ShellCheck, and shfmt. Maintainers should use the separate v2 live
validation checklist before claiming live OCI disposable-zone or OCI-hosted
resource-principal proof.
