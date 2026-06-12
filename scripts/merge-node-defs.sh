#!/usr/bin/env bash
# merge-node-defs.sh — 将 node-defs/ 树状目录合并为兼容单文件 node-defs.json
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
DIR="$ROOT/node-defs"
OUT="$ROOT/node-defs.json"

if [[ ! -f "$DIR/index.json" ]]; then
  echo "ERROR: missing $DIR/index.json" >&2
  exit 1
fi

MERGE_ROOT="$ROOT" MERGE_OUT="$OUT" node - <<'NODE'
const fs = require('node:fs')
const path = require('node:path')

const root = process.env.MERGE_ROOT
const out = process.env.MERGE_OUT
const dir = path.join(root, 'node-defs')
const index = JSON.parse(fs.readFileSync(path.join(dir, 'index.json'), 'utf8'))
const merged = []

for (const file of index.files) {
  const chunk = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'))
  if (!Array.isArray(chunk)) {
    console.error(`ERROR: ${file} is not a JSON array`)
    process.exit(1)
  }
  merged.push(...chunk)
}

const seen = new Set()
for (const node of merged) {
  if (seen.has(node.class_type)) {
    console.error(`ERROR: duplicate class_type ${node.class_type}`)
    process.exit(1)
  }
  seen.add(node.class_type)
}

fs.writeFileSync(out, `${JSON.stringify(merged, null, 2)}\n`)
console.log(`OK: merged ${merged.length} nodes -> ${out}`)
NODE
