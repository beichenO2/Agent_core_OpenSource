# Agent_core Workflow: Development & Testing

**Aggregated P-rules**: P4a (新增即是重构), P7 (不确定性显式化), P8 (修改优先于重写), P21b (Feature Status 生命周期)
**Legacy source**: `一般规范_legacy.md` §执行强度与真实性, §新增功能, §重构, §Debug

---

## W-DEV-1: Graduation Test Trio

**Supplements**: [Agent_core:P21b]

Every feature must pass three layers of testing before its `status` can advance from `in-progress` to `tested`. [Agent_core:P21b]'s 5-step verification chain is the prerequisite gate; W-DEV-1 defines the graduation criteria that follow.

### Three Required Tests

| # | Test Layer | What It Validates | Pass Criteria |
|---|-----------|-------------------|---------------|
| 1 | Full-chain integration | Main workflow runs end-to-end across all touched modules/projects | All user-facing workflows complete without error; no stub substitutions |
| 2 | Stress test | System stability under high concurrency, high load, or long runtime | No significant performance degradation, no resource leaks (memory, file descriptors, connections) |
| 3 | Attack test | Robustness against abnormal input, boundary conditions, malicious calls | No crashes, no silent data corruption, no exploitable error paths |

### Execution Rules

1. Tests execute **in order** (integration → stress → attack). Each layer must pass before proceeding.
2. Test results are recorded in the task token's "测试记录" section with: scope, method, result, failures, and resolution.
3. Any test failure → feature `test_status` must be set to `failed` per [Agent_core:W-HON-1]. The feature `status` stays `in-progress` or moves to `blocked`.
4. All three tests passed → `test_status: "passed"`, `status` may advance to `tested`.

### Integration with P21b Verification Chain

[Agent_core:P21b] requires 5 pre-checks before a feature reaches `tested`:
1. Compile / type check
2. Single-file test
3. Cross-module integration test
4. Boundary test
5. Regression confirmation

W-DEV-1's trio operates **after** these 5 checks pass. The graduation trio validates the feature at system level, not just module level.

---

## W-DEV-2: No Stub Implementations

**Overrides**: tqsdk stubs practice

Stub implementations are forbidden in main code paths. Real logic must be implemented, tested, and verified.

### Policy

| Location | Stubs Allowed? | Rationale |
|----------|---------------|-----------|
| `tests/**` | Yes | Test doubles are legitimate testing patterns |
| `*.stub.{ts,py,js}` | Yes | Explicitly marked stub files for development scaffolding |
| All other paths | **No** | Main code must contain real implementations |

### Rules

1. Full-chain integration tests (W-DEV-1 layer 1) **must not use stubs**. If a dependency isn't available, the test should fail rather than silently pass with a stub.
2. Hardcoded return values, placeholder logic, or TODO-marked functions in production paths are treated as stub violations.
3. If a feature cannot be fully implemented due to external dependencies, its `status` must remain `in-progress` and `test_status` must be `stub` — never `done`.

### Legacy Constraints (from 一般规范_legacy.md §执行强度与真实性)

Per [Agent_core:P4a] and the legacy execution intensity standard:

- Work intensity does not scale down with task size. Once execution begins, real logic must be completed, verified, and synced.
- Reverting design scope, shrinking goals, or writing interface-only code because "it's too much work" is forbidden.
- Every addition is a local refactoring of existing structure per [Agent_core:P4a] — check and reorganize touched logic, tests, docs, and old entry points.
- Minimal patches without structural integration reasoning are forbidden, regardless of change size.

### New Feature Development (from 一般规范_legacy.md §新增功能)

- Must be real implementations, not surface-level changes.
- Must include mental walkthrough: does this affect other ecosystem integrations? Does it truly meet the stated requirement?
- Must design tests with test-first / TDD approach. Local-only testing is insufficient.
- Tech choices must use current SOTA methods per [Agent_core:P14] / [Agent_core:W-SOTA-1].
- New features are refactoring events per [Agent_core:P4a] — reorganize related existing logic.

### Refactoring (from 一般规范_legacy.md §重构)

- Goal: more coherent code relationships, clearer responsibilities, less redundancy — not just file moves or renames.
- Must state whether behavior changes.
- Outdated implementations, old entry points, old docs, and empty directories must be cleaned.
- Post-refactor verification must prove new structure covers original capabilities.

### Debug (from 一般规范_legacy.md §Debug)

- Test-first: use tests to locate and verify fixes.
- Minimal change principle per [Agent_core:P8] — do not modify unrelated code.
- Problematic code must be fully removed. Multi-file cleanup follows [Agent_core:W-DEL-1/2/3].
