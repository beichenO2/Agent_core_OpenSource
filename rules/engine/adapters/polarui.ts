import type { RuleFile } from '../trigger-engine.js'

/** PolarUI PromptInject 节点参数 */
export function toPromptInject(rule: RuleFile): {
  role: string
  constraints: string
  prior_knowledge: string
} {
  return {
    role: `规则注入: ${rule.id}`,
    constraints: rule.level === 'norm' ? '规范层：必须遵守' : '协议层：上下文相关',
    prior_knowledge: rule.body,
  }
}

export function mergeRulesForInject(rules: RuleFile[]): string {
  return rules.map(r => `[${r.id}]\n${r.body}`).join('\n\n')
}
