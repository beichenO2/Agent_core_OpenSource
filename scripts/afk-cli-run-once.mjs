#!/usr/bin/env node
/**
 * Register ephemeral PolarProcess cursor-cli-afk-* → start → wait stop → unregister.
 * One shared Start/afk-cli/start.sh; params in command string (not register.env).
 *
 * Usage:
 *   node hub/scripts/afk-cli-run-once.mjs --chat <id> --prompt '...'
 *   node hub/scripts/afk-cli-run-once.mjs --dual   # two chats, prove isolation + cleanup
 */
import { spawnSync } from 'node:child_process';

const PP = 'http://127.0.0.1:11055';
const WORK = '~/Polarisor/PolarCopilot';

function parseArgs(argv) {
  const out = { dual: false, chat: null, prompt: null, keep: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dual') out.dual = true;
    else if (a === '--keep') out.keep = true;
    else if (a === '--chat') out.chat = argv[++i];
    else if (a === '--prompt') out.prompt = argv[++i];
  }
  return out;
}

function http(method, path, body) {
  const args = ['-sS', '-X', method, `${PP}${path}`, '-H', 'Content-Type: application/json'];
  if (body !== undefined) args.push('-d', JSON.stringify(body));
  const r = spawnSync('curl', args, { encoding: 'utf8' });
  let json = {};
  try {
    json = JSON.parse(r.stdout || '{}');
  } catch {
    json = { raw: r.stdout, err: r.stderr };
  }
  return { status: r.status, json };
}

function createChat() {
  const r = spawnSync('cursor-agent', ['create-chat'], { encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`create-chat failed: ${r.stderr}`);
  return (r.stdout || '').trim();
}

function sleep(ms) {
  spawnSync('sleep', [String(ms / 1000)]);
}

function runOne({ chatId, prompt, keep }) {
  const id = `cursor-cli-afk-${chatId.slice(0, 8)}`;
  // Quote-safe: chat id is uuid; prompt single-quoted with escape
  const qPrompt = String(prompt).replace(/'/g, `'\\''`);
  const command = `bash Start/afk-cli/start.sh '${chatId}' '${qPrompt}'`;

  console.log('REGISTER', id);
  let res = http('POST', '/api/services/register', {
    id,
    name: `AFK CLI ${chatId.slice(0, 8)}`,
    command,
    work_dir: WORK,
    device_id: 'any',
    auto_start: false,
    restart_on_failure: false,
    max_restarts: 0,
    start_script_dir: 'Start/afk-cli',
  });
  if (!res.json.ok && !/already|exists|registered/i.test(JSON.stringify(res.json))) {
    console.error('register failed', res.json);
    return { id, ok: false, phase: 'register', detail: res.json };
  }

  console.log('START', id);
  res = http('POST', `/api/services/${id}/start`, {});
  if (!res.json.ok) {
    console.error('start failed', res.json);
    if (!keep) http('DELETE', `/api/services/${id}`, {});
    return { id, ok: false, phase: 'start', detail: res.json };
  }

  // Wait until stopped/error (print mode exits)
  let last = null;
  for (let i = 0; i < 60; i++) {
    sleep(2000);
    last = http('GET', `/api/services/${id}`).json;
    if (last.status === 'stopped' || last.status === 'error') break;
  }

  const ok = last?.status === 'stopped' && Number(last?.last_exit_code) === 0;
  console.log('DONE', id, last?.status, last?.last_exit_code);

  if (!keep) {
    // ephemeral cursor-cli-* → DELETE without confirm
    const del = http('DELETE', `/api/services/${id}`, {});
    console.log('UNREGISTER', id, del.json);
  }
  return { id, ok, status: last?.status, exit: last?.last_exit_code, chatId };
}

const args = parseArgs(process.argv.slice(2));
const results = [];

if (args.dual) {
  const a = createChat();
  const b = createChat();
  results.push(
    runOne({ chatId: a, prompt: 'Reply with exactly: AFK_TAB_A and stop.', keep: args.keep }),
  );
  results.push(
    runOne({ chatId: b, prompt: 'Reply with exactly: AFK_TAB_B and stop.', keep: args.keep }),
  );
} else {
  const chat = args.chat || createChat();
  results.push(
    runOne({
      chatId: chat,
      prompt: args.prompt || 'Reply with exactly: AFK_TAB_OK and stop.',
      keep: args.keep,
    }),
  );
}

console.log(JSON.stringify({ results }, null, 2));
process.exit(results.every((r) => r.ok) ? 0 : 1);
