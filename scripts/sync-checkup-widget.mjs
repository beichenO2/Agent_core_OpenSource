#!/usr/bin/env node
/**
 * Sync @polarcop/checkup-widget dist to ecosystem hosts + Hub embed static.
 * Run after: cd PolarCopilot/web && npm run build:widget
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const SRC = path.join(ROOT, 'PolarCopilot/web/checkup-widget/dist/checkup-widget.es.js')

const WIDGET_TARGETS = [
  'Clock/frontend/public/checkup-widget',
  'SOTAgent/console/public/checkup-widget',
  'KnowLever/web/checkup-widget',
  'PolarDesign/gallery/checkup-widget',
  'tqsdk/trading-platform/apps/web/public/checkup-widget',
  'PolarCopilot/hub/static/checkup-widget',
]

/** P1 API-only / 无独立前端 — Hub /embed/:project 落地页 */
const HUB_EMBED_PROJECTS = [
  { project: 'PolarPort', note: '端口注册 API — 管理入口' },
  { project: 'PolarMemory', note: '记忆块 API — 控制台入口' },
  { project: 'PolarProcess', note: '进程/watchdog API — 监控入口' },
  { project: 'PolarBudget', note: 'CPU 预算/lease API — 预算入口' },
  { project: 'digist', note: 'DIGiST API — Web 采集入口' },
  { project: 'AutoOffice', note: '文档生成 API — 预览/报告入口' },
]

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true })
}

function copyWidget() {
  if (!fs.existsSync(SRC)) {
    console.error(`Missing widget build: ${SRC}`)
    console.error('Run: cd PolarCopilot/web && npm run build:widget')
    process.exit(1)
  }
  for (const rel of WIDGET_TARGETS) {
    const dir = path.join(ROOT, rel)
    ensureDir(dir)
    const dest = path.join(dir, 'checkup-widget.es.js')
    fs.copyFileSync(SRC, dest)
    console.log(`OK widget → ${rel}/`)
  }
}

function hubEmbedHtml(project, note) {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${project} — 检修入口</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; color: #1a1a2e; }
    code { background: #f1f5f9; padding: 0.15rem 0.4rem; border-radius: 4px; }
  </style>
</head>
<body>
  <h1>${project}</h1>
  <p>${note}</p>
  <p>使用右下角 <strong>检修</strong> 按钮提交问题（截图+批注+描述），路由至 <code>@checkup-agent</code>。</p>
  <script type="module" src="/checkup-widget/checkup-widget.es.js"></script>
  <polar-checkup data-project="${project}" data-position="bottom-right"></polar-checkup>
</body>
</html>
`
}

function writeHubEmbeds() {
  const embedDir = path.join(ROOT, 'PolarCopilot/hub/static/checkup-embed')
  ensureDir(embedDir)
  for (const { project, note } of HUB_EMBED_PROJECTS) {
    const file = path.join(embedDir, `${project}.html`)
    fs.writeFileSync(file, hubEmbedHtml(project, note), 'utf8')
    console.log(`OK embed → hub/static/checkup-embed/${project}.html`)
  }
}

copyWidget()
writeHubEmbeds()
console.log('\nDone. Hub routes: GET /embed/:project  +  /checkup-widget/*')
