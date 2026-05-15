---
phase: 03
reviewers: [gemini, claude]
reviewed_at: 2026-05-15T04:05:04Z
plans_reviewed:
  - .planning/phases/03-authentication-selection-refactor/03-01-PLAN.md
  - .planning/phases/03-authentication-selection-refactor/03-02-PLAN.md
  - .planning/phases/03-authentication-selection-refactor/03-03-PLAN.md
---

# Cross-AI Plan Review - Phase 03

Phase 03: Authentication Selection Refactor

## Gemini Review

# Phase 03 Implementation Plan Review

Structured review of the implementation plans for **Phase 03: Authentication Selection Refactor**.

## Summary
The implementation plans for Phase 03 are exceptionally well-structured and rigorously aligned with the project's core mandates and architectural decisions. The strategy focuses on establishing a clean, global `_oci_auth_mode` selector that prioritizes existing API-key authentication while creating a safe, non-mutating boundary for the upcoming Resource Principal (RP) implementation. The use of a TDD-driven mocked shell harness ensures that complex authentication fallback scenarios—such as partial API-key configuration falling back to RP—are verified empirically before implementation.

## Strengths
- **Strict Adherence to Auth Precedence:** The plans correctly implement the "API-key wins" logic (D-13) by ensuring `_oci_config` is invoked and evaluated before any RP detection occurs.
- **Robust Boundary Management:** Implementing the RP "not-implemented" gate within `_signed_request` (D-09) provides a fail-safe that prevents any accidental OCI DNS mutations or invalid signing attempts during this transitional phase.
- **Side-Effect Safety:** The choice to use a private global variable for the auth mode instead of command substitution (D-03) is a vital architectural decision that prevents the loss of shell side effects observed in previous phases.
- **Comprehensive Diagnostic Coverage:** Plan 03-02 Task 3 specifically addresses the requirement (AUTH-03) to distinguish between API-key and RP configuration issues in error logs, improving operator visibility.
- **Persistence Integrity:** The plans include explicit assertions to ensure that ephemeral Resource Principal metadata (tokens, paths, versions) are never persisted to the durable `acme.sh` account configuration (D-11).

## Concerns
- **Confusion over Double Error Messages (Severity: LOW):** If `_signed_request` fails due to the RP gate, the caller (`_get_zone`) will likely continue its label-walking loop unless the error is treated as terminal. This might result in multiple "signing not implemented" messages followed by a final "Zone not found" error. While not functionally broken, it could be slightly noisy.
- **OCI CLI Config Persistence (Severity: LOW):** `_oci_config` modifies account configuration as it reads values. If it fails partially and then falls back to RP, it will have already saved whatever partial API-key fields it found. While this is consistent with existing `acme.sh` behavior, it's important to ensure this doesn't accidentally "lock in" a broken API-key config that overrides a future valid RP environment if the logic changes.

## Suggestions
- **Terminal RP Error:** Consider making the RP gate in `_signed_request` emit a specific signal that `_get_zone` can recognize to break the label-walking loop early, avoiding redundant error logs.
- **Mode Reset Verification:** In the `le_test_oci_rm_uses_auth_selector` smoke test, explicitly verify that the auth mode is reset at the start of the call to ensure that state from a previous (e.g., `add`) call in the same shell session doesn't leak.
- **Diagnostic Formatting:** Ensure that when falling back to RP after a partial API-key failure, the logs clearly indicate the transition (e.g., "API-key config incomplete; attempting resource principal fallback") to help users understand why one method was chosen over another.

## Risk Assessment: LOW
The risk is low because:
1. **No Breaking Changes:** The existing API-key path remains the primary and unchanged logic branch.
2. **Mocked Validation:** The comprehensive test suite in `test/dns_oci_mock.sh` covers all edge cases identified in the requirements (partial keys, fallback precedence, missing all auth).
3. **No Live Mutation:** The RP path is hard-gated to fail before any network requests or record mutations are attempted.
4. **POSIX Compliance:** The plan maintains the project's strict reliance on POSIX shell and existing `acme.sh` helpers.

**Conclusion:** The plans are ready for execution.

---

## Claude Review

# Cross-AI Plan Review: Phase 3 Authentication Selection Refactor

## Overall Summary

The three plans collectively form a tight, well-scoped TDD-driven refactor that introduces an explicit `_oci_auth_mode` selector boundary while preserving the existing API-key signing path verbatim. The plans correctly defer all RP signing to Phase 4 by gating `_signed_request`, and they enforce the no-persistence and stable-diagnostic rules from CONTEXT.md. The work is appropriately small (~3 tasks per plan, all touching only `dnsapi/dns_oci.sh` and `test/dns_oci_mock.sh`) and the validation strategy is credential-free. The main risks are subtle: a single ordering coupling between plans 01 and 02, an inspection-point question for `_oci_auth_mode` after `dns_oci_add` returns, and a small ambiguity in how `_oci_config` partial-failure short-circuits interact with persistence.

---

## Plan 03-01: Selector Boundary

### Strengths
- Clean RED-GREEN-REFACTOR sequencing: Task 1 writes failing public tests, Task 2 implements selector + gate, Task 3 adds the partial-key fallback case.
- Threat model directly maps to D-01/D-03/D-05; mitigations are testable.
- `_signed_request` guard at the top is the right architectural choice — single chokepoint for both GET zone lookup and PATCH.
- Test naming aligns with VALIDATION.md verification map exactly.

### Concerns

- **[MEDIUM] `_oci_auth_mode` inspection after public call.** Task 2 acceptance says "_oci_auth_mode=resource_principal" must be asserted, but `dns_oci_add` runs in the same shell as the test (sourced), so the global persists. That's fine — but Task 1 acceptance says the same assertion must hold *before implementation*, which is impossible (the variable doesn't exist yet). The RED test should fail on the PATCH-absent assertion or the boundary-substring assertion, not on the mode global. Worth clarifying that the mode-global assertion is a GREEN-state acceptance criterion, not a RED indicator.

- **[MEDIUM] `_oci_config` short-circuit hides partial-key state.** `_oci_config` currently returns `1` on the *first* missing field (e.g., missing TENANCY returns before evaluating USER/KEY). Task 3's partial-key test sets TENANCY+REGION present but USER/KEY absent — `_oci_config` will fail on USER and never emit a diagnostic about KEY. The diagnostic assertion "names missing key-based field names such as `OCI_CLI_USER` or `OCI_CLI_KEY`" is satisfiable by `OCI_CLI_USER` alone, which is OK, but the plan should explicitly note that early-return semantics are preserved (D-02) and the test only needs *one* missing field name.

- **[LOW] RP detector helper not named or fully specified.** Task 2 says "a new RP detector helper" but doesn't name it. CONTEXT.md uses `_oci_resource_principal_configured`; locking this name in the plan would help downstream Phase 4 work and reduce ambiguity in code review.

- **[LOW] Test isolation between cases.** `_oci_auth_mode` is a process global; if test N sets it to `resource_principal` and test N+1 doesn't reset it, leakage is possible. `_reset_oci_mocks` should unset `_oci_auth_mode` — worth adding to acceptance criteria.

### Suggestions
- Add to Task 2 action: "Extend `_reset_oci_mocks` to `unset _oci_auth_mode` (or assign empty) to prevent cross-test leakage."
- Name the RP detector helper explicitly (e.g., `_oci_resource_principal_configured`).
- Clarify Task 1's RED state: the failing assertion is the absence of the not-implemented diagnostic substring and the unexpected PATCH, not the mode global.

### Risk: **LOW-MEDIUM**

---

## Plan 03-02: Persistence Boundaries

### Strengths
- Excellent coverage of the four matrix corners (D-14): API-key success, partial-key fallback (from 03-01), missing-all-auth, API-key-wins.
- `le_test_oci_auth_oci_cli_config_file_primary` is a non-obvious gap-filler: it proves the config-file path still works post-refactor, which is a real regression risk.
- Persistence assertions are specific: name, value, and capture-file all checked.

### Concerns

- **[MEDIUM] `_readini` mock extension is non-trivial.** Current `_readini` mock just appends to `readini_keys` and returns nothing. Task 2 requires it to return real fixture values for tenancy/user/region/key_file. This is a meaningful mock change that could affect *every other test* that triggers `_readini` (currently none do, because env vars are always set in `_reset_oci_mocks`). The plan should clarify whether `_readini` becomes data-driven (lookup table) or whether the test installs a one-shot override. Risk of breaking existing characterization tests if global.

- **[MEDIUM] Saved-key assertion ambiguity for API-key-wins.** Task 1 asserts `OCI_CLI_KEY` saved when both API-key and RP env are complete. But `_reset_oci_mocks` already sets a multi-line `OCI_CLI_KEY` PEM block — the existing `le_test_oci_auth_api_key` test asserts the `-----BEGIN PRIVATE KEY-----` prefix. The new test should reuse that assertion shape to avoid drift.

- **[LOW] "If keeping one case is cleaner" is plan-level indecision.** Task 2 offers two options for the no-persistence test. Pick one in the plan, not at execution time, to keep VALIDATION.md's case list authoritative.

- **[LOW] `_clearaccountconf_mutable` for RP not addressed.** D-11 says no clears for RP either. Acceptance criteria check `MOCK_CLEARED_KEYS` for RP names — good. But the plan should explicitly say the implementation must not call `_clearaccountconf_mutable OCI_RESOURCE_PRINCIPAL_*` for any reason, even defensive cleanup.

### Suggestions
- Specify the `_readini` mock pattern: e.g., "extend `_readini` to read fixture values from a per-key associative store written by `_mock_oci_ini` before the test calls `dns_oci_add`."
- Resolve Task 2's "or extend" option in favor of a separate case (matches VALIDATION.md row for `le_test_oci_auth_resource_principal_does_not_persist`).
- Reuse the `-----BEGIN PRIVATE KEY-----` substring from existing `le_test_oci_auth_api_key` in the API-key-wins assertion.

### Risk: **MEDIUM** — the `_readini` mock change has potential blast radius.

---

## Plan 03-03: Matrix Closure + Static Gates

### Strengths
- Correct scoping: one remove smoke (not a full remove matrix) per D-15.
- Static gates use already-validated local versions; no dependency churn.
- Task 2's "repair any Phase 3 regression" framing matches the iterative reality of running the full suite at closeout.

### Concerns

- **[LOW] Task 2 lacks bounded repair budget.** "Repair any Phase 3 regression" could become open-ended. Tie to the standard `deviation_rules` 3-retry limit explicitly.

- **[LOW] shfmt `-i 2` may rewrite Phase 1/2 code.** If existing files have any spacing drift from prior commits, `shfmt -w` will modify them and the `git diff --exit-code` will fail on unrelated changes. The plan should say "stage only Phase-3-touched hunks" or commit any formatter-only fixups separately so they don't get attributed to Phase 3 logic.

- **[LOW] No assertion that `le_test_oci_auth_resource_principal_current_state` is removed or renamed.** PATTERNS.md says Phase 3 should "rename or supersede the current-state RP characterization" — but none of the three plans explicitly retires it. By Phase 3 end, that test asserts behavior (`unable to read OCI_CLI_TENANCY` error) that contradicts the new RP boundary diagnostic. It will either break or become misleading.

### Suggestions
- Add a Task 2 acceptance criterion: "`le_test_oci_auth_resource_principal_current_state` is removed or renamed to the new boundary case, and no fixture asserts the obsolete pre-fallback behavior."
- Note in Task 3 action: "If shfmt rewrites unrelated lines in Phase 1/2 code, commit those as a separate `style:` fixup, not as part of Phase 3 logic commits."

### Risk: **LOW**

---

## Cross-Plan Issues

- **[MEDIUM] Stranded test from Phase 1.** `le_test_oci_auth_resource_principal_current_state` (lines 577–600 of `test/dns_oci_mock.sh`) explicitly characterizes the *current* failure mode and even has a comment saying "Phase 3/4 must change this fixture." None of the three plans schedules its removal/replacement. It will likely fail in 03-01 Task 2 once `_oci_select_auth` lands (because RP env will now be detected and the failure path changes from "missing TENANCY" to "RP not implemented"). This should be explicitly handled in 03-01 Task 1 or Task 2.

- **[LOW] Sub-zone of D-08 verification.** D-08 says "verify the exact current OCI resource-principal environment variable shape against official Oracle docs before finalizing." Research already did this (2026-05-15 verification noted in RESEARCH.md). No plan task re-validates at execution time — fine, but should be acknowledged as accepted-via-research, not skipped.

- **[LOW] No explicit `_oci_auth_mode` declaration site.** D-03 mandates a private global; the plan should specify whether it's declared at file scope in `dns_oci.sh` (preferred) or implicitly via `_oci_select_auth`'s reset. File-scope declaration aids ShellCheck (avoids SC2154-style warnings).

---

## Phase Goal Achievement

The plans **do** achieve the stated Phase 3 goal:
- ✓ AUTH-01 (API-key primary): proved by `le_test_oci_auth_api_key`, `le_test_oci_auth_oci_cli_config_file_primary`, `le_test_oci_auth_api_key_wins_over_resource_principal`.
- ✓ AUTH-02 (RP only as fallback): proved by `le_test_oci_auth_partial_key_falls_back_to_resource_principal` and the API-key-wins case.
- ✓ AUTH-03 (distinct diagnostics): proved by `le_test_oci_auth_missing_reports_both_paths`.
- ✓ Phase 4 boundary preserved: `_signed_request` gate fails before any signing/PATCH on RP mode.

The plans also correctly **avoid** Phase 4 scope (no RPST parsing, no token signing, no Authorization header construction).

---

## Overall Risk: **LOW-MEDIUM**

**Justification:** Plans are well-scoped, decisions-aligned, and use established harness patterns. The main risks are (1) the stranded Phase 1 RP characterization test that will break when 03-01 lands, (2) the `_readini` mock extension's potential blast radius in 03-02, and (3) the unspecified handling of `_oci_auth_mode` reset across tests. All three are easily resolvable with small plan amendments before execution.

### Top 3 Pre-Execution Fixes
1. **Add explicit handling for `le_test_oci_auth_resource_principal_current_state`** in 03-01 (remove or rename).
2. **Specify the `_readini` mock extension pattern** in 03-02 Task 2 (per-key fixture store vs. one-shot override).
3. **Add `_oci_auth_mode` to `_reset_oci_mocks`** to prevent cross-test leakage.

---

## Consensus Summary

Both reviewers found the Phase 03 plans well scoped and aligned with the phase goal: preserve API-key authentication as the primary path while creating a non-mutating resource-principal fallback boundary for Phase 4. Neither reviewer raised any HIGH-severity concern. The review cycle's unresolved concerns are LOW and MEDIUM plan-quality refinements that should be folded into the next planning pass before execution.

### Agreed Strengths

- Existing API-key authentication remains the primary path, with explicit API-key-wins coverage when resource-principal environment variables are also present.
- The resource-principal path is correctly gated before signing or DNS mutation, keeping Phase 03 from implementing Phase 04 signing scope early.
- The plans use the mocked shell harness to prove fallback behavior, missing-auth diagnostics, no-persistence boundaries, and remove-path smoke coverage without requiring live OCI credentials.
- The refactor is constrained to `dnsapi/dns_oci.sh` and `test/dns_oci_mock.sh`, matching the milestone's POSIX shell and acme.sh helper constraints.

### Agreed Concerns

- **MEDIUM - Plan 03-01 should clarify `_oci_auth_mode` assertions and reset behavior.** Claude noted that `_oci_auth_mode=resource_principal` is a GREEN-state acceptance criterion, not a RED-state failure condition, and that `_reset_oci_mocks` should unset or reset the global to prevent cross-test leakage. Gemini separately suggested explicit mode-reset verification.
- **MEDIUM - Partial API-key fallback diagnostics need to preserve current `_oci_config` early-return behavior.** Claude noted that `_oci_config` fails on the first missing field, so tests should require at least one missing key-based field such as `OCI_CLI_USER` rather than implying every missing field must be reported. Gemini also flagged partial API-key persistence/fallback as a place where diagnostic clarity matters.
- **MEDIUM - Plan 03-02 should specify the `_readini` mock extension pattern.** Claude called out the config-file test's mock change as the highest-blast-radius item because a global `_readini` behavior change could affect existing characterization tests.
- **MEDIUM - The existing `le_test_oci_auth_resource_principal_current_state` fixture must be explicitly retired or replaced.** Claude identified this as a stranded Phase 1 characterization that will likely conflict with the new Phase 03 boundary once fallback detection is implemented.
- **LOW - Resource-principal gate errors may be noisy during zone label walking.** Gemini noted `_get_zone` could emit repeated RP-not-implemented messages and a final zone-not-found message unless the terminal gate is handled cleanly.

### Divergent Views

- Gemini assessed the overall phase risk as LOW and considered the plans ready for execution with minor polish.
- Claude assessed the overall phase risk as LOW-MEDIUM because the `_readini` mock extension, stranded current-state fixture, and auth-mode global reset are easy to fix but should be made explicit before execution.
- Gemini emphasized operator-facing diagnostic noise and persistence side effects; Claude emphasized test-harness precision and plan wording that could otherwise produce ambiguous implementation choices.

### Recommended Planning Updates

- Amend 03-01 to name the resource-principal detector helper, clarify RED vs GREEN assertions for `_oci_auth_mode`, reset `_oci_auth_mode` in `_reset_oci_mocks`, and explicitly remove or rename `le_test_oci_auth_resource_principal_current_state`.
- Amend 03-02 to use a separate no-persistence case, reuse the existing saved-key assertion shape for API-key-wins, state that no `_clearaccountconf_mutable OCI_RESOURCE_PRINCIPAL_*` calls are allowed, and define the `_readini` fixture pattern before execution.
- Amend 03-03 to bound regression repair by the standard deviation rules and keep formatter-only churn separate from Phase 03 logic changes if `shfmt -w` touches unrelated lines.

### Current HIGH Concerns

None.
