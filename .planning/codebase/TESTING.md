# Testing Patterns

**Analysis Date:** 2026-05-14

## Test Framework

**Runner:**
- GitHub Actions is the primary runner. Workflows live in `.github/workflows/*.yml`.
- `test/dns_oci_mock.sh` is a repo-local POSIX shell harness for mocked OCI DNS hook characterization. It uses `le_test_*` cases and `CASE` selection, but no package manager, Bats, Python, or Node runner.
- Integration and platform tests use the external `acmetest` repository cloned by workflows such as `.github/workflows/Ubuntu.yml`, `.github/workflows/Linux.yml`, `.github/workflows/DNS.yml`, `.github/workflows/PebbleStrict.yml`, and `.github/workflows/Windows.yml`.
- Static quality gates use ShellCheck and shfmt in `.github/workflows/shellcheck.yml`.

**Assertion Library:**
- Shell command exit status is the assertion mechanism.
- ShellCheck exits non-zero on lint failures in `.github/workflows/shellcheck.yml`.
- `git diff --exit-code` after `shfmt -l -w -i 2 .` is the formatting assertion in `.github/workflows/shellcheck.yml`.
- `./letest.sh`, `./rundocker.sh testplat`, and `./rundocker.sh testall` from external `acmetest` provide integration assertions.

**Run Commands:**
```bash
shellcheck -e SC2181 -e SC2089 **/*.sh              # Run shell lint gate used by .github/workflows/shellcheck.yml
shfmt -l -w -i 2 . && git diff --exit-code          # Run formatting gate used by .github/workflows/shellcheck.yml
CASE=le_test_oci_harness_bootstrap sh test/dns_oci_mock.sh
sh test/dns_oci_mock.sh                             # Run full mocked OCI DNS hook characterization harness
cd .. && git clone --depth=1 https://github.com/acmesh-official/acmetest.git && cp -r acme.sh acmetest/
cd ../acmetest && ./letest.sh                       # Run external integration harness for the copied repo
cd ../acmetest && ./rundocker.sh testplat ubuntu:latest
cd ../acmetest && ./rundocker.sh testall            # DNS API test pattern used by .github/workflows/DNS.yml when secrets are configured
```

## Test File Organization

**Location:**
- CI workflows are under `.github/workflows/`.
- Runtime shell code under `acme.sh`, `dnsapi/`, `deploy/`, and `notify/` mostly relies on external integration tests.
- Focused repo-local mock harnesses live under `test/`; currently `test/dns_oci_mock.sh` covers OCI DNS hook behavior without live OCI DNS or credentials.
- External integration tests are pulled from `https://github.com/acmesh-official/acmetest.git` during CI rather than committed in this repository.

**Naming:**
- Platform workflows are named by operating system: `.github/workflows/Ubuntu.yml`, `.github/workflows/MacOS.yml`, `.github/workflows/Windows.yml`, `.github/workflows/FreeBSD.yml`, `.github/workflows/OpenBSD.yml`.
- Feature workflows are named by validation area: `.github/workflows/shellcheck.yml`, `.github/workflows/DNS.yml`, `.github/workflows/PebbleStrict.yml`, `.github/workflows/dockerhub.yml`.
- PR guidance workflows are named for hook families: `.github/workflows/pr_dns.yml` and `.github/workflows/pr_notify.yml`.

**Structure:**
```text
.github/workflows/
|-- shellcheck.yml      # Static shell lint and shfmt formatting gate
|-- Ubuntu.yml          # acmetest matrix against Let's Encrypt, ZeroSSL, and StepCA
|-- Linux.yml           # acmetest Docker platform matrix across Linux distributions
|-- DNS.yml             # DNS API integration workflow using provider secrets
|-- PebbleStrict.yml    # Local Pebble ACME strict-mode integration tests
|-- Windows.yml         # Cygwin-based Windows integration test
|-- MacOS.yml           # macOS integration test
`-- *BSD/Solaris/Haiku  # VM-backed platform integration tests
```

## Test Structure

**Suite Organization:**
```yaml
jobs:
  Ubuntu:
    strategy:
      matrix:
        include:
          - TEST_ACME_Server: "LetsEncrypt.org_test"
            TEST_PREFERRED_CHAIN: (STAGING)
          - TEST_ACME_Server: "https://localhost:9000/acme/acme/directory"
            NO_REVOKE: 1
    env:
      TEST_LOCAL: 1
      TEST_ACME_Server: ${{ matrix.TEST_ACME_Server }}
    steps:
      - uses: actions/checkout@v6
      - name: Clone acmetest
        run: |
          cd .. \
          && git clone --depth=1 https://github.com/acmesh-official/acmetest.git \
          && cp -r acme.sh acmetest/
      - name: Run acmetest
        run: |
          cd ../acmetest \
          && sudo --preserve-env ./letest.sh
```

**Patterns:**
- Path filters keep workflows scoped. Root `*.sh` changes trigger platform workflows such as `.github/workflows/Ubuntu.yml`; `dnsapi/*.sh` changes trigger `.github/workflows/DNS.yml`; shell file changes trigger `.github/workflows/shellcheck.yml`.
- Every integration workflow checks out this repository, clones `acmetest` beside it, copies the repo into `acmetest/acme.sh`, then runs `letest.sh` or `rundocker.sh`.
- Matrix variables drive ACME server selection, CA expectations, ECC/RSA coverage, wget coverage, preferred-chain coverage, and IP certificate coverage.
- VM-backed OS tests use `vmactions/*-vm` actions and pass environment variables with an `envs:` list.
- Failure debug steps print the VM debug wiki link when a VM-backed job fails.
- DNS API tests are gated on GitHub secrets. `.github/workflows/DNS.yml` has a `CheckToken` job, a `Fail` job for non-official forks without tokens, and platform jobs when tokens are present.

## Mocking

**Framework:** Not used

**Patterns:**
```yaml
- name: Start StepCA
  if: ${{ matrix.TEST_ACME_Server=='https://localhost:9000/acme/acme/directory' }}
  run: |
    docker run --rm -d \
      -p 9000:9000 \
      -e "DOCKER_STEPCA_INIT_NAME=Smallstep" \
      --name stepca \
      smallstep/step-ca:0.23.1
```

```yaml
- name: Run Pebble
  run: |
    docker run --rm -itd --name=pebble \
    -e PEBBLE_VA_ALWAYS_VALID=1 \
    -p 14000:14000 -p 15000:15000 ghcr.io/letsencrypt/pebble:latest -config /test/config/pebble-config.json -strict
```

**What to Mock:**
- Prefer real integration targets or protocol-compatible local ACME servers over shell-level mocks.
- Use StepCA in `.github/workflows/Ubuntu.yml` for local ACME directory tests.
- Use Pebble in `.github/workflows/PebbleStrict.yml` for strict ACME behavior and IP certificate coverage.
- Use `anyvm-org/cf-tunnel@v0` to provide a reachable HTTP challenge domain in platform workflows.

**What NOT to Mock:**
- Do not mock `acme.sh` helper functions for hook tests unless a dedicated unit harness is introduced. Current validation expects sourced runtime behavior through `acmetest`.
- Do not replace DNS provider behavior with local string assertions for merge confidence; `.github/workflows/DNS.yml` expects real provider credentials through GitHub secrets.
- Do not bypass platform workflows for portability-sensitive changes. POSIX shell changes must be exercised through the OS matrix where possible.

## Fixtures and Factories

**Test Data:**
```yaml
env:
  TEST_LOCAL: 1
  TEST_ACME_Server: ${{ matrix.TEST_ACME_Server }}
  CA_ECDSA: ${{ matrix.CA_ECDSA }}
  CA: ${{ matrix.CA }}
  TEST_PREFERRED_CHAIN: ${{ matrix.TEST_PREFERRED_CHAIN }}
  TestingDomain: ${{ steps.tunnel.outputs.server }}
```

**Location:**
- Platform and CA fixture values live in workflow matrices in `.github/workflows/Ubuntu.yml`, `.github/workflows/MacOS.yml`, `.github/workflows/Windows.yml`, and BSD/Solaris/Haiku workflows.
- DNS provider credentials are GitHub Actions secrets referenced by name in `.github/workflows/DNS.yml`; never store secret values in the repository.
- DNS timing and shape controls use environment variables such as `TEST_DNS`, `TestingDomain`, `TEST_DNS_NO_WILDCARD`, `TEST_DNS_NO_SUBDOMAIN`, and `TEST_DNS_SLEEP`.
- External scenario definitions and assertions live in the `acmetest` repository cloned during CI.

## Coverage

**Requirements:** None enforced by a coverage tool

**View Coverage:**
```bash
# No coverage report command exists in this repository.
# Use GitHub Actions status for .github/workflows/*.yml and acmetest results.
```

## Test Types

**Unit Tests:**
- Not used for runtime shell code.
- `.codex/hooks/*.sh` and `.codex/hooks/*.js` include structured output contracts in comments, but no local test runner is committed for those hooks.

**Integration Tests:**
- Primary validation mode.
- `.github/workflows/Ubuntu.yml` tests Let's Encrypt staging, ZeroSSL, and local StepCA variants.
- `.github/workflows/Linux.yml` runs `./rundocker.sh testplat` across Linux distributions including Ubuntu, Debian, Fedora, Alpine, Arch, Gentoo, Oracle Linux, and others.
- `.github/workflows/DNS.yml` runs DNS API tests across Docker, macOS, Windows/Cygwin, and VM-backed Unix platforms when provider secrets exist.
- `.github/workflows/PebbleStrict.yml` runs strict Pebble and IP certificate scenarios.

**E2E Tests:**
- GitHub Actions plus `acmetest` are the E2E layer.
- E2E flows cover issuance, renewal, DNS validation, HTTP challenge handling, preferred chains, alternate ACME servers, and platform-specific command behavior.

## Common Patterns

**Async Testing:**
```sh
if [ -n "$AWS_DNS_SLOWRATE" ]; then
  _info "Slow rate activated: sleeping for $AWS_DNS_SLOWRATE seconds"
  _sleep "$AWS_DNS_SLOWRATE"
else
  _sleep 1
fi
```

- DNS providers should use `_sleep` rather than raw `sleep`.
- DNS CI supports `TEST_DNS_SLEEP` in `.github/workflows/DNS.yml` for provider propagation timing.

**Error Testing:**
```sh
if ! _get_root "$fulldomain"; then
  _err "invalid domain"
  return 1
fi
```

- Integration assertions are behavior-first: commands return non-zero on failure and the workflow job fails.
- Static error patterns are enforced with ShellCheck, with explicit exclusions for `SC2181` and `SC2089` in `.github/workflows/shellcheck.yml`.
- Format regressions are caught by running shfmt and requiring `git diff --exit-code` to be clean.

---

*Testing analysis: 2026-05-14*
