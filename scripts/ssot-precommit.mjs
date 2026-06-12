#!/usr/bin/env node
// ssot-precommit.mjs — SSoT pre-commit deep validation (Layer 3)
//
// Exit codes:
//   0 — pass (commit allowed)
//   1 — reject (commit blocked)
//
// Validation rules:
//   | Rule                                          | Exit | Severity |
//   |-----------------------------------------------|------|----------|
//   | polaris.json is not valid JSON                | 1    | hard     |
//   | status="done" feature missing test_status     | 1    | hard     |
//   | status="done" + test_status != "passed"       | 0    | warning  |
//   | All features have empty behavior[]            | 1    | hard     |
//   | PolarSoul.md is deleted                       | 1    | hard     |
//   | test_status="not_tested"                      | 0    | compliant|
//   | New project (no polaris.json yet)             | 0    | normal   |

import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { execSync } from 'node:child_process';

// ─── Arguments ────────────────────────────────────────────────────────────────

const rawArgs = process.argv.slice(2);
const checkFilesIdx = rawArgs.indexOf('--check-files');
const checkFiles = checkFilesIdx >= 0
  ? rawArgs[checkFilesIdx + 1].split(',').map((f) => f.trim()).filter(Boolean)
  : [];

if (checkFiles.length === 0) {
  process.exit(0);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getPolarisRoot() {
  return process.env.POLARISOR_ROOT || join(homedir(), 'Polarisor');
}

/**
 * Attempt to parse file as JSON.
 * Returns { parsed, error } so caller can distinguish "valid JSON" from "file not found".
 */
function readJson(filePath) {
  if (!existsSync(filePath)) {
    return { parsed: null, error: 'file not found' };
  }
  try {
    return { parsed: JSON.parse(readFileSync(filePath, 'utf-8')), error: null };
  } catch (err) {
    return { parsed: null, error: String(err) };
  }
}

/**
 * Detect if a file is staged as deleted using git diff --cached --diff-filter=D
 */
function isDeletedInGit(fileName) {
  try {
    const out = String(
      execSync('git diff --cached --name-only --diff-filter=D 2>/dev/null', {
        encoding: 'utf-8',
        timeout: 5000,
      }),
    );
    return out.split('\n').map((l) => l.trim()).filter(Boolean).includes(fileName);
  } catch {
    return false;
  }
}

// ─── Validators ──────────────────────────────────────────────────────────────

/**
 * Hard block: polaris.json must be parseable as JSON.
 */
function validateJsonStructure(filePath) {
  const { parsed, error } = readJson(filePath);
  if (error) {
    return [{ type: 'json_invalid', detail: error, file: filePath }];
  }
  return [];
}

/**
 * Hard block: every feature with status="done" MUST have a test_status field.
 * Soft warning: status="done" with test_status != "passed" is allowed (honest marking).
 *
 * Allowed test_status values: "passed", "failed", "not_tested"
 * Missing test_status on a done feature: hard error.
 */
function validateDoneFeatures(parsed, filePath) {
  const errors = [];
  const warnings = [];

  const allFeatures = [];
  for (const req of parsed.requirements || []) {
    for (const feat of req.features || []) {
      allFeatures.push(feat);
    }
  }

  for (const feature of allFeatures) {
    if (feature.status === 'done') {
      if (!Object.prototype.hasOwnProperty.call(feature, 'test_status')) {
        errors.push({
          type: 'done_without_test_status',
          detail: `feature "${feature.name}" has status=done but is missing test_status field`,
          file: filePath,
          feature: feature.name,
        });
      } else if (feature.test_status !== 'passed') {
        // W-HON-1: honest marking — failed/not_tested are allowed with a warning
        warnings.push({
          type: 'done_test_status_not_passed',
          detail: `feature "${feature.name}" has status=done with test_status="${feature.test_status}" (honest marking allowed)`,
          file: filePath,
          feature: feature.name,
        });
      }
    }
  }

  return { errors, warnings };
}

/**
 * Hard block: every feature must have at least one non-empty behavior entry.
 * An empty behavior[] array is a spec deficiency — reject.
 */
function validateBehavior(parsed, filePath) {
  const errors = [];
  const warnings = [];

  const allFeatures = [];
  for (const req of parsed.requirements || []) {
    for (const feat of req.features || []) {
      allFeatures.push(feat);
    }
  }

  if (allFeatures.length === 0) {
    // No features yet — normal for new projects
    return { errors, warnings };
  }

  for (const feature of allFeatures) {
    if (!Array.isArray(feature.behavior) || feature.behavior.length === 0) {
      errors.push({
        type: 'empty_behavior',
        detail: `feature "${feature.name}" has empty behavior[]`,
        file: filePath,
        feature: feature.name,
      });
      continue;
    }
    const trimmed = feature.behavior.map((b) => String(b).trim()).filter(Boolean);
    if (trimmed.length === 0) {
      errors.push({
        type: 'empty_behavior',
        detail: `feature "${feature.name}" has behavior[] with only empty strings`,
        file: filePath,
        feature: feature.name,
      });
    }
  }

  return { errors, warnings };
}

// ─── Main ─────────────────────────────────────────────────────────────────────

function runPrecommitCheck(fileList) {
  const allErrors = [];
  const allWarnings = [];

  for (const file of fileList) {
    const root = getPolarisRoot();
    const fullPath = join(root, file);

    // ── polaris.json ──────────────────────────────────────────────────────────
    if (file.endsWith('polaris.json')) {
      // New project — polaris.json doesn't exist yet → allow (normal flow)
      if (!existsSync(fullPath)) {
        continue;
      }

      // 1. JSON validity (hard block)
      allErrors.push(...validateJsonStructure(fullPath));

      const { parsed, error } = readJson(fullPath);
      if (error) continue; // already recorded as error above

      // 2. done + test_status pairing (hard block + soft warning)
      const { errors, warnings } = validateDoneFeatures(parsed, file);
      allErrors.push(...errors);
      allWarnings.push(...warnings);

      // 3. behavior[] not all empty (hard block)
      const beh = validateBehavior(parsed, file);
      allErrors.push(...beh.errors);
      allWarnings.push(...beh.warnings);
    }

    // ── PolarSoul.md deletion ─────────────────────────────────────────────────
    if (file.includes('PolarSoul.md')) {
      if (isDeletedInGit(file)) {
        allErrors.push({
          type: 'polarsoul_deleted',
          detail: 'PolarSoul.md is staged for deletion — SSoT root cannot be deleted',
          file,
        });
      }
    }

    // ── capabilities.json ─────────────────────────────────────────────────────
    // No specific pre-commit rule defined; only JSON validity if it appears.
    if (file.endsWith('capabilities.json')) {
      if (!existsSync(fullPath)) {
        continue; // new project — allow
      }
      const { error } = readJson(fullPath);
      if (error) {
        allErrors.push({
          type: 'json_invalid',
          detail: `capabilities.json is not valid JSON: ${error}`,
          file,
        });
      }
    }
  }

  // ── Emit warnings to stderr ──────────────────────────────────────────────────
  for (const w of allWarnings) {
    if (w.feature) {
      console.error(`SSOT WARNING [${w.type}]: ${w.detail}`);
    } else {
      console.error(`SSOT WARNING [${w.type}]: ${w.detail}`);
    }
  }

  // ── Emit errors to stderr and reject ────────────────────────────────────────
  if (allErrors.length > 0) {
    for (const e of allErrors) {
      if (e.feature) {
        console.error(`SSOT ERROR [${e.type}]: ${e.detail}`);
      } else {
        console.error(`SSOT ERROR [${e.type}]: ${e.detail}`);
      }
    }
    process.exit(1);
  }

  process.exit(0);
}

runPrecommitCheck(checkFiles);
