# Phase 2: Delegated Zone Discovery and TXT Payloads - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 2-Delegated Zone Discovery and TXT Payloads
**Areas discussed:** Fallback semantics, TXT payload meaning, Operator-facing messages, Mock proof depth

---

## Fallback Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Debug-only fallback note | Normal success stays terse; debug logs show fallback details. | yes |
| Success names selected zone | User-facing success includes selected parent/delegated zone. | |
| Warning-style notice | User-facing output explicitly says fallback was used. | |

**User's choice:** Debug-only fallback note.
**Notes:** Normal renewal output should stay quiet for headless automation.

| Option | Description | Selected |
|--------|-------------|----------|
| Empty lookup only | Only no id falls through. | |
| Empty or permission-denied | Missing access behaves like not found. | |
| Refined rule | Missing/no-id/malformed candidate responses fall through; visible access denied fails hard. | yes |

**User's choice:** Refined rule.
**Notes:** OCI often collapses not-found and not-authorized into 404-like responses. Fall back for ambiguous cases, but fail hard when authorization trouble is clearly visible from response text/code.

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit invariant | Tests assert exact candidate probe order. | |
| Behavioral only | Tests assert final PATCH target/body rather than internal order. | yes |
| You decide | Planner chooses based on brittleness. | |

**User's choice:** Behavioral only.
**Notes:** Protect the delegated-zone result without making tests brittle against internal iteration details.

| Option | Description | Selected |
|--------|-------------|----------|
| Selected-zone summary | Debug final selected zone and record owner. | yes |
| Candidate trail | Debug each candidate and outcome. | |
| Minimal current logs | Avoid new structured debug. | |

**User's choice:** Selected-zone summary.
**Notes:** Later clarified that factual candidate/status/fallback debug is useful when available, but should not editorialize OCI ambiguity.

| Option | Description | Selected |
|--------|-------------|----------|
| Current-style concise failure | Keep only the existing no-zone error. | |
| Add factual hint | Add one hint to check zone existence and permissions. | yes |
| Detailed candidate failure | Include each attempted candidate in normal output. | |

**User's choice:** Add factual hint.
**Notes:** The final correction was to use the hint, while keeping detailed probe facts in debug.

| Option | Description | Selected |
|--------|-------------|----------|
| Strict symmetry | Add and remove use the same selected-zone logic. | yes |
| Remove may be looser | Remove can tolerate best-effort differences. | |
| You decide | Planner chooses. | |

**User's choice:** Strict symmetry.
**Notes:** Add/remove must compute the same selected zone and TXT owner.

---

## TXT Payload Meaning

| Option | Description | Selected |
|--------|-------------|----------|
| Internal owner is relative, JSON stays FQDN | Compute selected-zone-relative owner internally, but preserve OCI API payload shape. | yes |
| Send relative JSON domain | Change OCI PATCH `domain` to the relative owner only. | |
| Probe and prove | Planner chooses after docs/current behavior inspection. | |

**User's choice:** Maintain current `dns_oci.sh` behavior.
**Notes:** Current OCI payload shape works, so preserve it unless proven wrong.

| Option | Description | Selected |
|--------|-------------|----------|
| Clarify internals by rename | Rename variables for selected zone and owner. | |
| Minimal rename | Keep existing variable style. | |
| Header/footer glossary | Explain variable-to-OCI terminology mapping without broad renames. | yes |

**User's choice:** Header/footer glossary.
**Notes:** Upstream maintainer conventions matter; broad renames may hurt mergeability.

| Option | Description | Selected |
|--------|-------------|----------|
| Shared computation only | Share selected-zone/owner calculation; keep payload strings separate. | yes |
| Shared payload builder | Build JSON item through one helper. | |
| You decide | Planner chooses. | |

**User's choice:** Shared computation only.
**Notes:** Keep ADD/REMOVE payload bodies familiar.

| Option | Description | Selected |
|--------|-------------|----------|
| No wildcard branch | Just handle the FQDN passed by acme.sh. | |
| Wildcard-aware comments/tests | No runtime branch, but name wildcard cases. | |
| Apex and delegated wildcard proof | Prove apex wildcard still works and delegated wildcard is fixed. | yes |

**User's choice:** Apex and delegated wildcard proof.
**Notes:** Wildcards are a primary motivation for the side project, but should not need special runtime logic.

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve current ADD ttl 30 | Keep ADD `ttl: 30` and no TTL on REMOVE. | yes |
| Normalize TTL handling | Change TTL behavior for consistency. | |
| You decide | Planner touches TTL only if needed. | |

**User's choice:** Preserve current TTL behavior.

| Option | Description | Selected |
|--------|-------------|----------|
| Leave JSON escaping unchanged | Stay scoped to zone/owner computation. | |
| Fix obvious escaping gaps if found | Add minimal local escaping fixes when tests expose real brittleness. | yes |
| You decide | Planner judges current string construction. | |

**User's choice:** Fix obvious escaping gaps if found.
**Notes:** User has occasionally seen odd acme.sh warnings that may be random TXT value weirdness. Escaping fixes must stay minimal and test-driven.

---

## Operator-Facing Messages

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve current success text | Keep current `Success: added/removed TXT record for <fqdn>.` | yes |
| Mention selected zone | Include selected zone in normal success output. | |
| You decide | Planner keeps current text unless style suggests otherwise. | |

**User's choice:** Preserve current success text.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep existing PATCH failure hint | Current permission hints remain. | yes |
| Add selected-zone context | Include selected zone or record FQDN in failure hint. | |
| You decide | Planner adjusts only if needed. | |

**User's choice:** Keep existing PATCH failure hint.

| Option | Description | Selected |
|--------|-------------|----------|
| One extra hint line | Current no-zone error plus a check-zone-existence-and-permissions hint. | yes |
| Rewrite single line | Replace current no-zone error with a new combined message. | |
| You decide | Planner chooses closest acme.sh style. | |

**User's choice:** One extra hint line.

| Option | Description | Selected |
|--------|-------------|----------|
| Use `_debug` for summary only | Ordinary debug carries selected-zone summary. | |
| Use `_debug2`/`_debug3` for probe facts | Deeper levels carry candidate details. | |
| Sensitivity-based discretion | Planner chooses level using acme.sh sensitivity rules. | yes |

**User's choice:** Sensitivity-based discretion.
**Notes:** `_debug2` is for non-PII but sensitive data such as zone OCIDs. `_debug3` can expose everything including auth headers; use accordingly.

| Option | Description | Selected |
|--------|-------------|----------|
| Leave auth selection untouched | Do not change auth-mode behavior in Phase 2. | yes |
| Allow tiny future-proofing | No behavior change, but harmless plumbing can avoid blocking Phase 3/4. | |
| You decide | Planner chooses. | |

**User's choice:** Leave auth selection untouched.
**Notes:** Do not be adversarial to known resource-principal needs. If RP requires X and possible Phase 2 choice Y would block it, do not implement Y.

---

## Mock Proof Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Public behavior only | Assert PATCH target/body/logging outcomes through public add/remove. | |
| Public plus helper state | Also assert helper globals or outputs. | |
| Public first, helper if needed | Use helper assertions only where public behavior is too indirect. | yes |

**User's choice:** Public first, helper if needed.

| Option | Description | Selected |
|--------|-------------|----------|
| Core matrix | Parent/apex, delegated subzone, fallback, no-zone. | |
| Wildcard-explicit matrix | Core matrix plus apex wildcard and delegated wildcard cases. | yes |
| Full edge matrix | Include multi-label, trailing dots, malformed names. | |

**User's choice:** Wildcard-explicit matrix.

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal debug assertions | Assert selected-zone summary and factual fallback/status where available. | yes |
| Avoid debug text brittleness | Assert only behavior and normal errors. | |
| You decide | Planner asserts only drift-prone debug contracts. | |

**User's choice:** Minimal debug assertions.
**Notes:** Do not fail on exact OCI-controlled error-message phrasing.

| Option | Description | Selected |
|--------|-------------|----------|
| Extend mock signal | Model status/body/id enough to prove fallback/authz/debug behavior. | yes |
| Keep id-only mock | Preserve current `_signed_request "id"` return shape only. | |
| You decide | Planner extends only if needed. | |

**User's choice:** Extend mock signal.
**Notes:** Do not overbuild; refer to upstream `acmetest` for testing comfort.

| Option | Description | Selected |
|--------|-------------|----------|
| Separate focused cases | Keep escaping tests separate from zone matrix. | yes |
| Fold into matrix | Combine escaping with delegated/wildcard cases. | |
| You decide | Planner keeps tests simplest. | |

**User's choice:** Separate focused cases.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, required | No-zone and authz hard-fail cases must prove no PATCH. | yes |
| No, implied by failure | Function failure is enough. | |
| You decide | Planner adds where easy. | |

**User's choice:** Yes, required.

---

## the agent's Discretion

- Exact private helper naming and whether it returns values or sets existing globals.
- Exact `_debug`/`_debug2` level placement, provided sensitivity rules are followed.
- Exact local JSON escaping helper shape, if a minimal escaping fix is needed.
- Narrow lookup or `_signed_request` plumbing shape, if status/error signal is needed without changing auth-mode behavior.

## Deferred Ideas

- Broad shared JSON utility work across acme.sh.
- Resource-principal authentication and auth-mode fallback implementation.
- Live OCI DNS validation.
