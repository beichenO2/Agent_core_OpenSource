# Polar Runtime Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a globally discoverable Codex Skill that enforces PolarPort and PolarProcess governance without mutating existing services.

**Architecture:** Keep Agent_core as the canonical source. Use a concise Skill for routing, a detailed reference for the runtime contract, and a read-only Bash auditor for deterministic checks. Install the Skill into Codex with a symlink after tests pass.

**Tech Stack:** Markdown Skills, Bash, curl, jq, Git, Codex Skill metadata.

---

### Task 1: Record the design and active SSoT state

**Files:**
- Create: `docs/superpowers/specs/2026-07-16-polar-runtime-governance-design.md`
- Modify: `polaris.json`

- [x] **Step 1: Write the approved design**

Record scope, alternatives, safety boundaries, components and acceptance criteria.

- [x] **Step 2: Mark implementation active in SSoT**

Add requirement `R5` with `polar_runtime_governance_skill` set to `in-progress` and `runtime_governance_audit` set to `planned`.

- [x] **Step 3: Validate JSON**

Run: `jq empty polaris.json`

Expected: exit code 0 with no output.

### Task 2: Build the read-only auditor with TDD

**Files:**
- Create: `.cursor/skills/polar-runtime-governance/tests/runtime-governance-audit.test.sh`
- Create: `.cursor/skills/polar-runtime-governance/scripts/runtime-governance-audit.sh`

- [x] **Step 1: Write failing tests**

Cover three observable behaviors using temporary fixtures and a fake `curl`: compliant project exits 0, project drift exits 1, unavailable authorities exit 2. Assert the script never sends a mutating HTTP method.

- [x] **Step 2: Run tests and verify RED**

Run: `bash .cursor/skills/polar-runtime-governance/tests/runtime-governance-audit.test.sh`

Expected: fail because `runtime-governance-audit.sh` does not exist.

- [x] **Step 3: Implement the minimal auditor**

Support `--project PATH` and `--ecosystem PATH`, use `POLARPORT_URL` and `POLARPROCESS_URL` overrides, perform health GETs, inspect project files, and emit exit codes 0/1/2. Never call a mutating endpoint.

- [x] **Step 4: Run tests and verify GREEN**

Run: `bash .cursor/skills/polar-runtime-governance/tests/runtime-governance-audit.test.sh`

Expected: all assertions pass.

### Task 3: Create the Codex Skill

**Files:**
- Create: `.cursor/skills/polar-runtime-governance/SKILL.md`
- Create: `.cursor/skills/polar-runtime-governance/references/runtime-contract.md`
- Create: `.cursor/skills/polar-runtime-governance/agents/openai.yaml`

- [x] **Step 1: Write the routing instructions**

Make the Skill trigger for Codex development, debugging, preview and deployment tasks that may start, stop, restart or expose a long-running service.

- [x] **Step 2: Write the runtime contract**

Specify authority roles, persistent/transient classification, preflight, onboarding, lifecycle actions, emergency boundaries, SSoT updates and completion checks.

- [x] **Step 3: Add UI metadata**

Set display name `Polar Runtime Governance`, a short description, a `$polar-runtime-governance` default prompt, and implicit invocation enabled.

- [x] **Step 4: Validate the Skill**

Run: `python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py .cursor/skills/polar-runtime-governance`

Expected: `Skill is valid!`

### Task 4: Validate safely and install globally

**Files:**
- Create symlink: `~/.codex/skills/polar-runtime-governance`
- Modify: `polaris.json`

- [x] **Step 1: Run repository checks**

Run:

```bash
jq empty polaris.json
bash .cursor/skills/polar-runtime-governance/tests/runtime-governance-audit.test.sh
npx vitest run tests/
```

Expected: JSON valid, auditor tests pass, existing 8 contract tests pass.

- [x] **Step 2: Run a real read-only ecosystem audit**

Run: `.cursor/skills/polar-runtime-governance/scripts/runtime-governance-audit.sh --ecosystem ~/Polarisor`

Expected: exit 0 when fully compliant or exit 1 with drift findings; never alter process or port state.

- [x] **Step 3: Mark SSoT tested and done**

Set both R5 features to `done`, set `test_status` to `passed`, and add evidence containing the validation commands and audit summary.

- [x] **Step 4: Install the Skill**

Create an idempotent symlink from `~/.codex/skills/polar-runtime-governance` to the Agent_core Skill directory and verify `SKILL.md` resolves.

- [x] **Step 5: Commit only task files**

Commit the design, plan, Skill, tests, auditor and SSoT update without including unrelated user changes.
