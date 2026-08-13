import { rulesToPrompt, type RuleFile } from '../trigger-engine.js'

/** PolarClaw system prompt 段落 */
export function toClawSystemPrompt(rules: RuleFile[]): string {
  return `# Injected Rules\n\n${rulesToPrompt(rules)}`
}
