import type { RuleFile } from '../trigger-engine.js'

function humanizeTrigger(pattern: string): string {
  const latin = pattern.match(/[a-z]{2,}/gi)
  if (latin?.length) return latin.join(' ')
  return pattern.replace(/\.\*/g, ' ').trim()
}

/** Cursor description：协议层用触发词，规范层说明 always inject */
export function buildMdcDescription(rule: RuleFile): string {
  const rel = rule.path.replace(/^.*Agent_core\//, 'Agent_core/')
  const srcNote = `（由 ${rel} 生成）`

  if (rule.level === 'norm' || rule.always) {
    if (rule.id === 'norms/core') {
      return `Polarisor 核心规范 ${srcNote}，always inject`
    }
    return `Polarisor ${rule.id} ${srcNote}`
  }

  const hints = rule.triggerPatterns
    .map(humanizeTrigger)
    .filter(Boolean)
    .slice(0, 16)
    .join(', ')

  const title = rule.id.replace('protocols/', '').replace(/\//g, ' ')
  return `${title}: ${hints} ${srcNote}`.trim()
}

/** Cursor .mdc 规则片段 */
export function toMdc(rule: RuleFile): string {
  const description = buildMdcDescription(rule)
  const alwaysApply = rule.level === 'norm' || rule.always === true
  return `---
description: ${description}
alwaysApply: ${alwaysApply}
---

${rule.body}
`
}

export function mdcFilenameForRule(rule: RuleFile): string {
  if (rule.id.startsWith('protocols/')) {
    const name = rule.id.split('/')[1]
    return `polarisor-protocol-${name}.mdc`
  }
  return `polarisor-${rule.id.replace(/\//g, '-')}.mdc`
}

export function toMdcBatch(rules: RuleFile[]): Map<string, string> {
  const out = new Map<string, string>()
  for (const r of rules) {
    out.set(mdcFilenameForRule(r), toMdc(r))
  }
  return out
}
