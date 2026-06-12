# Agent_core Workflow: Deletion & Archival

**Aggregated P-rules**: P13 (归档规则 — 6 维检查, ClawBin, 两阶段删除, 过时文件检测)
**Legacy source**: `一般规范_legacy.md` §删除旧实现

---

## W-DEL-1: Ecosystem-Wide Reference Verification Before Deletion

**Supplements**: [Agent_core:P13]

Before any delete/archive operation, execute a regex search verification across the entire Polarisor ecosystem to confirm no remaining references to the target.

### Procedure

1. **Identify deletion target**: file path, function name, class name, variable name, config key, or any other identifier being removed.
2. **Run ecosystem-wide search**:
   ```bash
   rg -l "<target_name>" ~/Polarisor/ --type-add 'code:*.{ts,js,py,md,json,sh,yaml,yml}' --type code
   ```
3. **Check git history** for recent additions referencing the target:
   ```bash
   git log -S "<target_name>" --oneline -10
   ```
4. **Evaluate each reference found**:
   - Active code reference → ⛔ cannot delete until reference is updated
   - Comment/doc reference → update or remove the reference
   - Test reference → update test to reflect new state
   - Archive/ClawBin reference → safe to ignore
5. **Only proceed with deletion** when zero active references remain outside archive paths.

### Rename Operations (from 一般规范_legacy.md §删除旧实现)

When deletion involves renaming, the regex search must cover all projects in the ecosystem, and all occurrences must be updated to the new name. Partial renaming (some files updated, others not) is a violation.

---

## W-DEL-2: Delete Empty Directory Shells

**Supplements**: [Agent_core:P13]

When deleting folder contents, the empty directory shell must also be deleted. No orphaned empty directories.

### Rules

1. After removing the last file from a directory, remove the directory itself.
2. Check for nested empty directories — removal must be recursive upward until a non-empty parent is reached.
3. Exception: directories containing only `.gitkeep` are considered intentionally empty (skeleton directories).
4. Document directories removed in the commit message or task token.

### Rationale (from 一般规范_legacy.md §删除旧实现)

Empty folders mislead subsequent Agents into thinking the directory serves a purpose. "如果清空了文件夹，文件夹本身也要删除，避免误会。"

---

## W-DEL-3: Post-Deletion Harmlessness Verification

**Supplements**: [Agent_core:P13]

Deletion is not complete until the minimum test suite for all affected areas passes.

### Procedure

1. **Identify affected areas**: list all modules, tests, and integrations that referenced the deleted target (from W-DEL-1's search results).
2. **Run affected tests**: execute the test suite for each affected area.
3. **Verify no regressions**: compare test results before and after deletion.
4. **Verify documentation sync** (from 一般规范_legacy.md §删除旧实现): all documentation referencing the deleted target must be updated or removed. "文档中的相关内容必须同步清除。"
5. **Record results**: write test results in the task token or commit message.

### Deletion Judgment Standard (from 一般规范_legacy.md §删除旧实现)

The sole criterion for deletion is "还有用吗" (is it still useful?). Do not use heuristic deletion judgment. Specifically:
- Build artifacts and intermediate results → generally safe to delete (can be regenerated)
- Code logic that runs correctly and has no replacement → ⛔ must not delete
- The judgment is functional, not aesthetic — "ugly but working" code cannot be deleted without a replacement
