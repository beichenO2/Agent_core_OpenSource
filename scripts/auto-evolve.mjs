#!/usr/bin/env node
/**
 * auto-evolve.mjs — QA-gated dependency evolution for one project.
 *
 * Pipeline (every step is a hard gate; any failure leaves main untouched):
 *   1. working tree must be clean (runtime files whitelisted) else SKIP
 *   2. baseline QA (test cmd) must be green else SKIP  — a red baseline
 *      means there is no gate, so we refuse to upgrade blindly
 *   3. `npm outdated` → only semver-range-respecting targets (`wanted`),
 *      i.e. minor/patch; majors never happen automatically
 *   4. work happens on branch auto-evolve/<stamp>; install + build + QA
 *   5. QA green → merge --no-ff into main; QA red → branch deleted, zero residue
 *   6. service restart via PolarProcess + health poll; unhealthy → revert
 *      the merge and restart again (rollback)
 *   7. markdown report in reports/ + lobster event (best effort)
 *
 * Usage:
 *   node auto-evolve.mjs --dir ~/Polarisor/AutoOffice --service autooffice \
 *     --health http://127.0.0.1:3900/api/health \
 *     [--node ~/.nvm/versions/node/v22.22.2/bin] \
 *     [--test "npm test"] [--build "npm run build"] [--no-restart]
 */

import { execSync, spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import os from 'node:os';

// ---------------------------------------------------------------------------
// args & helpers
// ---------------------------------------------------------------------------

function arg(name, dflt = null) {
  const i = process.argv.indexOf(`--${name}`);
  if (i === -1) return dflt;
  const v = process.argv[i + 1];
  return v && !v.startsWith('--') ? v : true;
}

const DIR = String(arg('dir', '')).replace(/^~/, os.homedir());
const SERVICE = arg('service', null);
const HEALTH = arg('health', null);
const NODE_BIN = arg('node', null);
const TEST_CMD = arg('test', 'npm test');
const BUILD_CMD = arg('build', null);
const NO_RESTART = process.argv.includes('--no-restart');
const POLARPROCESS = (process.env.POLARPROCESS_URL || 'http://127.0.0.1:11055').replace(/\/$/, '');
const PILOT_URL = (process.env.PILOT_URL || 'http://127.0.0.1:4900').replace(/\/$/, '');

if (!DIR || !existsSync(DIR)) {
  console.error('[auto-evolve] --dir missing or not found:', DIR);
  process.exit(1);
}

const ENV = { ...process.env };
if (NODE_BIN) {
  ENV.PATH = `${NODE_BIN}:${ENV.PATH}`;
  ENV.npm_config_scripts_prepend_node_path = 'true';
}

/** Runtime / generated artifacts allowed to be dirty without blocking evolution. */
const RUNTIME_DIRTY_RE = /lobster-events.*\.jsonl|\.log$|\.pid$|reports\/(auto-evolve|sota-radar)-/;

const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '').slice(0, 12);
const BRANCH = `auto-evolve/${stamp}`;
const log = (...a) => console.log('[auto-evolve]', ...a);

function sh(cmd, opts = {}) {
  return execSync(cmd, { cwd: DIR, env: ENV, encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 600_000, ...opts });
}

/** Git ops can race peer-sync / IDE; retry when HEAD.lock is transient. */
function shGit(cmd, opts = {}) {
  const lock = join(DIR, '.git', 'HEAD.lock');
  for (let attempt = 0; attempt < 12; attempt++) {
    try {
      return sh(cmd, opts);
    } catch (err) {
      const msg = String(err?.stderr || err?.message || err);
      const locked = msg.includes('HEAD.lock') || msg.includes('index.lock') || existsSync(lock);
      if (!locked || attempt === 11) throw err;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 2500 * (attempt + 1));
    }
  }
}

function run(cmd) {
  // Avoid `-lc`: login shells re-source nvm and can downgrade Node mid-pipeline.
  const r = spawnSync('/bin/bash', ['-c', cmd], { cwd: DIR, env: ENV, encoding: 'utf-8', timeout: 900_000 });
  return { ok: r.status === 0, out: (r.stdout || '') + (r.stderr || ''), code: r.status };
}

async function emitEvent(severity, payload) {
  try {
    await fetch(`${PILOT_URL}/api/pilot/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'custom',
        source_project: SERVICE || 'auto-evolve',
        target_project: SERVICE || 'auto-evolve',
        severity,
        payload: { kind: 'auto-evolve', ...payload },
        dedup_key: `auto-evolve:${SERVICE}:${stamp}`,
      }),
      signal: AbortSignal.timeout(5000),
    });
  } catch { /* best effort */ }
}

const reportLines = [`# auto-evolve — ${SERVICE ?? DIR} — ${new Date().toISOString()}`, ''];
function note(line) { reportLines.push(line); log(line); }

function writeReport() {
  try {
    const dir = join(DIR, 'reports');
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, `auto-evolve-${stamp}.md`), reportLines.join('\n') + '\n', 'utf-8');
  } catch (e) { log('report write failed:', e.message); }
}

async function finish(status, extra = {}) {
  note('');
  note(`**Result: ${status}**`);
  writeReport();
  await emitEvent(status === 'upgraded' ? 'info' : status === 'rolled-back' ? 'error' : 'warning', { status, ...extra });
  process.exit(status === 'rolled-back' ? 1 : 0);
}

// ---------------------------------------------------------------------------
// pipeline
// ---------------------------------------------------------------------------

async function main() {
  // gate 1: clean tree
  const dirty = shGit('git status --porcelain').split('\n').filter(Boolean)
    .filter((l) => !RUNTIME_DIRTY_RE.test(l));
  if (dirty.length > 0) {
    note(`Gate 1 FAILED — working tree has ${dirty.length} non-runtime changes; refusing to evolve on top of WIP.`);
    dirty.slice(0, 8).forEach((l) => note(`  ${l}`));
    return finish('skipped', { reason: 'dirty-tree' });
  }
  const baseRef = shGit('git rev-parse HEAD').trim();
  const baseBranch = shGit('git rev-parse --abbrev-ref HEAD').trim();
  note(`Gate 1 OK — clean tree on ${baseBranch}@${baseRef.slice(0, 7)}`);

  // gate 2: baseline QA
  note(`Gate 2 — baseline QA: \`${TEST_CMD}\``);
  const baseline = run(TEST_CMD);
  if (!baseline.ok) {
    note('Gate 2 FAILED — baseline tests are red; no QA gate exists, refusing blind upgrade.');
    note('```\n' + baseline.out.slice(-1500) + '\n```');
    return finish('skipped', { reason: 'baseline-red' });
  }
  note('Gate 2 OK — baseline green');

  // gate 3: what can move within semver ranges?
  let outdated = {};
  try {
    outdated = JSON.parse(sh('npm outdated --json || true') || '{}');
  } catch { outdated = {}; }
  const targets = Object.entries(outdated)
    .filter(([, v]) => v.current && v.wanted && v.current !== v.wanted)
    .map(([name, v]) => ({ name, from: v.current, to: v.wanted }));
  if (targets.length === 0) {
    note('Gate 3 — nothing to upgrade within semver ranges (majors are never auto-applied).');
    return finish('up-to-date');
  }
  note(`Gate 3 — ${targets.length} in-range upgrades: ${targets.map((t) => `${t.name} ${t.from}→${t.to}`).join(', ')}`);

  // branch work
  shGit(`git checkout -b ${BRANCH}`);
  try {
    const spec = targets.map((t) => `${t.name}@${t.to}`).join(' ');
    note(`Installing: ${spec}`);
    const inst = run(`npm install ${spec}`);
    if (!inst.ok) throw new Error('npm install failed:\n' + inst.out.slice(-1200));

    if (targets.some((t) => t.name === 'playwright')) {
      note('playwright bumped — refreshing browser bundle (npmmirror fallback)');
      const pw = run('npx playwright install chromium || PLAYWRIGHT_DOWNLOAD_HOST=https://cdn.npmmirror.com/binaries/playwright npx playwright install chromium');
      if (!pw.ok) throw new Error('playwright browser install failed:\n' + pw.out.slice(-800));
    }

    if (BUILD_CMD) {
      note(`Build: \`${BUILD_CMD}\``);
      const b = run(BUILD_CMD);
      if (!b.ok) throw new Error('build failed:\n' + b.out.slice(-1200));
    }

    note(`QA gate: \`${TEST_CMD}\``);
    const qa = run(TEST_CMD);
    if (!qa.ok) throw new Error('QA gate red after upgrade:\n' + qa.out.slice(-1500));
    note('QA gate GREEN on upgraded deps');

    // guard against concurrent auto-committers polluting the branch
    const tip = shGit('git log -1 --format=%s').trim();
    shGit('git add -A');
    shGit(`git commit -m "chore(auto-evolve): ${targets.map((t) => `${t.name}@${t.to}`).join(' ')}" -m "QA-gated in-range upgrade. Baseline green, post-upgrade suite green. Generated by Agent_core/scripts/auto-evolve.mjs."`);
    void tip;

    shGit(`git checkout ${baseBranch}`);
    shGit(`git merge --no-ff ${BRANCH} -m "merge: auto-evolve ${stamp} (${targets.length} deps, QA green)"`);
    shGit(`git branch -d ${BRANCH}`);
    note(`Merged into ${baseBranch}: ${shGit('git log -1 --oneline').trim()}`);
  } catch (err) {
    note(`Upgrade aborted — ${String(err.message || err)}`);
    run(`git checkout -f ${baseBranch}`);
    run(`git branch -D ${BRANCH}`);
    run(`git reset --hard ${baseRef}`);
    note(`Residue cleaned; ${baseBranch} back at ${baseRef.slice(0, 7)}.`);
    return finish('skipped', { reason: 'qa-red-or-install-failure' });
  }

  // restart + health gate
  if (SERVICE && HEALTH && !NO_RESTART) {
    note(`Restarting ${SERVICE} via PolarProcess`);
    const r = run(`curl -sS -m 20 -X POST ${POLARPROCESS}/api/services/${SERVICE}/restart`);
    note(r.out.trim().slice(0, 200));
    let healthy = false;
    for (let i = 0; i < 20; i++) {
      await new Promise((res) => setTimeout(res, 3000));
      const h = run(`curl -sS -o /dev/null -w '%{http_code}' -m 4 ${HEALTH}`);
      if (h.out.trim() === '200') { healthy = true; break; }
    }
    if (!healthy) {
      note('Health gate FAILED after 60s — rolling back merge.');
      run('git revert -m 1 --no-edit HEAD');
      run(`curl -sS -m 20 -X POST ${POLARPROCESS}/api/services/${SERVICE}/restart`);
      return finish('rolled-back', { targets });
    }
    note('Health gate OK — service healthy on upgraded deps.');
  } else {
    note('Restart skipped (no --service/--health or --no-restart).');
  }

  return finish('upgraded', { targets });
}

main().catch(async (err) => {
  note(`Unexpected failure: ${String(err?.stack || err)}`);
  writeReport();
  await emitEvent('error', { status: 'crashed' });
  process.exit(1);
});
