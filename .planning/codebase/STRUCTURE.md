# Codebase Structure

**Analysis Date:** 2026-05-14

## Directory Layout

```text
acme.sh/
|-- acme.sh              # Main POSIX shell executable and complete ACME client runtime
|-- Dockerfile           # Alpine container image, command wrappers, and supercronic entrypoint
|-- README.md            # User-facing feature, install, issue, renew, deploy, and usage guide
|-- LICENSE.md           # GPL license text
|-- dnsapi/              # DNS-01 provider hook modules
|-- deploy/              # Certificate deployment hook modules
|-- notify/              # Renewal notification hook modules
|-- test/                # Repo-local mocked shell harnesses for focused provider characterization
|-- .github/             # GitHub issue/PR templates and Actions workflows
|-- .codex/              # GSD/Codex workflow skills, agents, hooks, templates, and references
`-- .planning/           # GSD planning outputs; codebase maps are written under `.planning/codebase/`
```

## Directory Purposes

**Root Application Files:**
- Purpose: Hold the shell application, packaging entrypoint, user documentation, and license.
- Contains: `acme.sh`, `Dockerfile`, `README.md`, `LICENSE.md`.
- Key files: `acme.sh`, `Dockerfile`, `README.md`.

**`dnsapi/`:**
- Purpose: DNS provider plugins for automated DNS-01 validation.
- Contains: 179 files, mostly `dns_<provider>.sh` hook modules plus `dnsapi/README.md`.
- Key files: `dnsapi/dns_cf.sh`, `dnsapi/dns_oci.sh`, `dnsapi/dns_aws.sh`, `dnsapi/dns_azure.sh`, `dnsapi/README.md`.
- Add DNS integrations here. A file named `dnsapi/dns_example.sh` must define `dns_example_add()` and `dns_example_rm()`.

**`deploy/`:**
- Purpose: Certificate deployment plugins for services, appliances, web servers, storage, and remote hosts.
- Contains: 54 files, mostly `<target>.sh` hook modules plus `deploy/README.md`.
- Key files: `deploy/ssh.sh`, `deploy/docker.sh`, `deploy/localcopy.sh`, `deploy/multideploy.sh`, `deploy/nginx.sh`, `deploy/apache.sh`, `deploy/README.md`.
- Add deployment integrations here. A file named `deploy/example.sh` must define `example_deploy()`.

**`notify/`:**
- Purpose: Notification plugins used by cron/renewal outcomes.
- Contains: 26 files, each exposing `<channel>_send()`.
- Key files: `notify/mail.sh`, `notify/slack.sh`, `notify/smtp.sh`, `notify/telegram.sh`, `notify/aws_ses.sh`.
- Add notification integrations here. A file named `notify/example.sh` must define `example_send()`.

**`test/`:**
- Purpose: Repo-local shell proof harnesses for focused provider behavior that must stay credential-free.
- Contains: `test/dns_oci_mock.sh` for OCI DNS hook characterization.
- Key files: `test/dns_oci_mock.sh`.
- Runtime note: These scripts are local validation support; `acme.sh` does not source them during normal operation.

**`.github/`:**
- Purpose: GitHub community automation and CI.
- Contains: `ISSUE_TEMPLATE.md`, `PULL_REQUEST_TEMPLATE.md`, `copilot-instructions.md`, funding config, and workflow YAML files.
- Key files: `.github/workflows/shellcheck.yml`, `.github/workflows/DNS.yml`, `.github/workflows/Linux.yml`, `.github/workflows/Ubuntu.yml`, `.github/workflows/PebbleStrict.yml`, `.github/workflows/dockerhub.yml`.

**`.codex/`:**
- Purpose: Local GSD/Codex workflow installation.
- Contains: agent Markdown/TOML configs, skill adapters, hooks, GSD workflow references, templates, and manifest.
- Key files: `.codex/config.toml`, `.codex/skills/gsd-map-codebase/SKILL.md`, `.codex/agents/gsd-codebase-mapper.toml`, `.codex/get-shit-done/VERSION`, `.codex/gsd-file-manifest.json`.
- Runtime note: `acme.sh` does not source or execute files in `.codex/`.

**`.planning/`:**
- Purpose: GSD planning artifacts and codebase maps.
- Contains: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.
- Runtime note: `acme.sh` does not read `.planning/`.

## Key File Locations

**Entry Points:**
- `acme.sh`: Main CLI script. `main "$@"` is at `acme.sh:8658`; command parser starts at `acme.sh:7831`.
- `Dockerfile`: Container entrypoint and command wrapper generator. Runtime entry script is generated at `Dockerfile:78`.
- `.github/workflows/*.yml`: CI entry points for GitHub Actions.
- `.codex/skills/*/SKILL.md`: GSD command entry points for local planning workflows.

**Configuration:**
- `acme.sh:3`: Application version constant `VER`.
- `acme.sh:23`: Built-in ACME CA URLs and defaults.
- `acme.sh:2807`: Working/config home initialization through `__initHome`.
- `acme.sh:2950`: Domain/account/CA/cert path initialization through `_initpath`.
- `acme.sh:2393`: Config file write/read helper layer.
- `.codex/config.toml`: GSD agent and hook registry.
- `.github/workflows/shellcheck.yml`: Shellcheck and shfmt quality gate.

**Core Logic:**
- `acme.sh:1928`: HTTP client setup and `curl`/`wget` selection.
- `acme.sh:2238`: JWS signed request transport.
- `acme.sh:2878`: ACME directory discovery.
- `acme.sh:3850`: Account registration.
- `acme.sh:4604`: Certificate issuance workflow.
- `acme.sh:5776`: Single certificate renewal.
- `acme.sh:5925`: All-certificate renewal loop.
- `acme.sh:6242`: Deployment hook dispatch.
- `acme.sh:7294`: Notification hook dispatch.
- `acme.sh:7631`: Online upgrade hash and upgrade flow.

**Validation Modes:**
- `acme.sh:2603`: Standalone HTTP-01 server.
- `acme.sh:2724`: Standalone TLS-ALPN-01 server.
- `acme.sh:3128`: Apache mode.
- `acme.sh:3284`: Nginx mode.
- `acme.sh:5067`: DNS persist and DNS-01 challenge setup.
- `acme.sh:4428`: DNS-over-HTTPS TXT propagation checks.
- `acme.sh:3537`: DNS cleanup.

**Hook Implementations:**
- `dnsapi/dns_cf.sh`: Cloudflare DNS hook using `CF_*` account/domain config.
- `dnsapi/dns_oci.sh`: Oracle Cloud Infrastructure DNS hook using OCI CLI config or env variables.
- `deploy/ssh.sh`: Remote SSH deployment hook using `DEPLOY_SSH_*` values.
- `deploy/docker.sh`: Docker container deployment hook using Docker API over Unix socket.
- `deploy/multideploy.sh`: YAML-driven multi-service deploy hook using `yq`.
- `notify/mail.sh`: Local mail notification hook.
- `notify/slack.sh`: Slack webhook notification hook.
- `notify/smtp.sh`: SMTP notification hook with curl/Python transport.

**Testing and CI:**
- `test/dns_oci_mock.sh`: Repo-local mocked OCI DNS hook harness with `le_test_*` cases and `CASE` selection.
- `.github/workflows/shellcheck.yml`: Runs shellcheck over `**/*.sh` and shfmt with two-space indentation.
- `.github/workflows/DNS.yml`: Runs DNS API tests through `acmetest` with provider secrets.
- `.github/workflows/PebbleStrict.yml`: Runs strict Pebble ACME tests, including IP certificate path.
- `.github/workflows/Linux.yml`: Runs Dockerized Linux distribution matrix tests.
- `.github/workflows/Ubuntu.yml`: Runs Ubuntu matrix against staging, ZeroSSL, StepCA, and IP certificate cases.
- `.github/workflows/Windows.yml`: Runs Cygwin-based Windows tests.
- `.github/workflows/MacOS.yml`: Runs macOS tests.
- `.github/workflows/*BSD.yml`, `.github/workflows/Solaris.yml`, `.github/workflows/Omnios.yml`, `.github/workflows/OpenIndiana.yml`, `.github/workflows/Haiku.yml`: Run portability tests across non-Linux platforms.

**Documentation:**
- `README.md`: Main user guide and command examples.
- `dnsapi/README.md`: DNS API hook documentation pointer.
- `deploy/README.md`: Deploy hook documentation pointer.
- `.github/copilot-instructions.md`: GitHub Copilot repository guidance.
- `.planning/codebase/ARCHITECTURE.md`: Architecture map for GSD planning and execution.
- `.planning/codebase/STRUCTURE.md`: Structure map for GSD planning and execution.

## Naming Conventions

**Files:**
- Main executable: `acme.sh` at repo root.
- DNS hook files: `dnsapi/dns_<provider>.sh`, for example `dnsapi/dns_cf.sh` and `dnsapi/dns_oci.sh`.
- Deploy hook files: `deploy/<target>.sh`, for example `deploy/ssh.sh` and `deploy/docker.sh`.
- Notify hook files: `notify/<channel>.sh`, for example `notify/slack.sh` and `notify/mail.sh`.
- GitHub workflow files: `.github/workflows/<Name>.yml`, with OS workflows using title case such as `.github/workflows/Linux.yml`.
- GSD skill files: `.codex/skills/<command>/SKILL.md`, for example `.codex/skills/gsd-map-codebase/SKILL.md`.

**Directories:**
- Provider registry directories are singular by integration type: `dnsapi/`, `deploy/`, `notify/`.
- Tooling directories are hidden at repo root: `.github/`, `.codex/`, `.planning/`.
- Runtime installation directories are not committed: `$LE_WORKING_DIR`, `$LE_CONFIG_HOME`, `$CERT_HOME`, and per-domain cert directories are created by installed `acme.sh`.

**Functions:**
- Shared/internal helpers in `acme.sh` use leading underscores: `_initpath`, `_send_signed_request`, `_savedomainconf`.
- Public command functions in `acme.sh` often omit leading underscores: `issue`, `renew`, `deploy`, `install`, `cron`.
- DNS hooks use `dns_<provider>_add` and `dns_<provider>_rm`: `dns_cf_add`, `dns_cf_rm`.
- Deploy hooks use `<target>_deploy`: `ssh_deploy`, `docker_deploy`, `multideploy_deploy`.
- Notify hooks use `<channel>_send`: `mail_send`, `slack_send`, `smtp_send`.

**State Variables:**
- Account and environment settings use uppercase names: `ACCOUNT_CONF_PATH`, `ACME_DIRECTORY`, `CERT_HOME`, `LE_CONFIG_HOME`.
- Domain persisted settings use `Le_` prefix: `Le_Domain`, `Le_Webroot`, `Le_NextRenewTime`, `Le_DeployHook`.
- Saved mutable hook settings use `SAVED_` prefix in config helpers: `SAVED_CF_Token`, `SAVED_DEPLOY_SSH_USER`.

## Where to Add New Code

**New CLI Command:**
- Primary code: Add a command function in `acme.sh` near related command implementations.
- Parser: Add `_CMD` mapping in `_process` near `acme.sh:7895`.
- Dispatch: Add a branch in the final command dispatch near `acme.sh:8527`.
- Help: Add usage text in `showhelp` near `acme.sh:7418`.
- Tests/CI: Ensure `.github/workflows/shellcheck.yml` passes and add/adjust relevant OS or Pebble workflow coverage if behavior affects ACME runtime.

**New ACME Protocol Behavior:**
- Primary code: Add to the relevant `acme.sh` layer: API discovery near `_initAPI`, order/issue behavior in `issue`, renewal behavior in `renew`, or account behavior in `_regAccount`.
- State: Persist command/account/domain settings with `_saveaccountconf`, `_savecaconf`, or `_savedomainconf` in `acme.sh`.
- Tests: Add coverage through `.github/workflows/PebbleStrict.yml`, `.github/workflows/Ubuntu.yml`, or external `acmetest` paths if protocol behavior changes.

**New DNS Provider:**
- Implementation: `dnsapi/dns_<provider>.sh`.
- Required functions: `dns_<provider>_add()` and `dns_<provider>_rm()`.
- Credential persistence: Use `_readaccountconf_mutable` and `_saveaccountconf_mutable` for account-level provider values, and `_savedomainconf` only for domain-scoped values such as a provider zone ID.
- Documentation: Update `dnsapi/README.md` only if local docs change; primary usage docs are linked from the wiki.
- Tests: Update or run DNS API test workflow expectations in `.github/workflows/DNS.yml`.

**New Deploy Hook:**
- Implementation: `deploy/<hook>.sh`.
- Required function: `<hook>_deploy()`.
- Inputs: Accept domain, key file, cert file, CA file, fullchain file, and PFX file in the order used by `_deploy` at `acme.sh:6266`.
- Credential persistence: Use `_getdeployconf`, `_savedeployconf`, and `_migratedeployconf`.
- Documentation: Update `deploy/README.md` only if local docs change; primary usage docs are linked from the wiki.

**New Notify Hook:**
- Implementation: `notify/<hook>.sh`.
- Required function: `<hook>_send()`.
- Inputs: Accept subject, content, and status code in the order used by `_send_notify` at `acme.sh:7338`.
- Credential persistence: Use `_readaccountconf_mutable` and `_saveaccountconf_mutable`.
- Command integration: No parser changes are needed when the hook follows naming convention.

**New Container Runtime Behavior:**
- Primary code: `Dockerfile`.
- Wrapper changes: Add command wrappers to the loop in `Dockerfile:43` when a new CLI command should be exposed as `/usr/local/bin/--<verb>`.
- Daemon changes: Modify the generated `/entry.sh` block at `Dockerfile:78`.

**New CI Workflow:**
- Implementation: `.github/workflows/<Name>.yml`.
- Scope: Keep path filters narrow to the files that trigger the workflow.
- Existing patterns: OS test workflows clone `acmetest`, copy this repo into it, and run `letest.sh` or `rundocker.sh`; formatting gates live in `.github/workflows/shellcheck.yml`.

**New GSD/Planning Artifact:**
- Implementation: `.planning/<area>/...` for planning outputs.
- Skills/agents: `.codex/skills/` and `.codex/agents/` are generated/managed by the GSD installer; avoid hand edits unless updating the local workflow installation itself.

## Special Directories

**`dnsapi/`:**
- Purpose: DNS provider hook registry.
- Generated: No.
- Committed: Yes.

**`deploy/`:**
- Purpose: Certificate deployment hook registry.
- Generated: No.
- Committed: Yes.

**`notify/`:**
- Purpose: Notification hook registry.
- Generated: No.
- Committed: Yes.

**`.github/`:**
- Purpose: GitHub templates and CI automation.
- Generated: No.
- Committed: Yes.

**`.codex/`:**
- Purpose: Local GSD/Codex workflow installation with generated skill, agent, reference, workflow, and template files.
- Generated: Yes, by GSD installer/update tooling.
- Committed: Yes in this repository snapshot.

**`.planning/`:**
- Purpose: GSD planning outputs and codebase maps.
- Generated: Yes, by GSD commands and mapper agents.
- Committed: Depends on workflow; codebase maps are intended planning artifacts.

**Runtime `$LE_WORKING_DIR`:**
- Purpose: Installed copy of `acme.sh` and hook directories, defaulting to `$HOME/.acme.sh`.
- Generated: Yes, by `acme.sh --install`.
- Committed: No.

**Runtime `$LE_CONFIG_HOME`:**
- Purpose: Account config, CA config, cert artifacts, logs, temporary files, and per-domain state.
- Generated: Yes, by `acme.sh` commands.
- Committed: No.

---

*Structure analysis: 2026-05-14*
