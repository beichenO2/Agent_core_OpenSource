#!/usr/bin/env npx tsx
/**
 * sync-cursor-rules.ts — 从 Agent_core/rules/ 重新生成 .cursor/rules/*.mdc
 *
 * 用法：npx tsx Agent_core/scripts/sync-cursor-rules.ts
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'
import { loadAllRules } from '../rules/engine/trigger-engine.js'
import { toMdcBatch, mdcFilenameForRule } from '../rules/engine/adapters/cursor.js'

const ROOT = join(homedir(), 'Polarisor')
const OUT_DIR = join(ROOT, '.cursor/rules')

/** 手写维护，不由 sync 覆盖 */
const SKIP = new Set(['my-mcp.mdc'])

mkdirSync(OUT_DIR, { recursive: true })

const rules = loadAllRules()
const batch = toMdcBatch(rules)
let written = 0

for (const [filename, content] of batch) {
  if (SKIP.has(filename)) continue
  writeFileSync(join(OUT_DIR, filename), content, 'utf-8')
  written++
  console.log(`  ✓ ${filename}`)
}

console.log(`\nOK: ${written} .mdc files synced to ${OUT_DIR}`)
console.log('Rules:', rules.map(r => mdcFilenameForRule(r)).join(', '))
