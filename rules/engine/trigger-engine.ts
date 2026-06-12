/**
 * 正则化规则触发引擎 — 宁可多触发不可漏触发
 */
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

export interface RuleFile {
  id: string
  level: 'norm' | 'protocol' | 'skill'
  always?: boolean
  triggers: RegExp[]
  triggerPatterns: string[]
  priority: number
  body: string
  path: string
}

const RULES_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

function patternToRegExp(pattern: string): RegExp {
  const normalized = String(pattern).replace(/\\\\/g, '\\')
  return new RegExp(normalized, 'i')
}
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
  if (!m) return { meta: {}, body: raw }
  const meta: Record<string, unknown> = {}
  const lines = m[1].split('\n')
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    const kv = line.match(/^(\w+):\s*(.*)$/)
    if (!kv) { i++; continue }
    const [, k, v] = kv
    if (v === '' && i + 1 < lines.length && lines[i + 1].trimStart().startsWith('- ')) {
      const arr: string[] = []
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
    else if (v.startsWith('[')) {
      try { meta[k] = JSON.parse(v.replace(/'/g, '"')) } catch { meta[k] = [] }
    } else meta[k] = v
    i++
  }
  return { meta, body: m[2].trim() }
}

function loadRules(dir: string, level: 'norm' | 'protocol' | 'skill'): RuleFile[] {
  const out: RuleFile[] = []
  for (const f of readdirSync(dir).filter(x => x.endsWith('.md') && x !== 'README.md')) {
    const path = join(dir, f)
    const raw = readFileSync(path, 'utf-8')
    const { meta, body } = parseFrontmatter(raw)
    const triggerPatterns = ((meta.triggers as string[]) ?? [])
    const triggers = triggerPatterns.map(t => patternToRegExp(t))
    out.push({
      id: String(meta.id ?? f),
      level,
      always: meta.always === true,
      triggers,
      triggerPatterns,
      priority: Number(meta.priority ?? 0),
      body,
      path,
    })
  }
  return out
}

let _cache: RuleFile[] | null = null

export function loadAllRules(): RuleFile[] {
  if (_cache) return _cache
  _cache = [
    ...loadRules(join(RULES_ROOT, 'norms'), 'norm'),
    ...loadRules(join(RULES_ROOT, 'protocols'), 'protocol'),
  ]
  return _cache
}

/** 根据用户输入文本选择应注入的规则（规范层全量 + 协议层按触发词） */
export function selectRules(inputText: string, opts?: { includeNorms?: boolean }): RuleFile[] {
  const includeNorms = opts?.includeNorms !== false
  const rules = loadAllRules()
  const selected: RuleFile[] = []

  for (const r of rules) {
    if (r.level === 'norm' && includeNorms) {
      if (r.always) selected.push(r)
      continue
    }
    if (r.level === 'protocol') {
      if (r.triggers.some(re => re.test(inputText))) selected.push(r)
    }
  }

  return selected.sort((a, b) => b.priority - a.priority)
}

export function rulesToPrompt(rules: RuleFile[]): string {
  return rules.map(r => `## ${r.id}\n\n${r.body}`).join('\n\n---\n\n')
}

let _skillCache: RuleFile[] | null = null

/** 技能层：显式调用，不参与 selectRules 自动匹配 */
export function loadSkillRules(): RuleFile[] {
  if (_skillCache) return _skillCache
  const skillsDir = join(RULES_ROOT, 'skills')
  try {
    _skillCache = loadRules(skillsDir, 'skill').filter((f) => f.id !== 'README')
  } catch {
    _skillCache = []
  }
  return _skillCache
}

export function selectSkill(skillId: string): RuleFile | null {
  const id = skillId.replace(/\.md$/, '')
  const base = id.includes('/') ? id.split('/').pop()! : id
  const candidates = [id, base, `skill-${id}`, `skill-${base}`]
  const skills = loadSkillRules()
  for (const c of candidates) {
    const hit = skills.find((r) => r.id === c || r.id === `skill-${c}`)
    if (hit) return hit
  }
  return null
}
