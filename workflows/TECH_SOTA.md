# Agent_core Workflow: Technology Age Thresholds

**Aggregated P-rules**: P14 (技术选型时效性), P23 (重要决策交叉验证)

---

## W-SOTA-1: Differentiated Technology Age Thresholds

**Refined-by**: [Agent_core:P14]

[Agent_core:P14] sets a blanket "1 year" freshness threshold for all technology. W-SOTA-1 refines this to differentiate between AI-related and other technology.

### Thresholds

| Category | Max Age | Examples |
|----------|---------|---------|
| AI-related tech | 1 year | LLM models, embedding models, training frameworks, Agent frameworks, RAG tooling, vector databases, prompt engineering libraries |
| All other tech | 2 years | Web frameworks, databases, build tools, CI/CD, testing frameworks, language runtimes |

### Alternative Criterion

Technology older than the threshold is still acceptable if:
- It is used in a **major company's actively-maintained open source project**
- That project has **commits within the last 3 months**

Example: SQLite (decades old) is used in countless active projects → acceptable. A vector DB library last updated 18 months ago with no major project using it → not acceptable for AI category.

### Classic Path Exemption

Long-term, universally used technology is exempt from age thresholds entirely:
- Git, SQLite, PostgreSQL, React, Linux, Python, Node.js, etc.
- These are "infrastructure" — their age is a feature, not a liability.

### Verification Requirement

Per [Agent_core:P23], technology recommendations must include cross-validation:
- Name, latest version, last update date, community activity level
- Multiple candidates → comparison table format
- Source URLs for all claims
