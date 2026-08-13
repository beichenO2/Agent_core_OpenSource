#!/usr/bin/env node
/**
 * 通用规则注入 CLI — PolarClaw / PolarPilot / 任意调用方
 * 用法:
 *   node inject-rules.mjs "用户消息文本"
 *   node inject-rules.mjs --adapter claw "git commit"
 *   node inject-rules.mjs --adapter pilot "watchdog 崩溃"
 *   node inject-rules.mjs --skill pc-solo-web
 */
import {
  selectRules,
  rulesToPrompt,
  buildClawAppend,
  buildPilotSystem,
  buildSkillPrompt,
} from '../rules/engine/runtime-inject.mjs'

const args = process.argv.slice(2)
let adapter = 'plain'
let skillId = null
const textParts = []

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--adapter' && args[i + 1]) {
    adapter = args[++i]
    continue
  }
  if (args[i] === '--skill' && args[i + 1]) {
    skillId = args[++i]
    continue
  }
  textParts.push(args[i])
}

if (skillId) {
  const prompt = buildSkillPrompt(skillId)
  if (!prompt) {
    console.error(`[inject-rules] skill not found: ${skillId}`)
    process.exit(1)
  }
  console.log(prompt)
  process.exit(0)
}

const input = textParts.join(' ') || ''
let out = ''
if (adapter === 'claw') out = buildClawAppend(input)
else if (adapter === 'pilot') out = buildPilotSystem(input)
else out = rulesToPrompt(selectRules(input))

console.log(out)
console.error(`[inject-rules] adapter=${adapter} matched ${selectRules(input).length} rules`)
