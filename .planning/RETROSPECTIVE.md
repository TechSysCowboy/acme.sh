# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 - OCI DNS Subzones and Resource Principal Auth

**Shipped:** 2026-05-15
**Phases:** 5 | **Plans:** 16 | **Tasks:** 49

### What Was Built

- A credential-free POSIX shell harness for `dnsapi/dns_oci.sh` with 38 mocked
  OCI DNS cases.
- Longest accessible zone discovery for delegated subzones, including parent
  fallback and hard-fail authorization boundaries.
- Shared add/remove selected-record behavior with wildcard coverage and JSON
  escaping for TXT/domain payload values.
- API-key-primary authentication selection with resource-principal fallback and
  no resource-principal persistence.
- Resource-principal GET/PATCH signing with session-token key IDs, body headers,
  path-backed material refresh, passphrase support, and secure logging.
- Provider metadata and wiki-ready guidance covering auth order, policies,
  delegated subzones, secret handling, and v1 validation limits.

### What Worked

- Building the local mock harness first made later behavior changes fast and
  repeatable without OCI credentials.
- Keeping API-key auth primary throughout the milestone gave every refactor a
  clear compatibility check.
- Treating provider docs and metadata as tested behavior prevented stale Phase 3
  signing-boundary language from surviving into the release surface.
- The milestone audit caught stale validation metadata even though the runtime
  proof was already complete.

### What Was Inefficient

- Phase validation files were not updated as plans completed, which made the
  final Nyquist audit do cleanup after the fact.
- Early Phase 2/3 summaries carried shfmt availability as deferred evidence
  until later phases refreshed the toolchain and final gates.
- The archive workflow moves ignored planning artifacts, so completion requires
  explicit force-add staging to keep the repository trace honest.

### Patterns Established

- Use `test/dns_oci_mock.sh` as the durable OCI hook regression harness.
- Model OCI lookup ambiguity explicitly: ambiguous hidden-zone responses may
  fall back, while visible authz/permission signals stop mutation.
- Keep resource-principal material request-local and reload path-backed files
  per signed request.
- Treat live OCI validation as release qualification, not a prerequisite for the
  credential-free v1 readiness bar.

### Key Lessons

1. Put the shell harness in place before changing provider logic; it gives
   immediate proof for both compatibility and security boundaries.
2. Separate auth selection from signing before adding a new auth mechanism; the
   API-key-primary contract stays much easier to prove.
3. Documentation claims need executable coverage when they describe auth order,
   secret handling, or supported environment variables.
4. Archive workflows need post-command git verification because ignored planning
   files can otherwise look invisible to normal `git status`.

### Cost Observations

- Model mix: primarily Codex execution with GSD planning/checker artifacts.
- Sessions: multiple focused GSD phase sessions plus milestone audit/closeout.
- Notable: the upfront mock harness reduced later verification to seconds per
  focused case and kept live OCI credentials out of the v1 loop.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | Multiple focused GSD sessions | 5 | Mock-first provider development with explicit audit and archive closeout |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dependency Additions |
|-----------|-------|----------|---------------------------|
| v1.0 | 38 mocked OCI shell cases | Zone discovery, TXT payloads, auth selection, RP signing, docs metadata | POSIX shell harness, no runtime SDK/package manager |

### Top Lessons

1. Credential-free mock coverage is the right foundation for provider hook work
   that would otherwise require cloud credentials.
2. Security-sensitive docs should be verified against implementation and tests
   before release.
