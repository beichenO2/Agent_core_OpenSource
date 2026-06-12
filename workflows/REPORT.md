# Agent_core Workflow: Progress Reporting

**Aggregated P-rules**: P19 (需求一致性报告), P21 (SSoT 同步强制), Proto-C (自动 Commit 流程)
**Legacy source**: `一般规范_legacy.md` §同步规范

---

## W-REP-1: Progress Report Format

**Supplements**: [Agent_core:P19]

Progress reports must include a 4-column table mapping features to their SSoT and code status, plus a judgment on each.

### Required Report Structure

Every task completion report must contain:

#### 1. Four-Column Status Table

| Feature | SSoT Status | Code Status | Judgment |
|---------|------------|-------------|----------|
| `[SSoT:ProjectName/R1/FeatureName]` | done / in-progress / blocked | implemented / partial / missing | ✅ / ⚠️ / ❌ |

Rules for each column:
- **Feature**: must use SSoT reference format `[SSoT:ProjectName/ReqId/FeatureName]` or `[Agent_core:Px]` rule ID — never bare text.
- **SSoT Status**: the current `status` field value from `polaris.json`.
- **Code Status**: factual assessment of the code — does the implementation exist, is it complete, does it work?
- **Judgment**: ✅ SSoT matches code, ⚠️ minor discrepancy, ❌ significant mismatch.

#### 2. Requirement Alignment Section

Per [Agent_core:P19], every report must also include:
1. Original requirement (user's exact words)
2. Original technical approach (user's words + Agent's understanding)
3. Actual technical approach used (deviation must be explained)
4. Reverse-engineering: what was actually implemented
5. Consistency judgment: ✅ fully consistent / ⚠️ reasonable improvement / ❌ deviation
6. Mental walkthrough: simulate user flow end-to-end, identify at least 1 risk or issue

### Documentation Sync (from 一般规范_legacy.md §同步规范)

1. **SSoT sync**: `polaris.json` is the single source of truth and ground truth for every project. It must track all improvements per [Agent_core:P21].
2. **Repository sync**: after completing a task, commit to the GitHub repository per [Agent_core:Proto-C]. Before committing, check diff to confirm no accidental deletions or overwrites of other Agents' work per [Agent_core:P22].

### Report Delivery

Reports are delivered via Hub Web informational prompt per [Agent_core:P11]. Three report formats are defined in `pc-solo-web`:
- Format A: task completion report
- Format B: research report
- Format C: project audit
