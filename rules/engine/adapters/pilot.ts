import { rulesToPrompt, type RuleFile } from '../trigger-engine.js'

/** PolarPilot daemon 附加 prompt */
export function toPilotDaemonPrompt(rules: RuleFile[]): string {
  return `[RULES]\n${rulesToPrompt(rules)}\n[/RULES]`
}
