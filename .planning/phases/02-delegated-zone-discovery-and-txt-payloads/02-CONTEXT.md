# Phase 2: Delegated Zone Discovery and TXT Payloads - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase changes `dnsapi/dns_oci.sh` so add/remove operations select the most
specific usable OCI DNS zone for the challenge FQDN, fall back to a usable parent
zone when appropriate, and build the same TXT record payload shape for add and
remove. It also expands the Phase 1 mocked shell harness to prove delegated
subzones, wildcard names, fallback, no-zone failures, factual debug output, and
small local JSON escaping fixes if the current payload construction is shown to
be brittle.

This phase does not implement resource-principal authentication or change auth
mode selection. It may make narrow lookup/signing plumbing adjustments only when
needed to expose zone lookup status/error signal or to avoid blocking known
resource-principal requirements in later phases.

</domain>

<decisions>
## Implementation Decisions

### Fallback Semantics
- **D-01:** Successful fallback from a delegated candidate to a parent zone stays quiet in normal output. Fallback details belong in debug output.
- **D-02:** When both delegated and parent zones are usable, tests should protect the public behavioral result, especially the final PATCH target/body, rather than locking exact internal probe order.
- **D-03:** Add and remove must use strictly symmetric selected-zone and record-owner computation.
- **D-04:** Introduce a shared private helper or equivalent shared computation so `dns_oci_add` and `dns_oci_rm` cannot drift in selected-zone/owner behavior.
- **D-05:** Prefer best-effort parent probing for headless automation: missing/no-id and malformed candidate responses can fall through to parent candidates.
- **D-06:** Access-denied or permission trouble should fail hard only when the OCI response exposes a clear authorization/permission signal. Ambiguous OCI `404` / `NotAuthorizedOrNotFound` / no-id results should be treated as candidate misses and keep probing.
- **D-07:** Debug output should be factual, not interpretive. For example, report that OCI returned a status for a candidate and the hook is trying the next candidate; do not claim "not found" or "unauthorized" unless OCI gives a clear non-ambiguous signal.

### TXT Payload Meaning
- **D-08:** Preserve the current OCI PATCH `domain` field shape unless implementation proves it wrong. Existing `dns_oci.sh` behavior works for current users, so "relative TXT payloads" means correct internal selected-zone/owner computation, not necessarily sending a relative `domain` value to OCI.
- **D-09:** Avoid broad variable renames for upstream mergeability. A small `dns_oci.sh` comment/glossary mapping acme.sh-style variables to OCI DNS terms is acceptable.
- **D-10:** Share selected-zone/owner computation only. Keep ADD and REMOVE JSON payload strings separate and familiar.
- **D-11:** Wildcards are in scope, especially delegated-subdomain wildcards, but they should not need special runtime branching beyond correct handling of the FQDN acme.sh supplies.
- **D-12:** Tests should prove both current apex wildcard behavior remains working and delegated wildcard behavior is fixed.
- **D-13:** Preserve current TTL behavior: ADD keeps `ttl: 30`; REMOVE keeps no TTL.
- **D-14:** If tests expose obvious JSON escaping gaps for realistic ACME TXT values or record domains, Phase 2 may add a minimal local fix. Broad shared JSON utility work is out of scope and should be deferred.

### Operator-Facing Messages
- **D-15:** Successful add/remove normal output should preserve current success text.
- **D-16:** PATCH failure permission hints should stay as-is.
- **D-17:** No-zone failure should keep the current error and add one short factual hint line: check that the zone exists and the user has permission to read it.
- **D-18:** Normal output remains quiet. Debug should contain factual probe/selection details useful to headless operators without leaking secrets.
- **D-19:** Logging level choices should follow acme.sh sensitivity conventions: `_debug2` may be appropriate for non-PII sensitive details such as zone OCIDs; `_debug3` may expose everything, including auth headers, and should not be used for routine zone probe facts unless deepest trace is truly needed.
- **D-20:** Auth-mode behavior stays untouched in Phase 2. Do not add resource-principal fallback here, but also do not choose a Phase 2 implementation that is knowingly incompatible with resource-principal work already understood for Phase 3/4.

### Mock Proof Depth
- **D-21:** Public add/remove behavior leads the proof. Use helper-level assertions only where public outputs are too indirect to prove selected-zone computation.
- **D-22:** Required zone/wildcard matrix: parent/apex, delegated subzone, fallback to parent, no-zone, apex wildcard, and delegated wildcard named cases.
- **D-23:** Include minimal debug assertions, but avoid brittle matching against OCI-controlled error-message phrasing. Assert stable facts controlled by the hook or harness, such as candidate zone, status, and fallback decision.
- **D-24:** Extend the mock signal enough to model status/body/id for lookup behavior, but keep the harness shell-level, focused, portable, and aligned with upstream `acmetest` comfort rather than building a mini OCI simulator.
- **D-25:** Escaping tests should be separate focused cases, not mixed into the delegated-zone matrix.
- **D-26:** No-zone and hard-fail authorization cases must explicitly prove no record mutation/PATCH is attempted.

### the agent's Discretion
The planner may choose exact private helper names and whether the helper returns
values or sets existing globals, as long as add/remove share the same
selected-zone and owner computation. The planner may choose the smallest clear
shape for local JSON escaping if tests justify it. The planner may make a
delicate, narrowly scoped lookup or `_signed_request` plumbing adjustment if
needed to expose status/error signal or avoid blocking known resource-principal
requirements, but must not perform a broad signing refactor or change auth-mode
selection in Phase 2.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and Milestone Scope
- `.planning/PROJECT.md` - Project scope, constraints, active requirements, and key decisions.
- `.planning/REQUIREMENTS.md` - Phase 2 requirements for ZONE-01, ZONE-02, ZONE-03, TXT-01, TXT-02, and TXT-03.
- `.planning/ROADMAP.md` - Phase 2 goal, success criteria, and planned work split.
- `.planning/STATE.md` - Current milestone and session state.
- `.planning/phases/01-oci-hook-characterization-and-test-harness/01-CONTEXT.md` - Phase 1 decisions for the mocked shell harness, proof matrix, and acmetest-shaped test style.

### Existing Code and Tests
- `dnsapi/dns_oci.sh` - OCI DNS provider implementation under change.
- `test/dns_oci_mock.sh` - Phase 1 mocked shell harness to extend for delegated zones, wildcards, fallback, status/body/id signal, escaping, and no-PATCH safety assertions.
- `.planning/codebase/STACK.md` - POSIX shell runtime, dependency, and verification constraints.
- `.planning/codebase/INTEGRATIONS.md` - DNS provider, OCI, GitHub Actions, and acmetest integration context.
- `.planning/codebase/ARCHITECTURE.md` - Hook plugin architecture, DNS-01 flow, logging, persistence, and provider boundary patterns.

### External OCI and Test References
- `https://github.com/acmesh-official/acmetest` - Upstream comfort level for shell-level, portable, focused test cases.
- `https://docs.oracle.com/en-us/iaas/Content/DNS/Tasks/record-add.htm` - OCI DNS record add behavior and payload context.
- `https://docs.oracle.com/en-us/iaas/tools/python/latest/api/dns/models/oci.dns.models.RecordDetails.html` - OCI record details model; `domain` is documented as the record domain/FQDN.
- `https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm` - OCI API error behavior, including ambiguous `NotAuthorizedOrNotFound` style failures.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `dnsapi/dns_oci.sh`: Public `dns_oci_add` and `dns_oci_rm` functions are the required behavioral entry points.
- `dnsapi/dns_oci.sh`: `_get_zone` already walks candidate labels and stops on the first lookup that returns an id; Phase 2 should tighten that behavior for delegated subzones and parent fallback.
- `dnsapi/dns_oci.sh`: `_signed_request "GET" ... "id"` is the current lookup boundary and may need a narrow way to expose status/error signal without changing auth selection.
- `test/dns_oci_mock.sh`: Existing shell harness stubs `_signed_request`, account config helpers, and logging helpers, and already contains parent, delegated, fallback, no-zone, symmetry, auth, and secure-debug characterization cases.

### Established Patterns
- Runtime hook changes must stay POSIX shell, use existing acme.sh helpers, and avoid adding SDKs or package managers.
- Upstream mergeability matters. Keep code close to maintainer conventions and avoid broad renames or abstractions when a small helper/comment would do.
- Sensitive data belongs in secure/debug-depth paths according to existing acme.sh logging conventions; normal output must not expose secrets or auth headers.
- Verification should be mocked shell-level proof plus focused static checks later, not live OCI credentials.

### Integration Points
- `dns_oci_add` and `dns_oci_rm` call selected-zone logic before PATCHing `/20180115/zones/${_domain}/records`.
- The selected-zone helper or equivalent shared computation must feed both ADD and REMOVE payload construction.
- The test harness should remain acmetest-shaped so useful cases can later be ported upstream.

</code_context>

<specifics>
## Specific Ideas

- Existing OCI PATCH payload shape works today and should be preserved unless proven wrong.
- Add a small glossary/comment in `dns_oci.sh` if useful to map acme.sh variable names to OCI DNS terminology without broad renames.
- For ambiguous fallback debug, prefer factual messages such as "OCI returned 404 for zone x.domain.com; trying domain.com" over editorial labels.
- Access denied is a hard failure when clearly visible, but OCI often collapses not-found and not-authorized into ambiguous 404-like responses, so best-effort fallback must handle that reality.
- The user occasionally sees odd acme.sh warnings that may come from random TXT value weirdness; minimal local JSON escaping fixes are welcome if tests reproduce a real issue.

</specifics>

<deferred>
## Deferred Ideas

- Broad shared JSON utility work across acme.sh belongs in a separate hardening effort if local OCI escaping is not enough.
- Resource-principal authentication and auth-mode fallback belong to later phases; Phase 2 should only avoid known incompatible choices.
- Live OCI DNS validation remains deferred to later UAT/final verification, not required for Phase 2 completion.

</deferred>

---

*Phase: 2-Delegated Zone Discovery and TXT Payloads*
*Context gathered: 2026-05-15*
