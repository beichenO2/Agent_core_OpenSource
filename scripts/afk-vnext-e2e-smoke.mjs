#!/usr/bin/env node
/**
 * AFK vNext automated E2E smoke.
 * node hub/scripts/afk-vnext-e2e-smoke.mjs
 */
import { spawnSync } from 'node:child_process';
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  rmSync,
  chmodSync,
  existsSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
// Pin absolute roots — avoid symlink / cwd surprises in agent shells.
const REPO = '~/Polarisor/PolarCopilot';
const HUB = join(REPO, 'hub');
const TSX_CLI = join(HUB, 'node_modules/tsx/dist/cli.mjs');
const HOOK = join(HUB, 'scripts/afk-stop-hook.sh');
console.log('E2E_ROOTS', { __dirname, HUB, REPO, TSX_CLI, existsHook: existsSync(HOOK) });

const results = [];
const pass = (name, salient) => {
  results.push({ name, ok: true, salient });
  console.log(`PASS  ${name} :: ${salient}`);
};
const fail = (name, salient) => {
  results.push({ name, ok: false, salient });
  console.error(`FAIL  ${name} :: ${salient}`);
};

const dir = mkdtempSync(join(tmpdir(), 'afk-e2e-'));
const dbPath = join(dir, 'afk.db');

const probeSrc = `
import { openAfkDb } from '${join(HUB, 'src/rr/afk/vnext/db.ts')}';
import { bindIdeConversation, gateCheckForConversation, registerNativeLane } from '${join(HUB, 'src/rr/afk/vnext/ide-adapter.ts')}';
import { createWebTask, buildCursorAgentProcessCommand, resolveExecConcurrency } from '${join(HUB, 'src/rr/afk/vnext/cli-adapter.ts')}';
import { assertCanMarkDone } from '${join(HUB, 'src/rr/afk/vnext/bridge.ts')}';
import { addCriterion, addWorkUnit, leaseWorkUnit, listActiveTasks, getTask, transitionTask } from '${join(HUB, 'src/rr/afk/vnext/store.ts')}';
import { completeTaskIfGatePasses } from '${join(HUB, 'src/rr/afk/vnext/completion-gate.ts')}';

const db = openAfkDb(process.env.POLAR_AFK_DB);
const a = bindIdeConversation(db, { conversationId: 'conv-A', projectRoot: '/repo', goal: 'task-A' });
const b = bindIdeConversation(db, { conversationId: 'conv-B', projectRoot: '/repo', goal: 'task-B' });
registerNativeLane(db, { taskId: a.task_id, laneKey: 'L1', role: 'implementer', nativeSubagentId: 'sub-A' });
registerNativeLane(db, { taskId: b.task_id, laneKey: 'L1', role: 'implementer', nativeSubagentId: 'sub-B' });
const dualBefore = {
  different: a.task_id !== b.task_id,
  a: gateCheckForConversation(db, 'conv-A', '/repo'),
  b: gateCheckForConversation(db, 'conv-B', '/repo'),
  cross: gateCheckForConversation(db, 'conv-A', '/other'),
  ids: [a.task_id, b.task_id],
};
const w1 = createWebTask(db, { goal: 'web-1', projectRoot: '/w1' });
const w2 = createWebTask(db, { goal: 'web-2', projectRoot: '/w2' });
const cmd1 = buildCursorAgentProcessCommand({
  taskId: w1.task_id, nativeHandle: 'chat-w1', resume: true, prompt: 'ping', workspace: '/w1', serviceId: 'afk-cli-w1',
});
addCriterion(db, a.task_id, 'only-A');
transitionTask(db, a.task_id, 'VERIFYING');
transitionTask(db, a.task_id, 'READY_TO_DELIVER');
const rejectNoEv = assertCanMarkDone(a.task_id, { db, projectRoot: '/repo' });
const withEv = assertCanMarkDone(a.task_id, { db, projectRoot: '/repo', evidence: { command: 'true', exitCode: 0, salient: 'ok' } });
const c1 = completeTaskIfGatePasses(db, a.task_id);
const c2 = completeTaskIfGatePasses(db, a.task_id);
const afterDoneA = gateCheckForConversation(db, 'conv-A', '/repo');
const stillB = gateCheckForConversation(db, 'conv-B', '/repo');
const u = addWorkUnit(db, { taskId: b.task_id, state: 'pending' });
const l1 = leaseWorkUnit(db, u, 'owner-1', 600000);
const l2 = leaseWorkUnit(db, u, 'owner-2', 600000);
const out = {
  dual: dualBefore,
  after: { aDoneNoContinue: afterDoneA.ok === true && afterDoneA.status === 'DONE', bStillContinue: stillB.ok === false },
  web: {
    queued: w1.status === 'QUEUED' && w2.status === 'QUEUED',
    resumeInCmd: cmd1.command.includes('Start/afk-cli/start.sh') && cmd1.command.includes('chat-w1') && cmd1.id.startsWith('cursor-cli-'),
    execConc: resolveExecConcurrency(null),
  },
  dupDone: {
    rejectNoEv: rejectNoEv.ok === false,
    firstOk: c1.ok === true && withEv.ok === true,
    secondStillDone: getTask(db, a.task_id)?.status === 'DONE',
    notActive: !listActiveTasks(db).some(t => t.task_id === a.task_id),
    secondGate: c2.ok === false,
  },
  lease: { first: l1.ok === true, secondFail: l2.ok === false },
};
console.log(JSON.stringify(out));
db.close();
`;

writeFileSync(join(dir, 'probe.mts'), probeSrc);

const probe = spawnSync(process.execPath, [TSX_CLI, join(dir, 'probe.mts')], {
  cwd: HUB,
  env: { ...process.env, POLAR_AFK_DB: dbPath, NODE_OPTIONS: '' },
  encoding: 'utf8',
});

let out = null;
if (probe.status !== 0) {
  fail('probe', (probe.stderr || probe.stdout || '').slice(0, 500));
} else {
  try {
    out = JSON.parse(probe.stdout.trim().split('\n').filter(Boolean).pop());
    pass('probe', 'ok');
  } catch (e) {
    fail('probe-parse', probe.stdout.slice(0, 400));
  }
}

if (out) {
  out.dual?.different && out.dual.a?.task_id && out.dual.b?.task_id && out.dual.a.task_id !== out.dual.b.task_id
    ? pass('dual-ide-bind-isolation', `${out.dual.a.task_id} | ${out.dual.b.task_id}`)
    : fail('dual-ide-bind-isolation', JSON.stringify(out.dual));

  out.dual?.a?.ok === false && out.dual?.b?.ok === false
    ? pass('gate-check-needs-continue', 'both running before done')
    : fail('gate-check-needs-continue', JSON.stringify({ a: out.dual?.a, b: out.dual?.b }));

  out.after?.aDoneNoContinue && out.after?.bStillContinue
    ? pass('done-A-does-not-stop-B', JSON.stringify(out.after))
    : fail('done-A-does-not-stop-B', JSON.stringify(out.after));

  out.dual?.cross?.task_id == null
    ? pass('cross-cwd-no-leak', 'conv-A+/other → unbound')
    : fail('cross-cwd-no-leak', JSON.stringify(out.dual.cross));
  out.web?.queued && out.web?.resumeInCmd && out.web?.execConc === 1
    ? pass('web-cli-queued-resume-budget1', 'ok')
    : fail('web-cli-queued-resume-budget1', JSON.stringify(out.web));

  out.dupDone?.rejectNoEv && out.dupDone?.firstOk && out.dupDone?.notActive && out.dupDone?.secondStillDone
    ? pass('duplicate-done-gate', JSON.stringify(out.dupDone))
    : fail('duplicate-done-gate', JSON.stringify(out.dupDone));

  out.lease?.first && out.lease?.secondFail
    ? pass('stale-lease-conflict', 'ok')
    : fail('stale-lease-conflict', JSON.stringify(out.lease));
}

chmodSync(HOOK, 0o755);
const hUnbound = spawnSync(HOOK, {
  input: JSON.stringify({
    hook_event_name: 'stop',
    status: 'completed',
    conversation_id: 'unbound-xyz',
    workspace_roots: ['/repo'],
    loop_count: 0,
  }),
  encoding: 'utf8',
  env: { ...process.env, POLAR_AFK_DB: dbPath },
});
(hUnbound.stdout || '').trim() === '{}'
  ? pass('stop-hook-unbound-noop', '{}')
  : fail('stop-hook-unbound-noop', hUnbound.stdout);

const hBound = spawnSync(HOOK, {
  input: JSON.stringify({
    hook_event_name: 'stop',
    status: 'completed',
    conversation_id: 'conv-B',
    workspace_roots: ['/repo'],
    loop_count: 0,
  }),
  encoding: 'utf8',
  env: { ...process.env, POLAR_AFK_DB: dbPath },
});
let hj = {};
try {
  hj = JSON.parse(hBound.stdout || '{}');
} catch {
  /* */
}
typeof hj.followup_message === 'string' && hj.followup_message.includes('AFK_CONTINUE')
  ? pass('stop-hook-followup-bound', hj.followup_message.slice(0, 80))
  : fail('stop-hook-followup-bound', (hBound.stdout || '').slice(0, 300));

// Hub API (may 404 if hub not restarted with vnext routes)
const hubGet = spawnSync('curl', ['-sS', '-o', join(dir, 'hub.json'), '-w', '%{http_code}', '--max-time', '3', 'http://127.0.0.1:8040/api/ui/rr/afk/vnext/tasks'], {
  encoding: 'utf8',
});
const code = (hubGet.stdout || '').trim();
if (code === '200') pass('hub-afk-vnext-api', '200');
else fail('hub-afk-vnext-api', `http=${code} (restart polarcop-hub to load vnext routes)`);

const mcp = spawnSync(process.execPath, [join(REPO, 'scripts/afk-mcp-control-plane-disable.mjs'), '--dry-run'], {
  encoding: 'utf8',
});
let mcpJ = {};
try {
  mcpJ = JSON.parse(mcp.stdout || '{}');
} catch {
  /* */
}
const safe = (mcpJ.wouldRemove || []).filter(
  (x) => x === 'rr-chat' || x === 'xj-chat' || String(x).startsWith('my-mcp-'),
);
safe.length >= 3
  ? pass('mcp-audit-safe-subset', `safe=${safe.join(',')} deferred_hub_agent=yes`)
  : fail('mcp-audit-safe-subset', (mcp.stdout || mcp.stderr || '').slice(0, 200));

const c1 = spawnSync('cursor-agent', ['create-chat'], { encoding: 'utf8', timeout: 60000 });
const c2 = spawnSync('cursor-agent', ['create-chat'], { encoding: 'utf8', timeout: 60000 });
const id1 = (c1.stdout || '').trim();
const id2 = (c2.stdout || '').trim();
c1.status === 0 && c2.status === 0 && id1 && id2 && id1 !== id2
  ? pass('cursor-agent-create-chat-dual', `${id1} | ${id2}`)
  : fail('cursor-agent-create-chat-dual', `c1=${c1.status} c2=${c2.status}`);

if (id1) {
  const run = spawnSync(
    'cursor-agent',
    ['-p', '--trust', '--force', '--resume', id1, '--output-format', 'text', 'Reply with exactly: AFK_SMOKE_OK and stop.'],
    { encoding: 'utf8', timeout: 120000, cwd: REPO },
  );
  const body = `${run.stdout || ''}${run.stderr || ''}`;
  run.status === 0 && /AFK_SMOKE_OK/.test(body)
    ? pass('cursor-agent-resume-print', 'AFK_SMOKE_OK')
    : fail('cursor-agent-resume-print', `exit=${run.status} ${body.slice(0, 200).replace(/\s+/g, ' ')}`);
}

if (id1 && id2) {
  // Second chat resume isolation — should not see first chat's AFK_SMOKE unless coincidental
  const run2 = spawnSync(
    'cursor-agent',
    ['-p', '--trust', '--force', '--resume', id2, '--output-format', 'text', 'Reply with exactly: AFK_SMOKE_B and stop.'],
    { encoding: 'utf8', timeout: 120000, cwd: REPO },
  );
  const body2 = `${run2.stdout || ''}${run2.stderr || ''}`;
  run2.status === 0 && /AFK_SMOKE_B/.test(body2)
    ? pass('cursor-agent-resume-print-B', 'AFK_SMOKE_B')
    : fail('cursor-agent-resume-print-B', `exit=${run2.status} ${body2.slice(0, 200).replace(/\s+/g, ' ')}`);
}

const reportPath = join(REPO, 'docs/superpowers/evidence/2026-07-31-afk-vnext-e2e-smoke.json');
mkdirSync(dirname(reportPath), { recursive: true });
const summary = {
  at: new Date().toISOString(),
  repo: REPO,
  dbPath,
  results,
  pass: results.filter((x) => x.ok).length,
  fail: results.filter((x) => !x.ok).length,
  human_still_required: [
    'Two Cursor IDE Agent tabs (real conversation_id from IDE) + natural stop → followup',
    'PolarProcess register+start for long-running CLI (after hub restart)',
    'Hub restart mid-run observation',
    'MCP --apply for rr-chat/xj-chat/my-mcp only after user ack',
  ],
};
writeFileSync(reportPath, JSON.stringify(summary, null, 2));
console.log('\nREPORT', reportPath);
console.log(`TOTAL pass=${summary.pass} fail=${summary.fail}`);
rmSync(dir, { recursive: true, force: true });
process.exit(summary.fail === 0 ? 0 : 1);
