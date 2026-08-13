#!/usr/bin/env node
/**
 * 将 Agent_core/rules/ 打包为 PolarUI 可 fetch 的 rules-bundle.json（浏览器侧触发引擎）
 */
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const RULES = join(ROOT, 'Agent_core', 'rules')
const OUT = join(ROOT, 'PolarUI', 'public', 'rules-bundle.json')

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
  for (const f of readdirSync(dir).filter((x) => x.endsWith('.md'))) {
    const raw = readFileSync(join(dir, f), 'utf-8')
    const { meta, body } = parseFrontmatter(raw)
    const triggers = ((meta.triggers ?? meta.trigger) || [])
    if (!Array.isArray(triggers)) continue
    out.push({
      id: String(meta.id ?? f.replace(/\.md$/, '')),
      level,
      always: meta.always === true || meta.always_inject === true,
      triggers,
      priority: Number(meta.priority ?? 0),
      body,
    })
  }
  return out
}

const rules = [
  ...loadDir(join(RULES, 'norms'), 'norm'),
  ...loadDir(join(RULES, 'protocols'), 'protocol'),
]

mkdirSync(dirname(OUT), { recursive: true })
writeFileSync(
  OUT,
  JSON.stringify({ version: 1, generated_at: new Date().toISOString(), rules }, null, 2),
  'utf-8'
)
console.log(`OK: ${rules.length} rules → ${OUT}`)
