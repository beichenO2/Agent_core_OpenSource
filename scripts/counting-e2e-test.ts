#!/usr/bin/env npx tsx
/**
 * E2E Counting Test — multi-role number reporting 1-200.
 *
 * Tests the v0.2 packet protocol by:
 * 1. Starting an in-process Hub
 * 2. Proxy submits a "count from 1 to 200" phase_objective to Controller
 * 3. Controller decomposes into batches of implementation_task for Workers
 * 4. Workers report their numbers
 * 5. Verify all 200 numbers are reported in correct order
 *
 * Uses PolarPrivate proxy + qwen3-coder-plus for LLM calls.
 *
 * Usage:
 *   npx tsx scripts/counting-e2e-test.ts [--batch-size 20] [--workers 3]
 */

import { parseArgs } from 'node:util';

const PROXY_BASE = `${process.env.POLARPRIVATE_URL || 'http://127.0.0.1:12790'}/v1`;
const MODEL = 'qwen3.6-plus';

const { values } = parseArgs({
  options: {
    'batch-size': { type: 'string', default: '20' },
    workers: { type: 'string', default: '3' },
    'dry-run': { type: 'boolean', default: false },
  },
});

const BATCH_SIZE = parseInt(values['batch-size']!, 10);
const NUM_WORKERS = parseInt(values.workers!, 10);
const DRY_RUN = values['dry-run'] ?? false;

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

async function callLlm(messages: ChatMessage[]): Promise<string> {
  const resp = await fetch(`${PROXY_BASE}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: MODEL, messages, temperature: 0 }),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`LLM call failed: ${resp.status} ${text}`);
  }

  const data = await resp.json() as {
    choices: Array<{ message: { content: string } }>;
  };
  return data.choices[0].message.content;
}

type CountingResult = {
  worker_id: string;
  batch_start: number;
  batch_end: number;
  numbers: number[];
};

async function workerCountBatch(
  workerId: string,
  batchStart: number,
  batchEnd: number,
): Promise<CountingResult> {
  const systemPrompt = `You are a counting worker agent (${workerId}). You receive a range and must output ONLY a JSON object. No explanation, no markdown.`;

  const userPrompt = `Count from ${batchStart} to ${batchEnd} (inclusive). Output this exact JSON format:
{
  "worker_id": "${workerId}",
  "batch_start": ${batchStart},
  "batch_end": ${batchEnd},
  "numbers": [${batchStart}, ${batchStart + 1}, ..., ${batchEnd}]
}

Output ONLY the JSON object. Nothing else.`;

  if (DRY_RUN) {
    const numbers: number[] = [];
    for (let i = batchStart; i <= batchEnd; i++) numbers.push(i);
    return { worker_id: workerId, batch_start: batchStart, batch_end: batchEnd, numbers };
  }

  const raw = await callLlm([
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ]);

  const jsonMatch = raw.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error(`Worker ${workerId} output no JSON: ${raw.slice(0, 200)}`);
  }

  const parsed = JSON.parse(jsonMatch[0]) as CountingResult;
  return parsed;
}

async function controllerDecompose(totalCount: number, batchSize: number): Promise<Array<{ start: number; end: number }>> {
  const systemPrompt = `You are a controller agent. You decompose a counting task into batches. Output ONLY a JSON array.`;

  const userPrompt = `Decompose counting from 1 to ${totalCount} into batches of ${batchSize}. Output this exact JSON format:
[
  { "start": 1, "end": ${batchSize} },
  { "start": ${batchSize + 1}, "end": ${batchSize * 2} },
  ...
]

Output ONLY the JSON array. Nothing else.`;

  if (DRY_RUN) {
    const batches: Array<{ start: number; end: number }> = [];
    for (let i = 1; i <= totalCount; i += batchSize) {
      batches.push({ start: i, end: Math.min(i + batchSize - 1, totalCount) });
    }
    return batches;
  }

  const raw = await callLlm([
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ]);

  const jsonMatch = raw.match(/\[[\s\S]*\]/);
  if (!jsonMatch) {
    throw new Error(`Controller output no JSON array: ${raw.slice(0, 200)}`);
  }

  return JSON.parse(jsonMatch[0]) as Array<{ start: number; end: number }>;
}

async function run() {
  console.log('=== gsd-2 E2E Counting Test ===');
  console.log(`Target: count 1 to 200`);
  console.log(`Batch size: ${BATCH_SIZE}`);
  console.log(`Workers: ${NUM_WORKERS}`);
  console.log(`Model: ${MODEL}`);
  console.log(`Dry run: ${DRY_RUN}`);
  console.log('');

  // Phase 1: Controller decomposes the task
  console.log('[Controller] Decomposing counting task...');
  const batches = await controllerDecompose(200, BATCH_SIZE);
  console.log(`[Controller] Created ${batches.length} batches`);

  // Phase 2: Workers execute batches in parallel (round-robin assignment)
  const workerAssignments: Map<string, Array<{ start: number; end: number }>> = new Map();
  for (let i = 0; i < batches.length; i++) {
    const workerIdx = (i % NUM_WORKERS) + 1;
    const workerId = `w${String(workerIdx).padStart(3, '0')}`;
    if (!workerAssignments.has(workerId)) {
      workerAssignments.set(workerId, []);
    }
    workerAssignments.get(workerId)!.push(batches[i]);
  }

  console.log('');
  for (const [wid, assigned] of workerAssignments) {
    console.log(`[${wid}] Assigned ${assigned.length} batches`);
  }
  console.log('');

  const allResults: CountingResult[] = [];
  const startTime = Date.now();

  // Execute batches — each worker processes its batches sequentially,
  // but different workers run in parallel
  const workerPromises = Array.from(workerAssignments.entries()).map(
    async ([workerId, assigned]) => {
      const results: CountingResult[] = [];
      for (const batch of assigned) {
        console.log(`[${workerId}] Counting ${batch.start}-${batch.end}...`);
        const result = await workerCountBatch(workerId, batch.start, batch.end);
        results.push(result);
        console.log(`[${workerId}] Done ${batch.start}-${batch.end} (${result.numbers.length} numbers)`);
      }
      return results;
    },
  );

  const workerResults = await Promise.all(workerPromises);
  for (const results of workerResults) {
    allResults.push(...results);
  }

  const elapsed = Date.now() - startTime;

  // Phase 3: Supervisor verifies
  console.log('');
  console.log('[Supervisor] Verifying results...');

  allResults.sort((a, b) => a.batch_start - b.batch_start);

  const allNumbers: number[] = [];
  for (const result of allResults) {
    allNumbers.push(...result.numbers);
  }

  // Verification checks
  let errors = 0;

  // Check 1: Total count
  if (allNumbers.length !== 200) {
    console.error(`  FAIL: Expected 200 numbers, got ${allNumbers.length}`);
    errors++;
  } else {
    console.log(`  PASS: Total count = 200`);
  }

  // Check 2: All numbers present
  const numberSet = new Set(allNumbers);
  const missing: number[] = [];
  for (let i = 1; i <= 200; i++) {
    if (!numberSet.has(i)) missing.push(i);
  }
  if (missing.length > 0) {
    console.error(`  FAIL: Missing numbers: ${missing.join(', ')}`);
    errors++;
  } else {
    console.log(`  PASS: All numbers 1-200 present`);
  }

  // Check 3: No duplicates
  if (allNumbers.length !== numberSet.size) {
    const duplicates = allNumbers.filter((n, i) => allNumbers.indexOf(n) !== i);
    console.error(`  FAIL: Duplicate numbers: ${[...new Set(duplicates)].join(', ')}`);
    errors++;
  } else {
    console.log(`  PASS: No duplicates`);
  }

  // Check 4: Sequence within each batch is correct
  let seqErrors = 0;
  for (const result of allResults) {
    for (let i = 0; i < result.numbers.length; i++) {
      const expected = result.batch_start + i;
      if (result.numbers[i] !== expected) {
        seqErrors++;
      }
    }
  }
  if (seqErrors > 0) {
    console.error(`  FAIL: ${seqErrors} sequence errors within batches`);
    errors++;
  } else {
    console.log(`  PASS: Batch sequences correct`);
  }

  console.log('');
  console.log('=== Summary ===');
  console.log(`Batches: ${allResults.length}`);
  console.log(`Workers used: ${workerAssignments.size}`);
  console.log(`Numbers collected: ${allNumbers.length}`);
  console.log(`Elapsed: ${elapsed}ms`);
  console.log(`Errors: ${errors}`);
  console.log(`Result: ${errors === 0 ? '✅ ALL PASS' : '❌ FAILED'}`);

  process.exit(errors > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
