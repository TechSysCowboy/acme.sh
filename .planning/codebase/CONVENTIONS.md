# Coding Conventions

**Analysis Date:** 2026-05-14

## Naming Patterns

**Files:**
- Use POSIX shell script files with `#!/usr/bin/env sh` for runtime code. The main executable is `acme.sh`; hook modules live in `dnsapi/*.sh`, `deploy/*.sh`, and `notify/*.sh`.
- DNS provider files use lower snake names with the `dns_` prefix: `dnsapi/dns_cf.sh`, `dnsapi/dns_aws.sh`, `dnsapi/dns_oci.sh`.
- Deploy hook files use lower snake names without a directory prefix: `deploy/ssh.sh`, `deploy/synology_dsm.sh`, `deploy/byteplus_alb.sh`.
- Notify hook files use lower snake names without a directory prefix: `notify/discord.sh`, `notify/aws_ses.sh`, `notify/weixin_work.sh`.
- GSD support hooks under `.codex/hooks/*.sh` are executable Bash helper scripts and intentionally differ from runtime acme.sh modules. Keep these separate from POSIX runtime code.

**Functions:**
- Define shell functions as `name() {` with the opening brace on the same line. This is used in `acme.sh`, `dnsapi/dns_cf.sh`, `deploy/ssh.sh`, and `notify/discord.sh`.
- Internal helpers use a leading underscore: `_debug()`, `_post()`, `_findHook()`, `_get_root()`, `_cf_rest()`.
- Lower-level private helpers may use a double underscore when tightly coupled to another helper: `__debug_bash_helper()`, `__initHome()`, `__calcAccountKeyHash()`.
- DNS hooks must export public functions named after the file base: `dns_cf_add()` and `dns_cf_rm()` in `dnsapi/dns_cf.sh`, `dns_aws_add()` and `dns_aws_rm()` in `dnsapi/dns_aws.sh`.
- Deploy hooks must expose `<hook>_deploy()`, for example `ssh_deploy()` in `deploy/ssh.sh` and `byteplus_alb_deploy()` in `deploy/byteplus_alb.sh`.
- Notify hooks must expose `<hook>_send()`, for example `discord_send()` in `notify/discord.sh` and `telegram_send()` in `notify/telegram.sh`.
- Core CLI functions in `acme.sh` include both lower-case command names (`registeraccount()`, `deploy()`, `setnotify()`) and older camel-style public wrappers (`createAccountKey()`, `createDomainKey()`, `createCSR()`). Match the surrounding command family instead of introducing a new style.

**Variables:**
- Global constants use upper snake case: `DEFAULT_CA`, `CA_ZEROSSL`, `LOG_LEVEL_1`, `NOTIFY_LEVEL_DEFAULT` in `acme.sh`.
- Project-private globals use a leading underscore with upper snake case: `_SUB_FOLDER_DNSAPI`, `_SUB_FOLDERS`, `_DNS_API_WIKI` in `acme.sh`.
- Function scratch variables commonly use lower snake case with a leading underscore, such as `_domain_id`, `_sub_domain`, `_deployApi`, `_n_hook_file`.
- Provider configuration variables keep the provider prefix and existing provider-specific casing: `CF_Token`, `CF_Account_ID`, `AWS_ACCESS_KEY_ID`, `DEPLOY_SSH_USER`, `DISCORD_WEBHOOK_URL`.
- Avoid `local` in POSIX runtime scripts. Variables are assigned directly inside functions, so choose names with provider or helper prefixes to avoid collisions.
- Quote variable expansions by default: `"$fulldomain"`, `"$_domain_id"`, `"$response"`, and `"$(command)"`.

**Types:**
- Runtime code is untyped POSIX shell. Functions communicate success with exit status `0` and failure with non-zero returns, usually `return 1`.
- Data objects are plain shell strings, files, and process output. Shared HTTP response state commonly uses the global `response` variable after `_get()` or `_post()`.
- Configuration is read from environment variables and account/domain/deploy config helpers, not structured config objects.
- GSD hook support under `.codex/hooks/*.js` uses Node.js/CommonJS for JSON parsing and typed JSON hook envelopes.

## Code Style

**Formatting:**
- Use `shfmt` formatting with two-space indentation. CI runs `~/shfmt -l -w -i 2 .` from `.github/workflows/shellcheck.yml`.
- Runtime shell scripts target POSIX `sh`, not Bash. Use `#!/usr/bin/env sh` in `acme.sh`, `dnsapi/*.sh`, `deploy/*.sh`, and `notify/*.sh`.
- Do not add global `set -e`, `set -u`, or `pipefail` to sourced runtime modules; the current source uses explicit return checks instead.
- Prefer `$(command)` over backticks. This pattern is consistent in `acme.sh`, `dnsapi/dns_cf.sh`, `dnsapi/dns_aws.sh`, and `deploy/ssh.sh`.
- Use portable single-bracket tests: `[ -z "$VAR" ]`, `[ "$value" = "yes" ]`, and `if ! command; then ... fi`.
- Keep command wrappers and portability helpers in `acme.sh` rather than using platform-specific command flags directly in hooks.

**Linting:**
- ShellCheck is the enforced shell linter. CI runs `shellcheck -V && shellcheck -e SC2181 -e SC2089 **/*.sh` in `.github/workflows/shellcheck.yml`.
- No `.shellcheckrc` file is present. Suppressions are inline and should be narrow, such as `# shellcheck disable=SC2034` for hook metadata variables in `dnsapi/dns_cf.sh`.
- Do not suppress ShellCheck globally unless the file follows an established metadata pattern. Prefer local suppressions near the exact portable-shell exception.
- `.github/copilot-instructions.md` defines review priorities for shell changes: POSIX portability, quoting, return-value checks, helper function use, and avoiding non-portable tools.
- GSD project hooks are opt-in through `.planning/config.json` and `.codex/config.toml`; `.codex/hooks/gsd-validate-commit.sh` enforces Conventional Commit subjects when community hooks are enabled.

## Import Organization

**Order:**
1. Runtime constants and metadata at the top of the file, for example `dns_cf_info` in `dnsapi/dns_cf.sh` and top-level constants in `acme.sh`.
2. Public hook or command functions, marked in many plugins by `########  Public functions #####################`.
3. Private helper functions, marked in many plugins by `####################  Private functions below ##################################`.

**Path Aliases:**
- Not applicable. The codebase uses shell paths and dynamic hook lookup, not language-level import aliases.
- Core hook categories are named in `acme.sh` as `_SUB_FOLDER_DNSAPI="dnsapi"`, `_SUB_FOLDER_DEPLOY="deploy"`, and `_SUB_FOLDER_NOTIFY="notify"`.
- Load hooks through `_findHook()` in `acme.sh`; do not hard-code alternate search paths in plugins.

## Error Handling

**Patterns:**
- Use explicit checks and `return 1`. Do not rely on shell options for control flow.
- Emit user-facing errors with `_err`, then return a failure status:

```sh
if [ -z "$CF_Key" ] || [ -z "$CF_Email" ]; then
  CF_Key=""
  CF_Email=""
  _err "You didn't specify a Cloudflare api key and email yet."
  _err "You can get yours from here https://dash.cloudflare.com/profile."
  return 1
fi
```

- Wrap external or helper calls with `if ! ...; then` when failure must stop the operation:

```sh
if ! _get_root "$fulldomain"; then
  _err "invalid domain"
  return 1
fi
```

- Treat idempotent absence as success when appropriate, such as DNS remove paths that log `"Don't need to remove."` in `dnsapi/dns_cf.sh`.
- Use `_exists` before optional external tools. Core helper `_exists()` in `acme.sh` centralizes command detection.
- Use `_secure_debug`, `_secure_debug2`, or `_secure_debug3` for secrets and authorization material. Do not log API tokens, private keys, passwords, or generated credentials with `_debug`.
- Use `_mktemp()` from `acme.sh` for temporary files in runtime code. Existing examples include `dnsapi/dns_oci.sh`, `deploy/ssh.sh`, and `deploy/unifi.sh`.

## Logging

**Framework:** acme.sh logging helpers, plus console output

**Patterns:**
- Use `_info` for normal progress messages and successful user-visible milestones.
- Use `_err` for user-visible errors; `_err` returns `1`, but call sites still explicitly return where control flow requires it.
- Use `_debug`, `_debug2`, and `_debug3` for increasing verbosity. `.github/copilot-instructions.md` prefers `_debug2` unless a different level is justified.
- Use `_secure_debug*` for any secret or sensitive derived value. `dnsapi/dns_aws.sh` uses `_secure_debug2 kSecret "$kSecret"` and `_secure_debug "_aws_creds" "$_aws_creds"`.
- Core logging in `acme.sh` supports `LOG_FILE`, timestamped stderr, and syslog levels through `_log()`, `_syslog()`, and `_printargs()`.

## Comments

**When to Comment:**
- Include usage comments above public hook functions, as in `dnsapi/dns_cf.sh` and `dnsapi/dns_aws.sh`.
- Keep provider metadata blocks in DNS hooks. The `dns_*_info` variable documents site, wiki docs, and supported environment options.
- Comment portability or platform-specific decisions, especially when using non-obvious `sed`, `tr`, VM, or API signing behavior.
- Keep ShellCheck suppressions explicit and close to the reason. Examples are `# shellcheck disable=SC2034` for metadata and `# shellcheck disable=SC2086` for intentional word splitting.
- GSD workflow skills in `.codex/skills/*/SKILL.md` use YAML front matter and XML-like sections. Preserve their adapter sections and user-gated workflow rules when editing GSD instructions.

**JSDoc/TSDoc:**
- Not applicable for runtime shell code.
- `.codex/hooks/*.js` uses inline comments rather than JSDoc; preserve typed JSON output contracts when editing those hooks.

## Function Design

**Size:** Keep new hook public functions small enough to read as one provider operation. Large provider files such as `dnsapi/dns_aws.sh` and `deploy/ssh.sh` split signing, root detection, remote command, and API helpers into private functions.

**Parameters:** Read positional parameters immediately into named variables:

```sh
fulldomain=$1
txtvalue=$2
```

Use hook-specific parameter contracts:
- DNS add/remove: `fulldomain=$1`, `txtvalue=$2`.
- Deploy: `_cdomain="$1"`, `_ckey="$2"`, `_ccert="$3"`, `_cca="$4"`, `_cfullchain="$5"`.
- Notify: `_subject="$1"`, `_content="$2"`, `_statusCode="$3"`.

**Return Values:** Return `0` for success and `1` for general failure. Preserve special constants such as `RENEW_SKIP=2` and `CODE_DNS_MANUAL=3` from `acme.sh`.

## Module Design

**Exports:** Shell modules export functions by name. `acme.sh` sources hook files dynamically and checks for the expected function:

```sh
d_command="${_d_api}_deploy"
if ! _exists "$d_command"; then
  _err "It seems that your API file is not correct. Make sure it has a function named: $d_command"
  return 1
fi
```

- DNS modules must provide matching `<filebase>_add` and `<filebase>_rm` functions.
- Deploy modules must provide `<filebase>_deploy`.
- Notify modules must provide `<filebase>_send`.
- New hooks should rely on helpers from `acme.sh` and should not source each other directly.

**Barrel Files:** Not used. Discovery is directory-based through `_findHook()` in `acme.sh` and naming conventions in `dnsapi/`, `deploy/`, and `notify/`.

---

*Convention analysis: 2026-05-14*
