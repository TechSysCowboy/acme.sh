# Technology Stack

**Analysis Date:** 2026-05-14

## Languages

**Primary:**
- POSIX shell (`sh`) - Main executable `acme.sh` and all runtime plugins in `dnsapi/*.sh`, `deploy/*.sh`, and `notify/*.sh`; the shebang is `#!/usr/bin/env sh` in `acme.sh`.

**Secondary:**
- Bash - Some deploy hooks use Bash-specific shebangs where needed, such as `deploy/synology_dsm.sh`.
- Dockerfile - Container image build and runtime wrapper in `Dockerfile`.
- YAML - GitHub Actions workflows in `.github/workflows/*.yml`.
- Markdown - User-facing documentation in `README.md`, `dnsapi/README.md`, and `deploy/README.md`.

## Runtime

**Environment:**
- POSIX-compatible shell runtime. `README.md` states compatibility with Bash, dash, and sh; `acme.sh` invokes `/usr/bin/env sh`.
- Project version: `v3.1.4` from `VER=3.1.4` in `acme.sh` and `./acme.sh --version`.
- Runtime home defaults to `$HOME/.acme.sh` through `DEFAULT_INSTALL_HOME` in `acme.sh`.
- Config and certificate state use filesystem paths derived from `LE_WORKING_DIR`, `LE_CONFIG_HOME`, `ACCOUNT_CONF_PATH`, and `CERT_HOME` in `acme.sh`.
- Docker runtime base is `alpine:3.23` in `Dockerfile`.

**Package Manager:**
- No language package manager detected; no `package.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, or lockfile exists in the repository root.
- Container dependencies are installed through Alpine `apk` in `Dockerfile`.
- CI installs OS packages through `apt-get`, `brew`, `pkg`, `mport`, `pkg_add`, and `pkgutil` in `.github/workflows/*.yml`.
- Lockfile: missing / not applicable for the shell codebase.

## Frameworks

**Core:**
- Custom ACME v2 shell client - `acme.sh` implements account registration, order creation, challenge handling, certificate renewal, revocation, deployment, and notification.
- Plugin hook system - DNS, deploy, and notify integrations are loaded from `dnsapi/`, `deploy/`, and `notify/` by `_findHook` and hook execution logic in `acme.sh`.

**Testing:**
- ShellCheck - Static analysis configured in `.github/workflows/shellcheck.yml`.
- shfmt `v3.1.2` - Formatting check configured in `.github/workflows/shellcheck.yml`.
- acmetest - External test harness cloned from `https://github.com/acmesh-official/acmetest.git` in `.github/workflows/Ubuntu.yml`, `.github/workflows/Linux.yml`, `.github/workflows/DNS.yml`, and platform workflows.
- Pebble strict ACME server - Integration validation in `.github/workflows/PebbleStrict.yml`.
- Smallstep Step CA `smallstep/step-ca:0.23.1` - Local ACME CA validation in `.github/workflows/Ubuntu.yml`.

**Build/Dev:**
- Docker / Buildx - Multi-architecture image publishing is configured in `.github/workflows/dockerhub.yml` and uses `Dockerfile`.
- GitHub Actions - CI matrix workflows live in `.github/workflows/` for Ubuntu, Linux containers, macOS, Windows/Cygwin, BSDs, Solaris-family platforms, Haiku, DNS APIs, ShellCheck, DockerHub, PR automation, issue automation, and wiki monitoring.
- vmactions VM actions - BSD, Solaris, OmniOS, OpenIndiana, and Haiku validation use `vmactions/*-vm@v1` in `.github/workflows/*.yml`.
- anyvm Cloudflare tunnel action - HTTP validation exposes local port 80 via `anyvm-org/cf-tunnel@v0` in platform workflows such as `.github/workflows/Linux.yml`.

## Key Dependencies

**Critical:**
- `openssl` - Required for account keys, domain keys, CSRs, signatures, hashing, base64, certificate parsing, PKCS conversion, and TLS material handling in `acme.sh`.
- `curl` or `wget` - Required HTTP clients for ACME, DNS APIs, deploy hooks, notification hooks, and upgrade checks through `_get` and `_post` in `acme.sh`.
- `sed`, `grep`, `awk`, `cut`, `tr`, `wc`, `date`, `head`, `tail` - Core POSIX text and filesystem utilities used across `acme.sh`, `dnsapi/*.sh`, `deploy/*.sh`, and `notify/*.sh`.
- `socat` - Used for standalone HTTP/TLS challenge serving and platform tests; installed in `Dockerfile` and CI workflows.
- `cron` / `crontab` / Windows Scheduler / `supercronic` - Renewal scheduling uses cron logic in `acme.sh`; container daemon mode uses `supercronic` in `Dockerfile`.

**Infrastructure:**
- `idn` / `libidn` - IDN domain conversion support is implemented in `_idn` in `acme.sh`; `libidn` is installed in `Dockerfile`.
- `openssh-client`, `ssh`, `scp` - Remote certificate deployment is implemented in `deploy/ssh.sh`, `deploy/routeros.sh`, `deploy/openmediavault.sh`, and `deploy/windows_rdp.sh`; `openssh-client` is installed in `Dockerfile`.
- `docker` CLI or Docker socket - Container certificate deployment is implemented in `deploy/docker.sh`.
- `jq` and `yq-go` - Installed in `Dockerfile` for container operational workflows and helper scripts.
- `oath-toolkit-oathtool` - Installed in `Dockerfile`; Synology DSM TOTP support checks for `oathtool` in `deploy/synology_dsm.sh`.
- `mail`, `sendmail`, `msmtp`, `sendxmpp`, `python`, `curl` SMTP support - Notification hooks use local mail/XMPP commands in `notify/mail.sh`, `notify/xmpp.sh`, and `notify/smtp.sh`.

## Configuration

**Environment:**
- Configure runtime location with `LE_WORKING_DIR`, `LE_CONFIG_HOME`, `ACCOUNT_CONF_PATH`, and `CERT_HOME`; these are read and persisted by `acme.sh`.
- Configure HTTP client behavior with `ACME_USE_WGET`, `ACME_USE_IPV4_REQUESTS`, `ACME_USE_IPV6_REQUESTS`, `CA_BUNDLE`, `CA_PATH`, and `HTTPS_INSECURE` in `acme.sh`.
- Configure crypto with `ACME_OPENSSL_BIN`, `DEFAULT_ACCOUNT_KEY_LENGTH`, and `DEFAULT_DOMAIN_KEY_LENGTH` in `acme.sh`.
- Configure ACME CA selection with `DEFAULT_ACME_SERVER`, `--server`, and CA constants in `acme.sh`.
- Configure logs and notifications with `LOG_FILE`, `LOG_LEVEL`, `SYS_LOG`, `NOTIFY_HOOK`, `NOTIFY_LEVEL`, `NOTIFY_MODE`, and `NOTIFY_SOURCE` in `acme.sh`.
- Configure DNS provider credentials through provider-specific environment variables read by `dnsapi/*.sh`, then saved via account/domain config helpers in `acme.sh`.
- Configure deploy hooks through provider-specific variables read by `deploy/*.sh`, then saved as `SAVED_*` entries in domain config via `acme.sh`.

**Build:**
- `Dockerfile` defines the Alpine runtime image, installed OS packages, `/entry.sh`, generated verb wrappers, `LE_WORKING_DIR=/acmebin`, `LE_CONFIG_HOME=/acme.sh`, and `/acme.sh` volume.
- `.github/workflows/shellcheck.yml` runs ShellCheck and shfmt.
- `.github/workflows/dockerhub.yml` builds and publishes `neilpang/acme.sh` multi-architecture images.
- `.github/workflows/Ubuntu.yml`, `.github/workflows/Linux.yml`, and platform workflows run acmetest across shell/OS targets.
- `.github/workflows/DNS.yml` validates DNS API plugins using GitHub Actions secrets and acmetest.
- `.github/workflows/pr_dns.yml`, `.github/workflows/pr_notify.yml`, `.github/workflows/issue.yml`, and `.github/workflows/wiki-monitor.yml` provide repository automation.

## Platform Requirements

**Development:**
- Use a POSIX shell plus `openssl` and either `curl` or `wget` to run `acme.sh`.
- Install `socat` for standalone challenge flows and CI parity with `.github/workflows/*.yml`.
- Install ShellCheck and shfmt for local quality checks matching `.github/workflows/shellcheck.yml`.
- Keep DNS/deploy/notify hooks as shell scripts in `dnsapi/`, `deploy/`, and `notify/`; do not introduce a language package manager for runtime plugins.

**Production:**
- Standard install target is `$HOME/.acme.sh` with daily cron renewal configured by `acme.sh`.
- Container target is the Alpine image defined by `Dockerfile`, with persistent state mounted at `/acme.sh` and daemon renewal driven by `supercronic`.
- Supported OS targets include Linux distributions, macOS, Windows/Cygwin, FreeBSD, OpenBSD, NetBSD, DragonFlyBSD, MidnightBSD, Solaris, OmniOS, OpenIndiana, and Haiku as represented by `README.md` and `.github/workflows/*.yml`.

---

*Stack analysis: 2026-05-14*
