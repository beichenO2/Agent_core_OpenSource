# Agent_core Workflow: Test Honesty

**Aggregated P-rules**: P21b (Feature Status 生命周期), P21c (问题发现即回退), P7 (不确定性显式化)
**Legacy source**: `一般规范_legacy.md` §执行强度与真实性

---

## W-HON-1: Test Status Honesty

**Supplements**: [Agent_core:P21b], [Agent_core:P21c]

Every feature in `polaris.json` must have a `test_status` field that honestly reflects its verification state.

### test_status Enum

| Value | Meaning | Allowed with `status: "done"`? |
|-------|---------|-------------------------------|
| `passed` | All tests passed (W-DEV-1 graduation trio complete) | ✅ Yes — the only value that permits `done` |
| `failed` | One or more tests failed | ❌ No |
| `not_tested` | Testing has not been performed | ❌ No |
| `stub` | Implementation uses stubs, cannot be fully tested | ❌ No |

### Constraint

A feature with `status: "done"` **requires** `test_status: "passed"` — no exceptions.

```json
{
  "name": "user_login",
  "status": "done",
  "test_status": "passed"
}
```

### Mapping to W-REP-1

The judgment column in W-REP-1's status table must explicitly reflect `test_status`:

| test_status | W-REP-1 Judgment |
|-------------|-----------------|
| `passed` | ✅ |
| `failed` | ❌ (with failure details) |
| `not_tested` | ⚠️ (test pending) |
| `stub` | ❌ (stub implementation) |

### Honesty Rules (reinforced from 一般规範_legacy.md §执行強度与真实性)

Per [Agent_core:P7], uncertainty must be explicit. Applied to testing:

1. **Never claim "done" without test evidence.** If tests weren't run, `test_status` must say `not_tested`.
2. **Never mark a stub as `passed`.** If real implementation is missing, `test_status` must say `stub`.
3. **Bug discovery triggers immediate rollback** per [Agent_core:P21c]: change `status` to `blocked`, add `blockers` description, notify via Hub.
4. **Test results are immutable facts.** Changing `test_status` from `failed` to `passed` requires re-running and passing the tests — not just editing the JSON.

### Enforcement

- polaris.json must always be the source of truth for test status.
- W-HON-1 defines the schema; SOTAgent must implement PATCH validation to enforce this constraint (separate task: `SOTAgent_polaris_schema.md`).
