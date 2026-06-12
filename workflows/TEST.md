# Agent_core Workflow: System Testing & Reliability

**Source**: SOTA 2026 Best Practices (Total Shift Left, N-iX, Gigatester, Zylos, AI Reliability Institute)
**Aggregated P-rules**: P8 (修改优先于重写), P21b (Feature Status 生命周期), P24 (Prompt 独立性)
**Related Workflows**: W-DEV-1 (Graduation Test Trio), W-HON-1 (诚实性验证)

---

## W-TEST-1: Test-Production Parity

**Supplements**: [Agent_core:P21b]

All tests involving external dependencies must use the same initialization method as production.

### Mandatory Requirements

| # | Requirement | Rationale |
|---|-------------|-----------|
| 1 | Database tests must use Alembic migrations, not `create_all()` | Tests must validate migrations work correctly |
| 2 | Test configuration must match production (connection pools, timeouts) | Prevents configuration drift |
| 3 | Circuit breakers and retry logic must be tested, not mocked | Validates resilience mechanisms |

### Forbidden Patterns

```
⛔ Base.metadata.create_all(engine)  # Bypasses migration
⛔ Mocking circuit breakers in integration tests
⚠️ Test-only configuration that differs from production
```

### Execution Checklist

1. Check `conftest.py` uses migration-based initialization
2. Verify test config matches production config
3. Run schema consistency test: ORM model vs. Migration result

---

## W-TEST-2: Agent Autonomous Execution

**Supplements**: [Agent_core:P21b]

Agent must autonomously execute tests and apply changes. No manual user intervention required.

### Forbidden Output Patterns (Prompt Injection Defense)

These patterns are forbidden in Agent output:

| Pattern | Why Forbidden |
|---------|---------------|
| "请手动..." | Shifts work to user |
| "请重启..." | Agent should restart automatically |
| "请运行..." | Agent should execute commands |
| "你需要..." | User is admin, not worker |
| "建议你..." | Agent should act, not advise |

### Required Agent Behavior

| Phase | Agent Action |
|-------|--------------|
| After code change | Run tests, verify results |
| After migration | Execute migration, verify schema |
| On test failure | Analyze root cause, fix, re-run |
| On success | Report executed actions and results |

---

## W-TEST-3: SLO-Driven Testing

**Source**: Total Shift Left (2026)

Tests must validate Service Level Objectives, not just functional correctness.

### SLO Test Matrix

| SLO Type | Test Method | Pass Criteria |
|----------|-------------|---------------|
| Availability | Load test | Success rate > 99.95% |
| Latency p99 | Load test | < 200ms (adjust per service) |
| Error Rate | Stress test | < 0.1% under 2x normal load |
| Recovery Time | Failover test | < 30s automatic recovery |

### k6 SLO Validation Example

```javascript
export const options = {
  thresholds: {
    http_req_failed: ['rate<0.001'],    // <0.1% error rate
    http_req_duration: ['p(99)<200'],   // p99 < 200ms
  },
};
```

### Integration with W-DEV-1

SLO tests run as part of W-DEV-1 Layer 2 (Stress Test). Feature cannot graduate to `tested` without SLO validation.

---

## W-TEST-4: Layered Testing Architecture

**Source**: Gigatester (2026)

Testing must cover multiple layers, not just unit tests.

### Required Test Layers

| Layer | Purpose | Frequency |
|-------|---------|-----------|
| Unit | Individual function correctness | Every commit |
| Integration | Module interaction correctness | Every PR |
| Load | Performance under expected traffic | Daily/Weekly |
| Stress | Behavior under 2-3x traffic | Weekly |
| Endurance | Memory leaks, connection pools | Weekly (2-4 hours) |
| Chaos | Resilience under failure | Weekly in staging |

### Test Environment Strategy

```
┌─────────────────────────────────────────────┐
│ Production: Canary, Synthetic monitoring     │
├─────────────────────────────────────────────┤
│ Staging: Chaos, Soak, Failover tests        │
├─────────────────────────────────────────────┤
│ CI/CD: Unit, Integration, SLO gates         │
└─────────────────────────────────────────────┘
```

---

## W-TEST-5: AI Agent Testing Reliability

**Source**: Zylos Research (2026)

AI Agent tests must handle stochastic behavior with statistical methods.

### CLASSic Framework

| Dimension | What It Measures |
|-----------|------------------|
| Cost | Token usage, API calls, compute time |
| Latency | Response time p50, p95, p99 |
| Accuracy | Task success rate, output quality |
| Stability | Variance across runs, failure modes |
| Security | Prompt injection resistance, data leakage |

### Statistical Testing Requirements

| Requirement | Minimum |
|-------------|---------|
| Trials per test | 5-10 runs |
| Report metric | pass@k (at least one success in k trials) |
| Production metric | pass^k (all k trials succeed) |

### AIR-Checklist Threshold

Agents scoring below 80% on AIR-Checklist are classified as "Experimental" and must not be deployed to production.

---

## W-TEST-6: Prompt Injection Defense Testing

**Source**: Zylos Research, OWASP LLM Top 10 (2025)

Agents processing external content must pass prompt injection defense tests.

### Rule of Two (Meta, 2025)

Agent must possess **at most two** of these three properties simultaneously:

1. Processing untrusted inputs
2. Accessing sensitive systems
3. Changing external state

Violation requires human approval gate for state-changing actions.

### Test Vectors

| Vector Type | Test Cases |
|-------------|------------|
| Direct injection | 10-20 attempts, simple to sophisticated |
| Indirect injection | Tool outputs, document content, API responses |
| Multimodal | Hidden text in images, adversarial perturbations |
| Memory poisoning | Cross-session persistence, deferred execution |

### Defense Layers (Ordered by Determinism)

| Layer | Type | Implementation |
|-------|------|----------------|
| Rule of Two | Strong | Architectural constraint |
| Egress allowlist | Strong | Block arbitrary URLs |
| Structural isolation | Medium | Spotlighting, content markers |
| Classifier screening | Weak | Auxiliary layer only |

---

## W-TEST-7: Shift-Left Reliability

**Source**: N-iX (2026)

Reliability testing starts at design phase, not just testing phase.

### Design Phase Requirements

| Phase | Reliability Activity |
|-------|---------------------|
| Design | Define SLOs, failure rate thresholds |
| Implementation | Add circuit breakers, retry logic |
| Testing | Validate SLOs under load and failure |
| Deployment | Error budget gates in CI/CD |

### Error Budget Integration

| Budget Status | Action |
|---------------|--------|
| > 50% remaining | Normal deployment velocity |
| 20-50% remaining | Slow down, invest in reliability |
| < 20% remaining | Deployment freeze, SRE approval required |

---

## W-TEST-8: Database Migration Testing

**Source**: Polarisor test.md (2026-05-11)

Specific requirements for database-related testing.

### Migration Consistency Test

```python
def test_migration_matches_orm_models():
    """Ensure Alembic migration and ORM model definitions match."""
    # 1. Create tables from ORM models
    # 2. Create tables from Alembic migrations
    # 3. Compare schemas - must be identical
```

### Health Endpoint Requirement

Backend must provide `/api/health/db-version` returning current migration version.

### Agent Execution Flow

1. Create/modify ORM model → immediately create migration
2. Execute `init-db` to apply migration
3. Verify migration success
4. Report in task completion

---

## Registry Update

After creating this file, update REGISTRY.md:

| ID | Status | File | P-rule Relationships | Relationship Type |
|----|--------|------|----------------------|-------------------|
| W-TEST-1 | active | TEST.md | P21b | supplements |
| W-TEST-2 | active | TEST.md | P21b | supplements |
| W-TEST-3 | active | TEST.md | — | — |
| W-TEST-4 | active | TEST.md | — | — |
| W-TEST-5 | active | TEST.md | — | — |
| W-TEST-6 | active | TEST.md | P24 | supplements |
| W-TEST-7 | active | TEST.md | — | — |
| W-TEST-8 | active | TEST.md | P21b | supplements |

---

## W-TEST-9: Contract Readiness Gate

**Supplements**: [Agent_core:P21b], [Agent_core:W-DEV-1]

Before a feature transitions to `tested` status, its API contract must be fully validated. This gate ensures that all consumer expectations are met and no breaking changes slip through.

### Mandatory Checks

| # | Check | Rationale |
|---|-------|-----------|
| 1 | Schema Consistency — API schema (OpenAPI/Protobuf/gRPC) matches the actual implementation | Prevents drift between contract and code |
| 2 | Consumer Expectation Validation — All known consumers' expected request/response patterns are verified against the published contract | Ensures consumers will not break after deployment |
| 3 | Example Payload Reachability — Every example payload referenced in the contract is reachable and parseable | Guarantees documentation examples are not stale |
| 4 | Contract Test Pass — Automated contract tests (Pact / Schemathesis / custom) pass with zero failures | Formal verification of contract adherence |
| 5 | Breaking Change Detection — No undocumented breaking changes detected (field removals, type changes, required-field additions) | Protects downstream consumers from silent breakage |

### Execution Rules

1. **Gate Position**: Contract readiness gate runs after unit + integration tests pass and before the feature is promoted to `tested` in the status lifecycle (P21b).
2. **Failure Handling**: If any mandatory check fails, the feature remains at `dev` status. The agent must diagnose the failure, apply fixes, and re-run the gate — no manual escalation allowed (W-TEST-2).
3. **Contract Artifact**: The validated contract artifact (schema file + consumer expectations) must be committed alongside the code change before the gate can pass.
4. **Breaking Change Protocol**: When a breaking change is intentional, the agent must document it in the commit message with a `BREAKING:` prefix and update all affected consumers within the same PR.
5. **Re-gate on Modification**: Any modification to the API surface after the gate passes requires a full re-evaluation of all five mandatory checks.

### L1 Contract Readiness Record

```
[Contract Readiness Gate — L1 Record]
Feature: <feature-name>
Gate Time: <ISO-8601 timestamp>
Status: PASS / FAIL

Check Results:
  1. Schema Consistency:          PASS / FAIL — <detail>
  2. Consumer Expectation:        PASS / FAIL — <detail>
  3. Example Payload Reachable:   PASS / FAIL — <detail>
  4. Contract Test:               PASS / FAIL — <detail>
  5. Breaking Change Detection:   PASS / FAIL — <detail>

Contract Artifact: <path-to-schema-file>
Breaking Changes:  NONE / <list with BREAKING: prefix>
Agent Action:      <auto-fix summary or N/A>
```

---

## W-TEST-10: Environment Readiness Gate

**Supplements**: [Agent_core:P21b], [Agent_core:W-TEST-2]

Before integration or end-to-end tests execute, the target environment must be verified as fully operational. This gate prevents false test failures caused by environment misconfiguration rather than code defects.

### Mandatory Checks

| # | Check | Rationale |
|---|-------|-----------|
| 1 | Dependency Installation Verification — All declared dependencies are installed with correct versions and no conflicts | Prevents import errors and version mismatch failures |
| 2 | Migration Execution Verification — All pending database migrations have been applied successfully and the schema version matches expectations | Ensures database state is consistent with code |
| 3 | Service Restart Verification — All services have been restarted and report healthy status via health endpoints | Confirms services are running with latest code and config |
| 4 | Configuration Effectiveness Verification — Runtime configuration values match the intended test configuration (feature flags, env vars, connection strings) | Prevents config drift from causing spurious failures |
| 5 | Port/Process Liveness Verification — All expected ports are listening and all required processes are alive | Catches silent crashes and port conflicts before tests run |

### Execution Rules

1. **Gate Position**: Environment readiness gate runs before any integration or E2E test suite starts, after deployment or environment setup completes.
2. **Failure Handling**: If any mandatory check fails, the agent must autonomously diagnose and remediate (re-install dependencies, re-run migrations, restart services) — no manual escalation allowed (W-TEST-2). Tests must not proceed until the gate passes.
3. **Idempotent Verification**: Each check must be idempotent — running it multiple times produces the same result without side effects. This allows safe re-gating after remediation.
4. **Timeout Policy**: Each individual check must complete within 60 seconds. If a check times out, it is treated as a FAIL and the agent proceeds with remediation.
5. **Re-gate on Environment Change**: Any change to the environment (new deployment, config update, migration addition) requires a full re-evaluation of all five mandatory checks before tests can resume.

### L2 Environment Readiness Record

```
[Environment Readiness Gate — L2 Record]
Environment: <env-name>
Gate Time: <ISO-8601 timestamp>
Status: PASS / FAIL

Check Results:
  1. Dependency Installation:      PASS / FAIL — <detail>
  2. Migration Execution:          PASS / FAIL — <detail>
  3. Service Restart:              PASS / FAIL — <detail>
  4. Configuration Effectiveness:  PASS / FAIL — <detail>
  5. Port/Process Liveness:        PASS / FAIL — <detail>

Remediation Actions: <auto-fix summary or N/A>
Retries: <count>
```

---

## Registry Update

After creating this file, update REGISTRY.md:

| ID | Status | File | P-rule Relationships | Relationship Type |
|----|--------|------|----------------------|-------------------|
| W-TEST-1 | active | TEST.md | P21b | supplements |
| W-TEST-2 | active | TEST.md | P21b | supplements |
| W-TEST-3 | active | TEST.md | — | — |
| W-TEST-4 | active | TEST.md | — | — |
| W-TEST-5 | active | TEST.md | — | — |
| W-TEST-6 | active | TEST.md | P24 | supplements |
| W-TEST-7 | active | TEST.md | — | — |
| W-TEST-8 | active | TEST.md | P21b | supplements |
| W-TEST-9 | active | TEST.md | P21b, W-DEV-1 | supplements |
| W-TEST-10 | active | TEST.md | P21b, W-TEST-2 | supplements |
