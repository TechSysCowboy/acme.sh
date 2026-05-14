# External Integrations

**Analysis Date:** 2026-05-14

## APIs & External Services

**ACME Certificate Authorities:**
- ZeroSSL - Default ACME CA for certificate issuance in `acme.sh`.
  - SDK/Client: Custom shell ACME client in `acme.sh` using `_get`, `_post`, and `_send_signed_request`.
  - Auth: ACME account key in `ACCOUNT_CONF_PATH`; EAB credentials from ZeroSSL endpoint are requested through `_ZERO_EAB_ENDPOINT` in `acme.sh`.
- Let's Encrypt production and staging - ACME v2 issuance and tests in `acme.sh` and `.github/workflows/*.yml`.
  - SDK/Client: Custom shell ACME client in `acme.sh`.
  - Auth: ACME account key in `ACCOUNT_CONF_PATH`.
- SSL.com, Google Public CA, and Actalis - Built-in CA aliases and directory URLs in `acme.sh`.
  - SDK/Client: Custom shell ACME client in `acme.sh`.
  - Auth: ACME account key in `ACCOUNT_CONF_PATH`; external account binding when required by the selected CA.
- Custom RFC8555-compatible ACME servers - User-provided `--server` / `DEFAULT_ACME_SERVER` handled by `acme.sh`.
  - SDK/Client: Custom shell ACME client in `acme.sh`.
  - Auth: ACME account key and optional EAB values in `ACCOUNT_CONF_PATH`.

**DNS Challenge Provider APIs:**
- DNS API plugins - 178 provider modules under `dnsapi/` add and remove `_acme-challenge` TXT records.
  - SDK/Client: Shell REST/XML/custom clients using shared `_get` and `_post` helpers in `acme.sh`; no provider SDK packages.
  - Auth: Provider-specific env vars saved through `_saveaccountconf_mutable`, `_savedomainconf`, and related helpers in `acme.sh`.
- Major cloud DNS examples - Cloudflare `dnsapi/dns_cf.sh`, AWS Route53 `dnsapi/dns_aws.sh`, Azure DNS `dnsapi/dns_azure.sh`, OCI DNS `dnsapi/dns_oci.sh`, Google Domains ACME DNS `dnsapi/dns_googledomains.sh`, DigitalOcean `dnsapi/dns_dgon.sh`, Alibaba Cloud DNS `dnsapi/dns_ali.sh`, Tencent Cloud `dnsapi/dns_tencent.sh`, Huawei Cloud `dnsapi/dns_huaweicloud.sh`, and Baidu Cloud `dnsapi/dns_baidu.sh`.
  - SDK/Client: Shared shell HTTP client in `acme.sh` plus provider-specific signing/parsing in each `dnsapi/*.sh`.
  - Auth: Examples include `CF_Token`, `CF_Key`, `CF_Email`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AZUREDNS_*`, `OCI_CLI_*`, `DO_API_KEY`, `Ali_Key`, and `Tencent_SecretId`.
- Registrar and hosting DNS examples - GoDaddy `dnsapi/dns_gd.sh`, Namecheap `dnsapi/dns_namecheap.sh`, Name.com `dnsapi/dns_namecom.sh`, OVH `dnsapi/dns_ovh.sh`, Porkbun `dnsapi/dns_porkbun.sh`, Netcup `dnsapi/dns_netcup.sh`, Hetzner `dnsapi/dns_hetzner.sh`, Linode `dnsapi/dns_linode_v4.sh`, Vultr `dnsapi/dns_vultr.sh`, Netlify `dnsapi/dns_netlify.sh`, Vercel `dnsapi/dns_vercel.sh`, and OpenProvider `dnsapi/dns_openprovider_rest.sh`.
  - SDK/Client: Provider-specific shell clients under `dnsapi/`.
  - Auth: Provider-specific API tokens, keys, usernames, passwords, or bearer tokens read from environment/config.
- Local or protocol DNS backends - RFC2136/nsupdate `dnsapi/dns_nsupdate.sh`, Knot `dnsapi/dns_knot.sh`, MaraDNS `dnsapi/dns_maradns.sh`, PowerDNS `dnsapi/dns_pdns.sh`, acme-dns `dnsapi/dns_acmedns.sh`, and AcmeProxy `dnsapi/dns_acmeproxy.sh`.
  - SDK/Client: Shell command/protocol wrappers under `dnsapi/`.
  - Auth: TSIG keys, basic auth, token auth, endpoint URLs, or local zone file paths.

**DNS Resolution Services:**
- DNS-over-HTTPS propagation checks - Cloudflare, Google, AliDNS, and DNSPod/Tencent DoH providers are selected by `DOH_USE` in `acme.sh`.
  - SDK/Client: Shared `_ns_lookup` DoH helpers in `acme.sh`.
  - Auth: None.

**Certificate Deployment Targets:**
- Local service reload hooks - Apache `deploy/apache.sh`, Nginx `deploy/nginx.sh`, HAProxy `deploy/haproxy.sh`, lighttpd `deploy/lighttpd.sh`, Dovecot `deploy/dovecot.sh`, Exim `deploy/exim4.sh`, OpenSSH `deploy/opensshd.sh`, vsftpd `deploy/vsftpd.sh`, Pure-FTPd `deploy/pureftpd.sh`, strongSwan `deploy/strongswan.sh`, and MySQL `deploy/mysqld.sh`.
  - SDK/Client: Local filesystem copies and shell reload commands.
  - Auth: Local OS permissions and optional deploy variables saved through `acme.sh`.
- Remote host and appliance hooks - SSH `deploy/ssh.sh`, RouterOS `deploy/routeros.sh`, Synology DSM `deploy/synology_dsm.sh`, TrueNAS REST `deploy/truenas.sh`, TrueNAS WebSocket `deploy/truenas_ws.sh`, Proxmox VE `deploy/proxmoxve.sh`, Proxmox Backup Server `deploy/proxmoxbs.sh`, UniFi `deploy/unifi.sh`, PAN-OS `deploy/panos.sh`, FRITZ!Box `deploy/fritzbox.sh`, Peplink `deploy/peplink.sh`, Ruckus `deploy/ruckus.sh`, OpenMediaVault `deploy/openmediavault.sh`, Windows RDP `deploy/windows_rdp.sh`, and Zyxel GS1900 `deploy/zyxel_gs1900.sh`.
  - SDK/Client: SSH/SCP, local commands, REST, XML, WebSocket, and appliance-specific shell clients.
  - Auth: Deploy-specific env vars such as `DEPLOY_SSH_*`, `SYNO_*`, `DEPLOY_TRUENAS_*`, `DEPLOY_PROXMOXVE_*`, `PANOS_*`, and appliance credentials.
- Cloud, CDN, and platform hooks - Alibaba CDN `deploy/ali_cdn.sh`, Alibaba DCDN `deploy/ali_dcdn.sh`, BytePlus ALB `deploy/byteplus_alb.sh`, CacheFly `deploy/cachefly.sh`, Edgio `deploy/edgio.sh`, Gcore CDN `deploy/gcore_cdn.sh`, GitLab Pages `deploy/gitlab.sh`, Netlify `deploy/netlify.sh`, Qiniu `deploy/qiniu.sh`, OpenStack Barbican `deploy/openstack.sh`, KeyHelp `deploy/keyhelp_api.sh`, Kong `deploy/kong.sh`, Docker `deploy/docker.sh`, Consul `deploy/consul.sh`, HashiCorp Vault REST `deploy/vault.sh`, and Vault CLI `deploy/vault_cli.sh`.
  - SDK/Client: Shell REST clients, Docker CLI/socket client, Consul/Vault CLI or HTTP API, and provider-specific signing.
  - Auth: Provider-specific env vars such as `ALIACCESSKEY`, `ALISECRETKEY`, `BYTEPLUS_ACCESS_KEY`, `BYTEPLUS_SECRET_KEY`, `CACHEFLY_TOKEN`, `EDGIO_CLIENT_ID`, `EDGIO_CLIENT_SECRET`, `GITLAB_TOKEN`, `NETLIFY_ACCESS_TOKEN`, `VAULT_TOKEN`, and `OS_*`.

**Notification Services:**
- Webhook and chat notifications - Slack `notify/slack.sh`, Slack App `notify/slack_app.sh`, Discord `notify/discord.sh`, Microsoft Teams `notify/teams.sh`, Telegram `notify/telegram.sh`, DingTalk `notify/dingtalk.sh`, Feishu `notify/feishu.sh`, Weixin Work `notify/weixin_work.sh`, Mattermost `notify/mattermost.sh`, Gotify `notify/gotify.sh`, ntfy `notify/ntfy.sh`, Bark `notify/bark.sh`, IFTTT `notify/ifttt.sh`, Pushbullet `notify/pushbullet.sh`, Pushover `notify/pushover.sh`, OpsGenie `notify/opsgenie.sh`, and CallMeBot WhatsApp `notify/callmebotWhatsApp.sh`.
  - SDK/Client: Shell HTTP clients through `_get` and `_post` in `acme.sh`.
  - Auth: Webhook URLs, bot tokens, API keys, and bearer tokens stored via account config.
- Email and message notifications - AWS SES `notify/aws_ses.sh`, Mailgun `notify/mailgun.sh`, Postmark `notify/postmark.sh`, SendGrid `notify/sendgrid.sh`, SMTP `notify/smtp.sh`, local mail `notify/mail.sh`, XMPP `notify/xmpp.sh`, and CQHTTP `notify/cqhttp.sh`.
  - SDK/Client: Shell HTTP clients, curl/Python SMTP support, local mail commands, and sendxmpp.
  - Auth: Service-specific env vars such as `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `MAILGUN_API_KEY`, `POSTMARK_TOKEN`, `SENDGRID_API_KEY`, `SMTP_*`, `MAIL_*`, and `XMPP_*`.

**Developer and CI Services:**
- GitHub Actions - Repository automation, test matrices, ShellCheck, shfmt, DNS tests, and Docker image publishing in `.github/workflows/*.yml`.
  - SDK/Client: GitHub Actions workflows and `actions/github-script@v6`.
  - Auth: GitHub-provided token plus workflow secrets referenced in `.github/workflows/*.yml`.
- Docker Hub - Multi-architecture image publishing for `neilpang/acme.sh` in `.github/workflows/dockerhub.yml`.
  - SDK/Client: Docker Buildx and `docker login`.
  - Auth: `DOCKER_USERNAME` and `DOCKER_PASSWORD` GitHub Actions secrets.
- External test harnesses - acmetest repository, Pebble, Step CA, vmactions VM actions, and anyvm Cloudflare tunnel actions in `.github/workflows/*.yml`.
  - SDK/Client: Git clone, Docker containers, GitHub Actions, and VM actions.
  - Auth: GitHub Actions environment and optional DNS provider secrets.

## Data Storage

**Databases:**
- Not detected; no database service or ORM exists in `acme.sh`, `dnsapi/`, `deploy/`, `notify/`, or configuration manifests.
  - Connection: Not applicable.
  - Client: Not applicable.

**File Storage:**
- Local filesystem is the primary store. `acme.sh` writes account configuration, CA data, domain configuration, keys, CSRs, certificates, logs, temporary files, and deployment settings under `LE_CONFIG_HOME`, `CERT_HOME`, and domain directories.
- Container storage is the `/acme.sh` volume declared in `Dockerfile`.
- Optional external secret/certificate stores are deploy targets, not primary application storage: Consul `deploy/consul.sh`, HashiCorp Vault REST `deploy/vault.sh`, Vault CLI `deploy/vault_cli.sh`, Docker containers `deploy/docker.sh`, and platform-specific deploy APIs under `deploy/`.

**Caching:**
- No external cache service detected.
- Local temporary files and HTTP headers are stored under `LE_TEMP_DIR` and `HTTP_HEADER` in `acme.sh`.
- DNS propagation checks use DoH providers in `acme.sh`, not a persistent cache.

## Authentication & Identity

**Auth Provider:**
- ACME account identity - Managed by local account keys and account configuration in `acme.sh`.
  - Implementation: Account keys, JWK thumbprints, nonce handling, and signed ACME requests are implemented in `acme.sh`.
- CA external account binding - Supported for CAs that require EAB, including ZeroSSL flow in `acme.sh`.
  - Implementation: EAB credentials and CA account data are stored in account config files handled by `acme.sh`.
- Provider identity - DNS, deploy, and notify modules use provider-specific API tokens, keys, credentials, OAuth bearer tokens, managed identities, instance roles, SSH keys, or local OS permissions.
  - Implementation: Module scripts under `dnsapi/`, `deploy/`, and `notify/` read env vars first, then persisted config through helper functions in `acme.sh`.

## Monitoring & Observability

**Error Tracking:**
- None detected as an external error tracking service.

**Logs:**
- Console logging, optional file logging, and optional syslog are implemented in `acme.sh` through `LOG_FILE`, `LOG_LEVEL`, and `SYS_LOG`.
- Renewal outcome notifications are sent through `NOTIFY_HOOK`, `NOTIFY_LEVEL`, `NOTIFY_MODE`, and `NOTIFY_SOURCE` in `acme.sh` and `notify/*.sh`.
- GitHub Actions logs provide CI observability for `.github/workflows/*.yml`.

## CI/CD & Deployment

**Hosting:**
- Docker image publishing targets Docker Hub image `neilpang/acme.sh` in `.github/workflows/dockerhub.yml`.
- Runtime deployment is user-managed via shell install, cron, Docker, or deploy hooks in `deploy/`.

**CI Pipeline:**
- GitHub Actions workflows in `.github/workflows/` run platform tests, DNS integration tests, ShellCheck, shfmt, Pebble strict tests, DockerHub builds, issue automation, PR checks, and wiki monitoring.

## Environment Configuration

**Required env vars:**
- Core runtime: `LE_WORKING_DIR`, `LE_CONFIG_HOME`, `ACCOUNT_CONF_PATH`, `CERT_HOME`, `ACCOUNT_EMAIL`, `DEFAULT_ACME_SERVER`, `ACME_OPENSSL_BIN`, `ACME_USE_WGET`, `CA_BUNDLE`, `CA_PATH`, `HTTPS_INSECURE`, `LOG_FILE`, `LOG_LEVEL`, `SYS_LOG`.
- DNS provider examples: `CF_Token`, `CF_Key`, `CF_Email`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AZUREDNS_SUBSCRIPTIONID`, `AZUREDNS_TENANTID`, `AZUREDNS_APPID`, `AZUREDNS_CLIENTSECRET`, `OCI_CLI_TENANCY`, `OCI_CLI_USER`, `OCI_CLI_REGION`, `OCI_CLI_KEY_FILE`, `OCI_CLI_KEY`, `DO_API_KEY`, `OVH_AK`, `OVH_AS`, `OVH_CK`, `NAMECHEAP_API_KEY`, `GANDI_LIVEDNS_KEY`, `HETZNER_TOKEN`, `VULTR_API_KEY`, `NETLIFY_ACCESS_TOKEN`, `VERCEL_TOKEN`.
- Deploy hook examples: `DEPLOY_SSH_*`, `DEPLOY_DOCKER_CONTAINER_*`, `VAULT_*`, `CONSUL_*`, `SYNO_*`, `DEPLOY_TRUENAS_*`, `DEPLOY_PROXMOXVE_*`, `PANOS_*`, `ALIACCESSKEY`, `ALISECRETKEY`, `BYTEPLUS_ACCESS_KEY`, `BYTEPLUS_SECRET_KEY`, `GITLAB_TOKEN`, `OS_*`.
- Notify hook examples: `SLACK_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`, `TEAMS_WEBHOOK_URL`, `TELEGRAM_BOT_APITOKEN`, `TELEGRAM_BOT_CHATID`, `DINGTALK_WEBHOOK`, `FEISHU_WEBHOOK`, `WEIXIN_WORK_WEBHOOK`, `GOTIFY_URL`, `GOTIFY_TOKEN`, `NTFY_URL`, `NTFY_TOPIC`, `OPSGENIE_API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `MAILGUN_API_KEY`, `POSTMARK_TOKEN`, `SENDGRID_API_KEY`, `SMTP_*`, `XMPP_*`.
- CI secrets: `DOCKER_USERNAME`, `DOCKER_PASSWORD`, DNS test secrets such as `TEST_DNS`, `TestingDomain`, `TokenName*`, and `TokenValue*` are referenced in `.github/workflows/DNS.yml` and `.github/workflows/dockerhub.yml`.

**Secrets location:**
- User runtime secrets are supplied as environment variables or persisted by `acme.sh` into account/domain config files under `LE_CONFIG_HOME`.
- Domain deploy settings are saved as `SAVED_*` entries in per-domain config files through `acme.sh`.
- GitHub Actions secrets are referenced in `.github/workflows/*.yml`.
- No `.env` files or secret files were detected during the repository scan.

## Webhooks & Callbacks

**Incoming:**
- None detected. The project is a CLI/client with no long-running inbound HTTP service in `acme.sh`.
- ACME challenge responses are outbound/temporary validation flows handled by webroot, standalone HTTP, standalone TLS-ALPN, DNS, DNS alias, stateless, and DNS persist modes in `acme.sh`.

**Outgoing:**
- ACME protocol requests to CA directory, nonce, account, order, authorization, finalize, certificate, revoke, and renewal info endpoints are implemented in `acme.sh`.
- DNS TXT record mutation requests are sent by provider modules under `dnsapi/`.
- Certificate deployment requests are sent by deploy hooks under `deploy/`.
- Notification webhooks and message API calls are sent by notify hooks under `notify/`.
- User-provided local commands run through `--pre-hook`, `--post-hook`, `--renew-hook`, `--reloadcmd`, `--deploy-hook`, and `--notify-hook` handling in `acme.sh`.

---

*Integration audit: 2026-05-14*
