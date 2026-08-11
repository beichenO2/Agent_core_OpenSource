# Agent_core Adapters

Per-Agent-form adapter configurations that customize how Agent_core rules are applied.

Each Agent form (PolarCopilot, Cursor/Codex IDE agents, PolarFlow) may have different:
- Input/output channels (Hub Web UI, CLI, IDE chat)
- Available tools (Shell, MCP, Computer Use)
- Execution constraints (interactive vs. autonomous)

Adapter configs declare these differences so that shared W-rules can adjust their behavior accordingly. The P-rules themselves never change — adapters only affect how workflows execute.
