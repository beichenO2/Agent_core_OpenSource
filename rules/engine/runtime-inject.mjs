/**
 * 纯 JS 规则触发引擎 — PolarClaw / PolarPilot / CLI 运行时消费
 * （不依赖 .ts 编译；与 trigger-engine.ts 语义对齐）
 */
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const RULES_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

/** YAML 中 \\b 常被存成字面量 \\\\b，归一化后再编译 */
function patternToRegExp(pattern) {
  const normalized = String(pattern).replace(/\\\\/g, '\\')
  return new RegExp(normalized, 'i')
}

function parseFrontmatter(raw) {
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
  if (!m) return { meta: {}, body: raw.trim() }
  const meta = {}
  const lines = m[1].split('\n')
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    const kv = line.match(/^(\w+):\s*(.*)$/)
    if (!kv) {
      i++
      continue
    }
    const [, k, v] = kv
    if (v === '' && i + 1 < lines.length && lines[i + 1].trimStart().startsWith('- ')) {
      const arr = []
      i++
      while (i < lines.length && /^\s*-\s+/.test(lines[i])) {
        arr.push(lines[i].replace(/^\s*-\s+/, '').replace(/^["']|["']$/g, ''))
        i++
      }
      meta[k] = arr
      continue
    }
    if (v === 'true') meta[k] = true
    else if (v === 'false') meta[k] = false
    else if (/^\d+$/.test(v)) meta[k] = Number(v)
    else meta[k] = v
    i++
  }
  return { meta, body: m[2].trim() }
}

function loadDir(dir, level) {
  const out = []
  let files = []
  try {
    files = readdirSync(dir).filter((x) => x.endsWith('.md') && x !== 'README.md')
  } catch {
    return out
  }
  for (const f of files) {
    const raw = readFileSync(join(dir, f), 'utf-8')
    const { meta, body } = parseFrontmatter(raw)
    const triggerPatterns = (meta.triggers ?? [])
    const triggers = Array.isArray(triggerPatterns)
      ? triggerPatterns.map((t) => patternToRegExp(t))
      : []
    out.push({
      id: String(meta.id ?? f.replace(/\.md$/, '')),
      level,
      always: meta.always === true || meta.always_inject === true,
      triggers,
      triggerPatterns: Array.isArray(triggerPatterns) ? triggerPatterns.map(String) : [],
      priority: Number(meta.priority ?? 0),
      body,
      path: join(dir, f),
    })
  }
  return out
}

let _cache = null

export function loadAllRules() {
  if (_cache) return _cache
  _cache = [
    ...loadDir(join(RULES_ROOT, 'norms'), 'norm'),
    ...loadDir(join(RULES_ROOT, 'protocols'), 'protocol'),
  ]
  return _cache
}

export function loadSkillRules() {
  return loadDir(join(RULES_ROOT, 'skills'), 'skill')
}

export function selectRules(inputText, opts = {}) {
  const includeNorms = opts.includeNorms !== false
  const rules = loadAllRules()
  const selected = []
  for (const r of rules) {
    if (r.level === 'norm' && includeNorms) {
      if (r.always) selected.push(r)
      continue
    }
    if (r.level === 'protocol') {
      if (r.triggers.some((re) => re.test(inputText))) selected.push(r)
    }
  }
  return selected.sort((a, b) => b.priority - a.priority)
}

export function selectSkill(skillId) {
  const id = String(skillId).replace(/\.md$/, '')
  const base = id.includes('/') ? id.split('/').pop() : id
  const candidates = [id, base, `skill-${id}`, `skill-${base}`].filter(Boolean)
  const skills = loadSkillRules()
  for (const c of candidates) {
    const hit = skills.find((r) => r.id === c || r.id === `skill-${c}`)
    if (hit) return hit
  }
  return null
}

export function rulesToPrompt(rules) {
  return rules.map((r) => `## ${r.id}\n\n${r.body}`).join('\n\n---\n\n')
}

export function buildClawAppend(inputText) {
  const rules = selectRules(inputText)
  if (!rules.length) return ''
  return `# Injected Rules\n\n${rulesToPrompt(rules)}`
}

export function buildPilotSystem(inputText, taskPrompt = '') {
  const rules = selectRules(inputText)
  const block = rules.length ? rulesToPrompt(rules) : ''
  if (!block && !taskPrompt) return ''
  const parts = []
  if (block) parts.push(`[RULES]\n${block}\n[/RULES]`)
  if (taskPrompt) parts.push(taskPrompt)
  return parts.join('\n\n')
}

export function buildSkillPrompt(skillId) {
  const skill = selectSkill(skillId)
  if (!skill) return null
  return `## Skill: ${skill.id}\n\n${skill.body}`
}
