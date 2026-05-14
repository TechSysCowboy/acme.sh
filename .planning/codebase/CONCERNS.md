# Codebase Concerns

**Analysis Date:** 2026-05-14

## Tech Debt

**Monolithic core script:**
- Issue: `acme.sh` is an 8,658-line POSIX shell script that owns protocol constants, logging, HTTP transport, config storage, standalone servers, web server integrations, account/certificate issuance, deployment, cron, Windows scheduler handling, and CLI parsing.
- Files: `acme.sh:1`, `acme.sh:1936`, `acme.sh:2393`, `acme.sh:3626`, `acme.sh:6360`, `acme.sh:8040`
- Impact: Changes to one concern can affect unrelated flows through global variables and shared helper state, and static analysis findings in the entrypoint become expensive to reason about.
- Fix approach: Extract stable, sourced modules only along existing boundaries: HTTP transport, config storage, hook execution, validation orchestration, and install/cron. Keep public CLI behavior in `acme.sh` and add shell-based regression checks before each extraction.

**Hand-maintained provider surface:**
- Issue: The repo contains 178 DNS hooks, 53 deploy hooks, and 26 notify hooks, each hand-rolling request construction, response parsing, credential persistence, and debug behavior.
- Files: `dnsapi/`, `deploy/`, `notify/`, `dnsapi/README.md`, `deploy/README.md`
- Impact: Provider behavior drifts: some hooks use secure debug helpers, some log raw headers, some depend on non-portable tools, and some do no cleanup on remove.
- Fix approach: Add shared provider helper contracts for auth header logging, JSON/XML extraction, TXT add/remove by value, pagination, retry/rate-limit handling, and credential persistence. Require new hooks to include a small fixture-based parser test.

**Config files are shell code, not structured data:**
- Issue: `_save_conf` writes shell assignment lines and `_read_conf` evaluates matching lines from config files with `eval`.
- Files: `acme.sh:2440`, `acme.sh:2470`, `acme.sh:2475`, `acme.sh:2536`, `acme.sh:2538`
- Impact: Config parsing is tightly coupled to shell syntax and becomes code execution if a config file is modified by another user or process.
- Fix approach: Store config as escaped key/value data and parse without `eval`, or restrict `eval` to validated key names plus a safe decoder. Treat the existing shell-format reader as a compatibility shim.

**Direct, non-atomic file writes:**
- Issue: Certificate installation and config mutation overwrite target files directly with `cat >` or `sed >` instead of writing a temporary file and renaming it atomically.
- Files: `acme.sh:2420`, `acme.sh:2431`, `acme.sh:6364`, `acme.sh:6390`, `acme.sh:6405`, `deploy/localcopy.sh:75`, `deploy/localcopy.sh:84`, `deploy/localcopy.sh:98`
- Impact: Concurrent cron runs, deploy hooks, or service reloads can observe truncated config, cert, chain, or key files.
- Fix approach: Add a shared atomic write helper that creates a temp file in the destination directory, sets the final mode before content is exposed, fsyncs where available, and renames over the destination.

## Known Bugs

**ShellCheck gate omits the main entrypoint:**
- Symptoms: The CI command `shellcheck -e SC2181 -e SC2089 **/*.sh` expands to nested shell files under the default Bash shell and excludes root `acme.sh`; running the same exclusions directly on `acme.sh` reports ShellCheck errors such as SC2145 at debug logging calls and SC2078 in `_base64`.
- Files: `.github/workflows/shellcheck.yml:29`, `acme.sh:357`, `acme.sh:391`, `acme.sh:424`, `acme.sh:989`
- Trigger: Run `bash -lc 'set -- **/*.sh; case " $* " in *" acme.sh "*) echo yes;; *) echo no;; esac'` from the repo root, then run `shellcheck -e SC2181 -e SC2089 acme.sh`.
- Workaround: Run ShellCheck on `acme.sh` explicitly in local verification.

**Selfhost DNS cleanup is a no-op:**
- Symptoms: `dns_selfhost_rm` always logs that creating and removing records is unsupported and returns without deleting the TXT record.
- Files: `dnsapi/dns_selfhost.sh:95`, `dnsapi/dns_selfhost.sh:100`
- Trigger: Issue a DNS-01 certificate with `--dns dns_selfhost`; cleanup leaves provider-side TXT state intact.
- Workaround: Manually remove stale challenge records outside `acme.sh`.

**Azure DNS zone discovery lacks continuation handling:**
- Symptoms: `_get_root` documents that Azure DNS list responses can exceed one page and that continuation-token handling is not implemented.
- Files: `dnsapi/dns_azure.sh:391`, `dnsapi/dns_azure.sh:395`, `dnsapi/dns_azure.sh:399`
- Trigger: Use an Azure subscription with enough DNS zones for the API to paginate.
- Workaround: Keep the relevant zone in the returned page or split zones across subscriptions until pagination is implemented.

**Active24 TXT removal can miss records:**
- Symptoms: `dns_active24_rm` notes that filtering by TXT content is still TODO and requests only one page of up to 100 TXT records before extracting IDs.
- Files: `dnsapi/dns_active24.sh:47`, `dnsapi/dns_active24.sh:49`, `dnsapi/dns_active24.sh:50`, `dnsapi/dns_active24.sh:58`
- Trigger: Use Active24 zones with many TXT records or duplicate challenge values.
- Workaround: Verify TXT cleanup manually after issuance.

## Security Considerations

**Provider hooks log credentials through normal debug channels:**
- Risk: Sensitive values can be written to stderr, log files, or syslog when debug logging is enabled.
- Files: `acme.sh:382`, `acme.sh:395`, `dnsapi/dns_active24.sh:165`, `dnsapi/dns_active24.sh:166`, `dnsapi/dns_active24.sh:167`, `dnsapi/dns_active24.sh:180`, `dnsapi/dns_active24.sh:183`, `dnsapi/dns_selectel.sh:311`, `dnsapi/dns_selectel.sh:314`, `dnsapi/dns_yc.sh:255`, `dnsapi/dns_yc.sh:261`
- Current mitigation: Secure debug helpers exist in `acme.sh:361`, `acme.sh:395`, and `acme.sh:428`, but provider hooks apply them inconsistently.
- Recommendations: Add a lint check that rejects `_debug` and `_debug2` calls containing token, secret, key, password, authorization header, JWT, or signed payload data. Convert provider auth traces to `_secure_debug*`.

**Docker image exposes certificate state too broadly:**
- Risk: The image creates an `acme` user, chowns config state to it, then leaves the container running as root and grants world read/write/execute permissions to both the working and config directories.
- Files: `Dockerfile:35`, `Dockerfile:41`, `Dockerfile:91`, `Dockerfile:93`
- Current mitigation: The config directory is owned by `acme:acme`.
- Recommendations: Add `USER acme`, remove `chmod -R o+rwx`, and set directory modes to `700` or `750`. Keep private keys at `600` and avoid world-writable mounted state.

**Hook and notification execution uses `eval`:**
- Risk: User-configured commands and config-derived values execute through the shell interpreter.
- Files: `acme.sh:3641`, `acme.sh:3740`, `acme.sh:3788`, `acme.sh:3804`, `acme.sh:6425`, `notify/mail.sh:66`, `notify/xmpp.sh:46`, `deploy/multideploy.sh:184`
- Current mitigation: Hooks are user-configured behavior and usually execute under the invoking account.
- Recommendations: Keep intentional command hooks documented as arbitrary code execution, but remove `eval` from command assembly helpers where structured argv execution is possible. Validate config keys before exporting or clearing them.

**Temporary file fallback is predictable:**
- Risk: `_mktemp` falls back to `/tmp/${PROJECT_NAME}wefADf24sf.$(_time).tmp` when `mktemp` is unavailable, allowing name prediction and race conditions.
- Files: `acme.sh:1909`, `acme.sh:1918`, `acme.sh:1938`, `acme.sh:1961`
- Current mitigation: Real `mktemp` is used when present.
- Recommendations: Fail closed when `mktemp` is unavailable for sensitive HTTP headers/debug dumps, or create a private temp directory with `mkdir` and restrictive permissions before writing files.

**GitHub workflows omit explicit token permissions:**
- Risk: Workflows inherit repository default `GITHUB_TOKEN` permissions, including for workflows that execute external actions or create issues.
- Files: `.github/workflows/*.yml`, `.github/workflows/wiki-monitor.yml:54`, `.github/workflows/dockerhub.yml:46`
- Current mitigation: `dockerhub.yml` disables checkout credential persistence at `.github/workflows/dockerhub.yml:48`.
- Recommendations: Add top-level `permissions: contents: read` to read-only workflows, then grant `issues: write` only to `wiki-monitor.yml` and package/publish permissions only where required.

## Performance Bottlenecks

**KAS DNS hook performs network I/O while being sourced:**
- Problem: `dns_kas.sh` fetches two WSDL documents and logs API URLs at top level before public functions run.
- Files: `dnsapi/dns_kas.sh:15`, `dnsapi/dns_kas.sh:19`, `dnsapi/dns_kas.sh:23`
- Cause: Provider API discovery lives in global initialization instead of lazy initialization.
- Improvement path: Move WSDL discovery into a cached `_kas_init` function and honor the provider-reported rate-limit value instead of the hard-coded `KAS_default_ratelimit`.

**DNS workflow serializes platform jobs:**
- Problem: `DNS.yml` chains Docker, macOS, Windows, BSD, Solaris, OmniOS, OpenIndiana, and Haiku jobs with `needs`, so one slow or flaky platform blocks all later platforms.
- Files: `.github/workflows/DNS.yml:48`, `.github/workflows/DNS.yml:97`, `.github/workflows/DNS.yml:145`, `.github/workflows/DNS.yml:207`, `.github/workflows/DNS.yml:263`, `.github/workflows/DNS.yml:319`, `.github/workflows/DNS.yml:396`, `.github/workflows/DNS.yml:457`, `.github/workflows/DNS.yml:514`, `.github/workflows/DNS.yml:573`, `.github/workflows/DNS.yml:629`, `.github/workflows/DNS.yml:685`
- Cause: Jobs are modeled as a linear validation chain.
- Improvement path: Use a matrix or independent jobs after the token check, with shared setup through a reusable workflow and platform-specific `continue-on-error` policy where appropriate.

**External test repository is cloned repeatedly:**
- Problem: CI clones `https://github.com/acmesh-official/acmetest.git` in many jobs, with no pinned revision and no reuse between jobs.
- Files: `.github/workflows/Linux.yml:44`, `.github/workflows/DNS.yml:70`, `.github/workflows/PebbleStrict.yml:43`, `.github/workflows/Ubuntu.yml:96`
- Cause: Test harness lives outside this repository and is fetched ad hoc.
- Improvement path: Pin the test harness commit, cache it per workflow run, or vendor the minimal test runner contract used by this repo.

## Fragile Areas

**Portable-shell rules are documented but not consistently enforceable:**
- Files: `.github/copilot-instructions.md:45`, `.github/copilot-instructions.md:61`, `dnsapi/dns_world4you.sh:64`, `dnsapi/dns_freemyip.sh:75`, `dnsapi/dns_gcloud.sh:84`, `dnsapi/dns_gcloud.sh:102`, `dnsapi/dns_edgedns.sh:448`, `deploy/multideploy.sh:83`
- Why fragile: The project targets POSIX sh across Linux, macOS, BSD, Solaris, BusyBox, Windows/Cygwin, Haiku, and OmniOS, but existing hooks use commands the repo guidance forbids or treats as portability hazards.
- Safe modification: Before changing a provider hook, scan it for non-portable helpers and either replace them with project wrappers or guard them with `_exists` plus a clear error.
- Test coverage: No in-repo fixture tests prove these paths on minimal shells.

**Command-string deploy hooks are difficult to quote safely:**
- Files: `deploy/haproxy.sh:331`, `deploy/haproxy.sh:359`, `deploy/haproxy.sh:361`, `deploy/lighttpd.sh:244`, `deploy/openmediavault.sh:48`, `deploy/openmediavault.sh:128`, `deploy/localcopy.sh:146`
- Why fragile: Hooks build command strings that interpolate paths, PEM contents, domains, and reload commands, then execute them with `eval`.
- Safe modification: Prefer functions that pass arguments directly; where string commands are required by external tools, isolate quoting in one helper and add tests with paths containing spaces, quotes, and shell metacharacters.
- Test coverage: No local tests exercise command construction with adversarial path/domain values.

**Certificate install and deploy paths are not concurrency-safe:**
- Files: `acme.sh:6364`, `acme.sh:6390`, `acme.sh:6405`, `acme.sh:6415`, `deploy/localcopy.sh:75`, `deploy/localcopy.sh:98`
- Why fragile: Files are overwritten in place and reload commands can run immediately after writes.
- Safe modification: Write into temp files in the target directory, set modes, rename atomically, then run reload commands only after all target writes succeed.
- Test coverage: No tests simulate concurrent readers or failed partial writes.

**Multi-deploy mutates shared domain config per service:**
- Files: `deploy/multideploy.sh:177`, `deploy/multideploy.sh:184`, `deploy/multideploy.sh:205`, `deploy/multideploy.sh:213`, `deploy/multideploy.sh:237`
- Why fragile: One service's environment variables are saved into domain config, then cleared after each service; interruption can leave stale or missing deploy state.
- Safe modification: Treat multi-deploy environment as process-local state and pass it into service hooks without persisting to domain config unless the user explicitly requests persistence.
- Test coverage: No tests cover failed middle service, interrupted deploy, or repeated deploy with different YAML environments.

## Scaling Limits

**DNS provider testing supports only five dynamic secret pairs:**
- Current capacity: `DNS.yml` exposes `TokenName1` through `TokenName5` and matching `TokenValue1` through `TokenValue5`.
- Files: `.github/workflows/DNS.yml:63`, `.github/workflows/DNS.yml:75`, `.github/workflows/DNS.yml:124`, `.github/workflows/DNS.yml:187`, `.github/workflows/DNS.yml:233`
- Limit: Providers needing more credentials or multiple accounts require workflow edits.
- Scaling path: Store provider test configurations as named GitHub environments or a structured encrypted artifact consumed by a reusable setup script.

**Azure DNS hook assumes a bounded zone list:**
- Current capacity: One API response is parsed for zone discovery.
- Files: `dnsapi/dns_azure.sh:391`, `dnsapi/dns_azure.sh:399`, `dnsapi/dns_azure.sh:410`
- Limit: Large Azure subscriptions can hide the matching zone behind pagination.
- Scaling path: Follow Azure continuation links until the matching zone is found or all pages are exhausted.

**Provider count scales review cost linearly:**
- Current capacity: 257 hook files under `dnsapi/`, `deploy/`, and `notify/`.
- Files: `dnsapi/`, `deploy/`, `notify/`
- Limit: Each provider carries bespoke parsing, auth, logging, and cleanup logic.
- Scaling path: Add generated metadata indexes and shared conformance tests for `*_add`, `*_rm`, credential persistence, secure logging, and idempotent cleanup.

## Dependencies at Risk

**Static formatting dependency is stale:**
- Risk: CI downloads `shfmt` v3.1.2 while the latest upstream `mvdan/sh` tag checked during this map is v3.13.1.
- Impact: Formatting and parser behavior can diverge from developer machines and modern shell syntax checks.
- Migration plan: Update `.github/workflows/shellcheck.yml:36` to the latest release or install through a pinned checksum-based action, and add dependency automation for workflow tools.

**Docker build actions lag latest majors:**
- Risk: `docker/setup-qemu-action@v2` and `docker/setup-buildx-action@v2` are used while upstream latest tags checked during this map are v4.0.0.
- Impact: DockerHub publishing can miss security fixes and platform builder fixes.
- Migration plan: Update `.github/workflows/dockerhub.yml:50` and `.github/workflows/dockerhub.yml:57`, then verify multi-platform image output.

**GitHub Script actions lag latest majors:**
- Risk: `actions/github-script@v6` is used while upstream latest tags checked during this map are v9.0.0.
- Impact: Issue/PR automation may depend on older Node runtimes and older GitHub client behavior.
- Migration plan: Update `.github/workflows/issue.yml:10`, `.github/workflows/pr_dns.yml:16`, and `.github/workflows/pr_notify.yml:18` with a small dry-run on representative events.

**External test inputs are unpinned:**
- Risk: CI pulls `acmetest` default branch, Pebble `master` compose file, and `ghcr.io/letsencrypt/pebble:latest`.
- Impact: CI can fail or pass because an external dependency changed, not because this repo changed.
- Migration plan: Pin `.github/workflows/Linux.yml:47`, `.github/workflows/PebbleStrict.yml:40`, `.github/workflows/PebbleStrict.yml:68`, and `.github/workflows/DNS.yml:71` to known-good revisions and update them through an explicit dependency refresh process.

**Dependency update automation is not configured:**
- Risk: No Dependabot or Renovate config is present under `.github/`.
- Impact: Workflow actions, Docker base images, shfmt downloads, and external test refs require manual discovery.
- Migration plan: Add `.github/dependabot.yml` or `renovate.json` for GitHub Actions, Docker, and direct GitHub release references.

## Missing Critical Features

**In-repo test harness:**
- Problem: No `tests/`, `*.test.*`, or `*.spec.*` files are present; runtime validation depends on external `acmetest`.
- Blocks: Provider parser tests, config migration tests, redaction tests, and hook quoting tests cannot run locally without network and external repo state.
- Files: `.github/workflows/Linux.yml:44`, `.github/workflows/DNS.yml:70`, `.github/workflows/PebbleStrict.yml:43`

**Secret-redaction regression gate:**
- Problem: Existing secure debug helpers are not enforced by tests or lint rules.
- Blocks: Safe review of new DNS, deploy, and notify hooks that manipulate Authorization headers, JWTs, and provider tokens.
- Files: `acme.sh:361`, `acme.sh:395`, `dnsapi/dns_active24.sh:165`, `dnsapi/dns_selectel.sh:314`, `dnsapi/dns_yc.sh:261`

**Atomic write and locking primitive:**
- Problem: Config, cert, key, chain, and deploy writes lack a shared lock/atomic write contract.
- Blocks: Reliable concurrent renewal, cron overlap protection, and safe deploy reloads.
- Files: `acme.sh:2394`, `acme.sh:6364`, `deploy/localcopy.sh:75`

## Test Coverage Gaps

**Core script static analysis:**
- What's not tested: `acme.sh` itself is not included by the current ShellCheck glob and has ShellCheck errors when scanned directly.
- Files: `.github/workflows/shellcheck.yml:29`, `acme.sh:357`, `acme.sh:391`, `acme.sh:424`, `acme.sh:989`
- Risk: Main CLI behavior can accumulate shell portability and quoting bugs while CI stays green.
- Priority: High

**Provider parser and cleanup behavior:**
- What's not tested: DNS hooks parse API responses with grep/sed/cut and implement cleanup differently per provider.
- Files: `dnsapi/dns_active24.sh:58`, `dnsapi/dns_azure.sh:410`, `dnsapi/dns_selfhost.sh:100`, `dnsapi/dns_selectel.sh:184`
- Risk: TXT records can be missed, deleted incorrectly, or left behind without detection.
- Priority: High

**Credential redaction behavior:**
- What's not tested: Debug output does not have fixture tests proving provider tokens, auth headers, JWTs, and API secrets are hidden unless `--output-insecure` is set.
- Files: `acme.sh:361`, `acme.sh:395`, `dnsapi/dns_active24.sh:166`, `dnsapi/dns_selectel.sh:314`, `dnsapi/dns_yc.sh:261`
- Risk: Debug logs gathered for support can leak provider credentials.
- Priority: High

**Config and deploy failure modes:**
- What's not tested: Direct overwrite, interrupted writes, invalid shell metacharacters in paths/domains, and concurrent cron/deploy execution.
- Files: `acme.sh:2421`, `acme.sh:2475`, `acme.sh:6425`, `deploy/localcopy.sh:146`, `deploy/multideploy.sh:184`
- Risk: Config corruption, command injection through trusted config, partial certificate install, and failed reloads can escape review.
- Priority: Medium

**Workflow behavior:**
- What's not tested: Workflow path filters, secret setup, unpinned external test repo revisions, and job fan-out behavior.
- Files: `.github/workflows/shellcheck.yml:29`, `.github/workflows/DNS.yml:28`, `.github/workflows/DNS.yml:70`, `.github/workflows/PebbleStrict.yml:40`
- Risk: CI can skip important files or fail for external reasons unrelated to the patch.
- Priority: Medium

---

*Concerns audit: 2026-05-14*
