<!-- refreshed: 2026-05-14 -->
# Architecture

**Analysis Date:** 2026-05-14

## System Overview

```text
+-------------------------------------------------------------+
|                      acme.sh CLI                             |
|                    `acme.sh`                                 |
+------------------+------------------+-----------------------+
| Command parser   | ACME workflows   | Install/cron/upgrade  |
| `acme.sh:7831`   | `acme.sh:4604`   | `acme.sh:7083`        |
+--------+---------+--------+---------+----------+------------+
         |                  |                    |
         v                  v                    v
+-------------------------------------------------------------+
|                  Core shell service layer                    |
| HTTP/JWS, crypto, config, validation, account, renewal       |
| `acme.sh:906`, `acme.sh:1928`, `acme.sh:2393`, `acme.sh:5776`|
+-------------+----------------------+------------------------+
              |                      |
              v                      v
+-----------------------------+  +----------------------------+
| Runtime-loaded hook modules |  | Local state and outputs    |
| `dnsapi/*.sh`               |  | `$LE_CONFIG_HOME`          |
| `deploy/*.sh`               |  | `account.conf`, `ca/`,     |
| `notify/*.sh`               |  | domain cert directories    |
+-----------------------------+  | `acme.sh:2807`,            |
                                 | `acme.sh:2950`             |
                                 +----------------------------+
              |
              v
+-------------------------------------------------------------+
| External ACME CAs, DNS providers, deployment targets, notify |
| APIs, local web servers, cron/scheduler, Docker runtime      |
| `Dockerfile`, `.github/workflows/*.yml`                      |
+-------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| CLI entry and command router | Parse flags, normalize command aliases, initialize shared runtime state, dispatch to command functions. | `acme.sh:7831`, `acme.sh:8470`, `acme.sh:8653` |
| ACME account and API client | Register/update/deactivate accounts, discover ACME directory endpoints, sign JWS requests, retry nonce and overload responses. | `acme.sh:2238`, `acme.sh:2878`, `acme.sh:3818`, `acme.sh:3850` |
| Certificate issuance workflow | Build orders, select challenge type, provision validations, finalize orders, download and split cert chains, calculate renewal times. | `acme.sh:4604`, `acme.sh:4869`, `acme.sh:5445`, `acme.sh:5712` |
| Renewal workflow | Load domain configuration, honor renewal schedule and ARI windows, call `issue`, deploy renewed certs, send notifications. | `acme.sh:5776`, `acme.sh:5925`, `acme.sh:6906` |
| Local config persistence | Store account, CA, domain, and deploy settings in shell-readable config files under `$LE_CONFIG_HOME`. | `acme.sh:2393`, `acme.sh:2442`, `acme.sh:2489`, `acme.sh:2553` |
| DNS provider hooks | Add and remove DNS-01 TXT records through provider-specific APIs using `dns_<name>_add` and `dns_<name>_rm`. | `dnsapi/dns_cf.sh:20`, `dnsapi/dns_cf.sh:111`, `dnsapi/dns_oci.sh:34`, `dnsapi/dns_oci.sh:56` |
| Deploy hooks | Push issued cert artifacts to servers and services using `<hook>_deploy`. | `acme.sh:6242`, `deploy/ssh.sh:32`, `deploy/docker.sh:15`, `deploy/multideploy.sh:37` |
| Notify hooks | Send renewal status through `<hook>_send`; notify hook configuration is account-scoped. | `acme.sh:7294`, `notify/mail.sh:11`, `notify/slack.sh:9`, `notify/smtp.sh:24` |
| Packaging/runtime image | Build the Alpine-based container, install runtime tools, generate command wrappers, and run supercronic daemon mode. | `Dockerfile:1`, `Dockerfile:37`, `Dockerfile:43`, `Dockerfile:78` |
| CI and contribution automation | Run OS matrix tests, shellcheck/shfmt, DNS hook tests, Docker publishing, PR guidance, and wiki edit notifications. | `.github/workflows/Linux.yml`, `.github/workflows/shellcheck.yml`, `.github/workflows/DNS.yml`, `.github/workflows/dockerhub.yml` |
| GSD workflow tooling | Provide local planning, review, execution, and codebase-mapping agent commands; keep generated planning docs under `.planning/`. | `.codex/config.toml:27`, `.codex/skills/gsd-map-codebase/SKILL.md`, `.codex/get-shit-done/VERSION` |

## Pattern Overview

**Overall:** Monolithic POSIX shell CLI with runtime-loaded hook modules.

**Key Characteristics:**
- `acme.sh` is the executable application and contains 212 shell functions, global constants, command parsing, persistence, ACME protocol logic, and command dispatch.
- Hook directories are plugin registries: `dnsapi/*.sh` exports `dns_<name>_add` and `dns_<name>_rm`, `deploy/*.sh` exports `<name>_deploy`, and `notify/*.sh` exports `<name>_send`.
- Runtime state is global shell variables plus persisted shell assignment files such as `$LE_CONFIG_HOME/account.conf`, `$LE_CONFIG_HOME/ca/.../ca.conf`, and `$CERT_HOME/<domain>/<domain>.conf`.
- External API calls use shell helpers, not SDKs: `_get`, `_post`, `_send_signed_request`, OpenSSL commands, `curl`, `wget`, `socat`, Python fallbacks, and provider-specific REST helpers.
- Installation copies `acme.sh`, `dnsapi/`, `deploy/`, and `notify/` into `$LE_WORKING_DIR`; hook discovery searches both the script home and working directory.

## Layers

**CLI and Dispatch Layer:**
- Purpose: Convert command-line flags to command variables and call exactly one command implementation.
- Location: `acme.sh:7831`
- Contains: `_process`, `showhelp`, `main`, command alias parsing, option parsing, final dispatch case statement.
- Depends on: Shared constants in `acme.sh:3`, `_selectServer` in `acme.sh:7731`, `_processAccountConf` in `acme.sh:7664`, `_initpath` in `acme.sh:2950`.
- Used by: Direct CLI invocation via `main "$@"` in `acme.sh:8658`, Docker wrappers generated in `Dockerfile:43`.

**ACME Protocol Layer:**
- Purpose: Speak ACME v2 using JWS-signed requests, account keys, orders, authorizations, challenges, finalize, certificate download, revoke, and ARI renewal information.
- Location: `acme.sh`
- Contains: `_initAPI` (`acme.sh:2878`), `_send_signed_request` (`acme.sh:2238`), `_regAccount` (`acme.sh:3850`), `issue` (`acme.sh:4604`), `renew` (`acme.sh:5776`), revoke/deactivate helpers (`acme.sh:6602`, `acme.sh:6721`).
- Depends on: HTTP helpers in `acme.sh:1928`, crypto helpers in `acme.sh:1009`, config helpers in `acme.sh:2393`, OpenSSL via `${ACME_OPENSSL_BIN:-openssl}`.
- Used by: CLI commands `--issue`, `--renew`, `--renew-all`, `--register-account`, `--revoke`, `--deactivate`, `--make-dns-persist-value`.

**HTTP and Crypto Utilities:**
- Purpose: Provide portable network, encoding, signing, certificate, CSR, key, and date helpers.
- Location: `acme.sh:906`, `acme.sh:1928`
- Contains: `_json_encode`, `_json_decode`, `_base64`, `_dbase64`, `_digest`, `_hmac`, `_sign`, `_createkey`, `_createcsr`, `_post`, `_get`, `_head_n`, `_tail_n`.
- Depends on: `curl` or `wget`, OpenSSL, POSIX shell commands, Python for date parsing fallback at `acme.sh:1875`.
- Used by: Core ACME workflow and provider hooks that call shared `_get`, `_post`, `_saveaccountconf_mutable`, `_readaccountconf_mutable`.

**Local State Layer:**
- Purpose: Resolve working directories and persist account, CA, domain, deployment, and notification settings.
- Location: `acme.sh:2807`, `acme.sh:2950`, `acme.sh:2393`
- Contains: `__initHome`, `_initpath`, `_save_conf`, `_read_conf`, `_savedomainconf`, `_saveaccountconf`, `_savecaconf`, `_savedeployconf`.
- Depends on: `$LE_WORKING_DIR`, `$LE_CONFIG_HOME`, `$CERT_HOME`, `$ACCOUNT_CONF_PATH`, `$CA_HOME`, and domain/keylength selection.
- Used by: Every command that needs cert paths, account paths, hook credentials, renewal schedules, or installation state.

**Challenge Validation Layer:**
- Purpose: Provision and clean up HTTP-01, DNS-01, TLS-ALPN-01, and DNS persist validations.
- Location: `acme.sh:2603`, `acme.sh:3128`, `acme.sh:3523`, `acme.sh:5067`
- Contains: `_startserver`, `_starttlsserver`, `_setApache`, `_setNginx`, `_clearupdns`, `_check_dns_entries`, DNS hook loading in `issue`.
- Depends on: Webroot paths, `socat` or Python fallback, OpenSSL `s_server`, Apache/nginx commands, DNS hook files, DNS-over-HTTPS helpers.
- Used by: `issue`, `signcsr`, and `renew`.

**Hook Plugin Layer:**
- Purpose: Extend core workflows without changing command routing for every provider or service.
- Location: `dnsapi/`, `deploy/`, `notify/`
- Contains: DNS providers (`dnsapi/dns_cf.sh`, `dnsapi/dns_oci.sh`), deployment targets (`deploy/ssh.sh`, `deploy/docker.sh`), notification targets (`notify/slack.sh`, `notify/mail.sh`).
- Depends on: Shared helpers sourced from `acme.sh`, provider environment variables, saved account/domain config, provider APIs and command-line tools.
- Used by: `_findHook` (`acme.sh:4188`), DNS provisioning in `issue` (`acme.sh:5139`), deploy dispatch (`acme.sh:6242`), notify dispatch (`acme.sh:7294`).

**Packaging and Automation Layer:**
- Purpose: Package the CLI for container use and verify portability across shells, OSes, providers, and formatting tools.
- Location: `Dockerfile`, `.github/workflows/`
- Contains: Alpine runtime image, command wrappers, supercronic entrypoint, OS matrix workflows, DNS hook workflow, shellcheck/shfmt workflow.
- Depends on: Alpine packages in `Dockerfile:3`, GitHub Actions, `acmetest`, `shellcheck`, `shfmt`, Docker Buildx.
- Used by: Maintainers and users consuming Docker images or relying on CI status.

**Planning Tooling Layer:**
- Purpose: Provide local GSD commands, agent definitions, templates, and workflow references for planning and execution.
- Location: `.codex/`, `.planning/`
- Contains: GSD skill adapters in `.codex/skills/`, agent configs in `.codex/agents/`, workflow references in `.codex/get-shit-done/workflows/`, codebase maps in `.planning/codebase/`.
- Depends on: `.codex/config.toml`, `.codex/get-shit-done/VERSION`, `.codex/gsd-file-manifest.json`.
- Used by: Codex/GSD workflows; not loaded by `acme.sh` runtime.

## Data Flow

### Primary Issue/Renew Request Path

1. User invokes `./acme.sh --issue ...` or `./acme.sh --renew ...`; `main` routes flag-led calls to `_process` (`acme.sh:8653`).
2. `_process` parses command and options into shell variables such as `_domain`, `_webroot`, `_server`, `_deploy_hook`, `_notify_hook`, then dispatches to `issue` or `renew` (`acme.sh:7831`, `acme.sh:8527`).
3. `_initpath` resolves `$LE_WORKING_DIR`, `$LE_CONFIG_HOME`, account config, CA config, domain directories, and certificate file paths (`acme.sh:2807`, `acme.sh:2950`).
4. `_initAPI` downloads the ACME directory and exports endpoint URLs including `ACME_NEW_ORDER`, `ACME_NEW_ACCOUNT`, and `ACME_RENEWAL_INFO` (`acme.sh:2878`).
5. `_regAccount` creates an account key if needed, handles EAB credentials for ZeroSSL, and persists account URL/hash in CA config (`acme.sh:3850`).
6. `issue` creates or reuses a domain key and CSR, creates an ACME order, fetches authorization objects, and builds a per-domain validation list (`acme.sh:4747`, `acme.sh:4813`, `acme.sh:4940`).
7. Validation is provisioned through webroot/standalone/nginx/apache/TLS-ALPN/DNS paths; DNS providers are found with `_findHook` and sourced before calling `<hook>_add` (`acme.sh:5139`, `acme.sh:5159`).
8. `issue` triggers each challenge, polls authorization status, finalizes the order, downloads the cert, splits the chain, stores paths, and calculates the next renewal time (`acme.sh:5326`, `acme.sh:5449`, `acme.sh:5545`, `acme.sh:5733`).
9. If install paths or deploy hooks are configured, `_installcert` and `_deploy` copy or deploy cert artifacts, then renew notifications are sent through `_send_notify` (`acme.sh:5742`, `acme.sh:5903`, `acme.sh:7294`).

### DNS-01 Hook Flow

1. User passes `--dns dns_cf`, `--dns dns_oci`, or another hook name; `_process` stores the hook in `_webroot` (`acme.sh:8134`).
2. `issue` maps DNS challenge authorization to `_acme-challenge` TXT records and computes the TXT value from the key authorization (`acme.sh:5113`, `acme.sh:5136`).
3. `_findHook` searches script-home and working-directory hook locations for `dnsapi/<hook>.sh` (`acme.sh:4188`, `acme.sh:5139`).
4. The hook file is sourced in a subshell and `<hook>_add` is called with TXT domain and value (`acme.sh:5159`, `dnsapi/dns_cf.sh:20`, `dnsapi/dns_oci.sh:34`).
5. `_check_dns_entries` polls DNS-over-HTTPS until TXT records are visible or times out; manual mode stores `Le_Vlist` and exits with `CODE_DNS_MANUAL` (`acme.sh:5190`, `acme.sh:5203`, `acme.sh:4428`).
6. `_clearupdns` sources each hook again and calls `<hook>_rm` after validation (`acme.sh:3537`, `dnsapi/dns_cf.sh:111`, `dnsapi/dns_oci.sh:56`).

### Deploy Hook Flow

1. User passes `--deploy --deploy-hook <hook>` or a domain persists `Le_DeployHook`; `_process` stores hook names in `_deploy_hook` (`acme.sh:8306`).
2. `deploy` loads the domain config and persists `Le_DeployHook` (`acme.sh:6280`).
3. `_deploy` resolves each hook with `_findHook`, sources `deploy/<hook>.sh`, verifies `<hook>_deploy`, and passes cert/key/CA/fullchain/PFX paths (`acme.sh:6242`, `acme.sh:6260`).
4. Hook modules read or save hook-specific settings through `_getdeployconf` and `_savedeployconf`; for example `deploy/ssh.sh` uses `DEPLOY_SSH_*` values (`deploy/ssh.sh:47`) and `deploy/docker.sh` uses `DEPLOY_DOCKER_*` values (`deploy/docker.sh:23`).

### Notify Hook Flow

1. User configures notification hooks with `--set-notify`; `setnotify` persists `NOTIFY_HOOK`, `NOTIFY_LEVEL`, `NOTIFY_MODE`, and `NOTIFY_SOURCE` in account config (`acme.sh:7367`).
2. `renew` and `renewAll` decide whether to notify based on return code and configured level/mode (`acme.sh:5911`, `acme.sh:6015`).
3. `_send_notify` resolves each hook with `_findHook`, sources `notify/<hook>.sh`, verifies `<hook>_send`, and passes subject/content/status code (`acme.sh:7294`, `notify/slack.sh:9`, `notify/mail.sh:11`).

**State Management:**
- Runtime state is shell variables in the current process and sourced hook subshells.
- Persistent account state lives in `$LE_CONFIG_HOME/account.conf` resolved by `__initHome` and `_initpath` (`acme.sh:2845`, `acme.sh:2956`).
- Persistent CA state lives in `$LE_CONFIG_HOME/ca/<host>/<path>/ca.conf`, `account.key`, and `account.json` (`acme.sh:2993`, `acme.sh:3005`).
- Persistent domain state and cert artifacts live in `$CERT_HOME/<domain>/` or `$CERT_HOME/<domain>_ecc/` (`acme.sh:3061`, `acme.sh:3083`).
- Deploy hook settings are stored in the domain config as `SAVED_<name>` entries through `_savedeployconf` (`acme.sh:2529`).

## Key Abstractions

**Command Functions:**
- Purpose: One shell function per CLI command; `_process` selects one command and passes parsed positional arguments.
- Examples: `issue` (`acme.sh:4604`), `renew` (`acme.sh:5776`), `deploy` (`acme.sh:6280`), `install` (`acme.sh:7083`), `setnotify` (`acme.sh:7367`).
- Pattern: `--long-option` aliases in `_process` set `_CMD`, then final dispatch calls the matching function.

**Hook Contracts:**
- Purpose: Keep provider integrations discoverable and dynamically loadable.
- Examples: `dnsapi/dns_cf.sh` defines `dns_cf_add` and `dns_cf_rm`; `deploy/ssh.sh` defines `ssh_deploy`; `notify/slack.sh` defines `slack_send`.
- Pattern: File basename must match command prefix. DNS hooks use `dns_<name>_add/rm`, deploy hooks use `<name>_deploy`, notify hooks use `<name>_send`.

**Config Helpers:**
- Purpose: Store shell variable assignments without a database or structured parser.
- Examples: `_save_conf`, `_read_conf`, `_savedomainconf`, `_saveaccountconf_mutable`, `_savedeployconf` in `acme.sh:2393`.
- Pattern: Write `KEY='value'` lines using `_setopt`; read by grep/eval and base64 wrappers for selected command strings.

**ACME Directory and CA Abstractions:**
- Purpose: Normalize named CA shortcuts and directory URLs into `ACME_DIRECTORY` and endpoint variables.
- Examples: CA constants in `acme.sh:23`, `_selectServer` in `acme.sh:7731`, `_getCAShortName` in `acme.sh:7759`, `_initAPI` in `acme.sh:2878`.
- Pattern: Command parser resolves `--server` aliases before command dispatch; `_initAPI` exports endpoint URLs from directory JSON.

**Certificate Artifact Set:**
- Purpose: Standardize per-domain output paths for key, CSR, cert, CA cert, full chain, PFX, PKCS8, and validation artifacts.
- Examples: `CERT_KEY_PATH`, `CSR_PATH`, `CERT_PATH`, `CA_CERT_PATH`, `CERT_FULLCHAIN_PATH`, `CERT_PFX_PATH`, `TLS_CERT` in `acme.sh:3091`.
- Pattern: `_initpath <domain> <keylength>` derives paths from `$CERT_HOME`, domain name, and ECC suffix.

**GSD Skills and Agents:**
- Purpose: Local workflow automation for planning, mapping, reviewing, executing, and shipping work.
- Examples: `.codex/skills/gsd-map-codebase/SKILL.md`, `.codex/agents/gsd-codebase-mapper.toml`, `.codex/get-shit-done/workflows/map-codebase.md`.
- Pattern: `.codex/config.toml` registers agents, while `.codex/skills/*/SKILL.md` maps GSD commands to workflow files.

## Entry Points

**CLI executable:**
- Location: `acme.sh`
- Triggers: User shell, cron job, Docker wrapper, CI test harness.
- Responsibilities: Parse commands, run ACME flows, manage local state, load hooks, install/upgrade/uninstall.

**Main dispatcher:**
- Location: `acme.sh:8653`
- Triggers: Bottom-of-file `main "$@"`.
- Responsibilities: Show help for empty invocations, route flag-led invocations to `_process`, and allow direct function execution for non-flag first arguments.

**Command parser:**
- Location: `acme.sh:7831`
- Triggers: `main` for normal CLI usage.
- Responsibilities: Normalize flags, persist account-level options, guard interactive sudo usage, call command functions.

**Install command:**
- Location: `acme.sh:7083`
- Triggers: `./acme.sh --install`, online installer, Docker build.
- Responsibilities: Copy executable and hook directories into `$LE_WORKING_DIR`, create config, install aliases and cron.

**Cron command:**
- Location: `acme.sh:7260`
- Triggers: Installed cron, Windows scheduler, Docker supercronic entrypoint.
- Responsibilities: Optional auto-upgrade, run `renewAll`, send bulk notifications, return renewal status.

**Docker entrypoint:**
- Location: `Dockerfile:78`
- Triggers: Container startup.
- Responsibilities: Generate default crontab for `daemon` mode and exec supercronic or the requested command.

**GitHub Actions:**
- Location: `.github/workflows/*.yml`
- Triggers: Push, pull request, workflow dispatch, tags, issues, wiki edits.
- Responsibilities: OS compatibility testing, DNS hook testing, shell formatting/linting, Docker image publishing, community workflow automation.

**GSD commands:**
- Location: `.codex/skills/*/SKILL.md`
- Triggers: Local Codex/GSD command invocation.
- Responsibilities: Planning, research, codebase mapping, execution, review, verification, and project state workflows. These do not participate in `acme.sh` certificate runtime.

## Architectural Constraints

- **Threading:** `acme.sh` uses a single shell process per command. Subprocesses are used for subshell isolation, external commands, background standalone servers (`acme.sh:2642`, `acme.sh:2781`), Docker/CI processes, and hook command execution.
- **Global state:** `acme.sh` uses module-level shell variables throughout (`ACME_DIRECTORY`, `ACCOUNT_CONF_PATH`, `DOMAIN_CONF`, `CERT_PATH`, `response`, `code`, `dns_entries`, `Le_*`). Treat command functions as stateful; always call `_initpath` before relying on paths.
- **Circular imports:** Not detected as static imports. Runtime sourcing is directional: `acme.sh` sources hook files; hook files assume helpers from `acme.sh` are already present.
- **Portability:** Keep implementation POSIX `sh` compatible unless code is explicitly inside CI, Dockerfile, or platform-specific external command sections. The repo tests many shells and OSes through `.github/workflows/*.yml`.
- **Persistence format:** Config files are shell assignment files parsed with grep/eval (`acme.sh:2470`). Values that may contain command text or spaces must use the existing base64 option in `_save_conf`.
- **Hook naming:** Hook file names and function names are coupled. A hook file in `dnsapi/dns_example.sh` must expose `dns_example_add` and `dns_example_rm`; `_findHook` and command construction rely on this coupling.
- **Secret handling:** Hook credentials are read from environment variables or persisted account/domain config, not committed repo files. No `.env`, `*.env`, `*.pem`, or `*.key` files are present in the repository scan.
- **Planning tooling boundary:** `.codex/` and `.planning/` are workflow/tooling areas. Runtime certificate changes should not import from or depend on these directories.

## Anti-Patterns

### Hook Contract Bypass

**What happens:** Adding provider behavior directly into `issue`, `_deploy`, or `_send_notify` instead of a hook module creates command-specific branching in `acme.sh`.
**Why it's wrong:** `acme.sh` already dispatches hooks by name with `_findHook` (`acme.sh:4188`), DNS command construction (`acme.sh:5165`), deploy command construction (`acme.sh:6260`), and notify command construction (`acme.sh:7332`). Direct provider branches expand the monolith and skip reusable hook credential patterns.
**Do this instead:** Add provider files under `dnsapi/`, `deploy/`, or `notify/` with the required function names and use shared config helpers, as shown in `dnsapi/dns_cf.sh`, `deploy/ssh.sh`, and `notify/slack.sh`.

### Path Use Before `_initpath`

**What happens:** Functions read or write `ACCOUNT_CONF_PATH`, `DOMAIN_CONF`, `CERT_PATH`, `CA_CONF`, or hook directories before `_initpath`/`__initHome` initializes them.
**Why it's wrong:** Paths depend on `$LE_WORKING_DIR`, `$LE_CONFIG_HOME`, `$CERT_HOME`, selected CA, selected key type, and domain name (`acme.sh:2807`, `acme.sh:2950`). Early path use writes to the wrong home or reads stale global values.
**Do this instead:** Call `_initpath` with the command's domain and ECC/keylength context before reading or writing persisted state; follow `renew` (`acme.sh:5787`), `deploy` (`acme.sh:6289`), and `installcert` (`acme.sh:6318`).

### Ad Hoc Secret Persistence

**What happens:** Hook credentials are stored in custom files or plaintext repo artifacts instead of account/domain config helpers.
**Why it's wrong:** Existing helpers centralize mutable credential handling and keep config under `$LE_CONFIG_HOME`; ad hoc files are missed by install, Docker, renewal, and secret redaction conventions.
**Do this instead:** Use `_readaccountconf_mutable`, `_saveaccountconf_mutable`, `_getdeployconf`, and `_savedeployconf` as shown in `dnsapi/dns_cf.sh:24`, `dnsapi/dns_oci.sh:96`, `deploy/ssh.sh:47`, and `notify/mail.sh:19`.

## Error Handling

**Strategy:** Shell return codes plus `_err` logging. Command functions return nonzero for errors; some workflows use special codes such as `RENEW_SKIP=2` and `CODE_DNS_MANUAL=3` (`acme.sh:93`).

**Patterns:**
- Use `_err` for failures and return `1` from functions; `_process` returns the command result (`acme.sh:8617`).
- Use `_info` for user-visible progress, `_debug`/`_secure_debug` for diagnostic output, and `OUTPUT_INSECURE=1` to reveal sensitive debug values intentionally (`acme.sh:297`, `acme.sh:362`, `acme.sh:8063`).
- Wrap hook loading and execution in subshells so provider functions do not leak local variables into the parent as much as direct sourcing would (`acme.sh:5159`, `acme.sh:6254`, `acme.sh:7326`).
- Clean up validation resources on error with `_clearup`, `_clearupdns`, `_restoreApache`, and `_restoreNginx` (`acme.sh:3523`).
- Retry transient ACME failures for nonce and overload responses in `_send_signed_request` (`acme.sh:2259`, `acme.sh:2359`).

## Cross-Cutting Concerns

**Logging:** `acme.sh` uses `_info`, `_err`, `_debug`, `_secure_debug`, optional log file, and optional syslog. Logging configuration is persisted in account config (`acme.sh:266`, `acme.sh:284`, `acme.sh:348`, `acme.sh:8490`).
**Validation:** Input validation is mostly inline in `_process`, command functions, and hook files. Examples include domain checks (`acme.sh:8015`), port and dependency prechecks (`acme.sh:6966`), DNS hook function checks (`acme.sh:5165`), and provider-specific credential checks (`dnsapi/dns_cf.sh:42`).
**Authentication:** ACME authentication uses account keys and JWS signatures (`acme.sh:2238`, `acme.sh:3850`). Provider authentication is hook-specific and uses environment variables plus persisted config helpers (`dnsapi/dns_cf.sh:24`, `dnsapi/dns_oci.sh:94`).
**Networking:** Core HTTP uses `curl` or `wget` selected by `_inithttp` (`acme.sh:1936`); standalone HTTP uses `socat` or Python (`acme.sh:2603`); TLS-ALPN uses OpenSSL `s_server` (`acme.sh:2724`).
**Scheduling:** Unix cron, fcron, Windows Task Scheduler, and Docker supercronic are supported through install and Docker paths (`acme.sh:6498`, `acme.sh:6448`, `Dockerfile:78`).
**Formatting and Quality Gates:** CI enforces shellcheck and shfmt through `.github/workflows/shellcheck.yml`; OS compatibility is covered by `.github/workflows/Linux.yml`, `.github/workflows/Ubuntu.yml`, and BSD/Solaris/Windows/macOS workflows.

---

*Architecture analysis: 2026-05-14*
