#!/usr/bin/env node

import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, relative } from 'node:path';

const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const strict = args.has('--strict');
const json = args.has('--json');

function parseArg(name) {
  const idx = rawArgs.indexOf(name);
  if (idx < 0 || idx + 1 >= rawArgs.length) return null;
  return rawArgs[idx + 1];
}

const outputFile = parseArg('--output-file');
const root = process.env.POLARISOR_ROOT || join(homedir(), 'Polarisor');

const skipNames = new Set([
  '.git',
  'node_modules',
  'dist',
  'build',
  '.venv',
  'venv',
  '__pycache__',
]);

function readJson(file) {
  try {
    return JSON.parse(readFileSync(file, 'utf-8'));
  } catch (error) {
    return { __parseError: String(error) };
  }
}

function listDirs(dir) {
  try {
    return readdirSync(dir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !skipNames.has(entry.name))
      .map((entry) => join(dir, entry.name));
  } catch {
    return [];
  }
}

function collectPolarisFiles() {
  const files = [];
  for (const projectDir of listDirs(root)) {
    const direct = join(projectDir, 'polaris.json');
    if (existsSync(direct)) files.push(direct);
  }
  return files;
}

function collectBackupDirs() {
  const dirs = [];
  for (const projectDir of [root, ...listDirs(root), join(root, 'PolarCopilot', 'hub')]) {
    const backupDir = join(projectDir, '.planning', '_backup_pre_v2');
    if (existsSync(backupDir)) dirs.push(backupDir);
  }
  return [...new Set(dirs)];
}

function flattenFeatures(project) {
  const features = [];
  for (const requirement of project.requirements || []) {
    for (const feature of requirement.features || []) {
      features.push({ requirement, feature });
    }
  }
  return features;
}

function hasEvidence(feature) {
  const values = [
    feature.evidence,
    feature.tests,
    feature.last_verified_commit,
    feature.last_verified_at,
  ];
  return values.some((value) => {
    if (Array.isArray(value)) return value.some((item) => String(item).trim().length > 0);
    if (value && typeof value === 'object') return Object.keys(value).length > 0;
    return String(value ?? '').trim().length > 0;
  });
}

function hasWeakBehavior(feature) {
  if (!Array.isArray(feature.behavior) || feature.behavior.length === 0) return true;
  const behavior = feature.behavior.map((item) => String(item).trim()).filter(Boolean);
  if (behavior.length === 0) return true;
  if (feature.description && behavior.length === 1 && behavior[0] === String(feature.description).trim()) return true;
  return behavior.some((item) => item.length < 8);
}

function auditProject(file) {
  const project = readJson(file);
  const features = flattenFeatures(project);
  const doneFeatures = features.filter(({ feature }) => feature.status === 'done');
  const missingEvidence = doneFeatures.filter(({ feature }) => !hasEvidence(feature));
  const weakBehavior = features.filter(({ feature }) => hasWeakBehavior(feature));
  const missingContacts = !project.contacts?.last_updated || !project.contacts?.updated_by;

  return {
    file: relative(root, file),
    name: project.name || relative(root, file).split('/')[0],
    parseError: project.__parseError || null,
    requirements: Array.isArray(project.requirements) ? project.requirements.length : 0,
    features: features.length,
    doneFeatures: doneFeatures.length,
    missingEvidence: missingEvidence.length,
    weakBehavior: weakBehavior.length,
    missingContacts,
  };
}

function readTextIfExists(file) {
  try {
    return readFileSync(file, 'utf-8');
  } catch {
    return '';
  }
}

function auditStateConflict() {
  const state = readTextIfExists(join(root, '.planning', 'state.md'));
  const handoff = readTextIfExists(join(root, '致继任者', 'HANDOFF.md'));
  const stateDone = /Milestone 6 完成|32 Phases done/.test(state);
  const handoffPlanning = /Milestone 6 规划中/.test(handoff);
  return {
    stateDone,
    handoffPlanning,
    conflict: stateDone && handoffPlanning,
  };
}

function runAudit() {
  const projects = collectPolarisFiles().map(auditProject);
  const duplicateNames = Object.entries(
    projects.reduce((acc, project) => {
      acc[project.name] = [...(acc[project.name] || []), project.file];
      return acc;
    }, {}),
  ).filter(([, files]) => files.length > 1);

  const backupDirs = collectBackupDirs().map((dir) => ({
    dir: relative(root, dir),
    hasReadme: existsSync(join(dir, 'README.md')),
    fileCount: readdirSync(dir).length,
  }));

  const stateConflict = auditStateConflict();
  const findings = [];

  for (const project of projects) {
    if (project.parseError) findings.push({ severity: 'high', type: 'parse_error', target: project.file, detail: project.parseError });
    if (project.missingContacts) findings.push({ severity: 'medium', type: 'missing_contacts', target: project.file });
    if (project.missingEvidence > 0) findings.push({ severity: 'high', type: 'done_without_evidence', target: project.file, count: project.missingEvidence });
    if (project.weakBehavior > 0) findings.push({ severity: 'medium', type: 'weak_behavior', target: project.file, count: project.weakBehavior });
  }

  for (const [name, files] of duplicateNames) {
    findings.push({ severity: 'medium', type: 'duplicate_project_name', target: name, files });
  }

  for (const backup of backupDirs) {
    if (!backup.hasReadme) findings.push({ severity: 'medium', type: 'backup_without_archive_readme', target: backup.dir });
  }

  if (stateConflict.conflict) {
    findings.push({
      severity: 'high',
      type: 'state_conflict',
      target: '.planning/state.md vs 致继任者/HANDOFF.md',
    });
  }

  return {
    root,
    generatedAt: new Date().toISOString(),
    projects,
    backupDirs,
    stateConflict,
    findings,
  };
}

function printText(result) {
  console.log('SSoT audit');
  console.log(`Root: ${result.root}`);
  console.log(`Projects: ${result.projects.length}`);
  console.log(`Findings: ${result.findings.length}`);
  console.log('');

  for (const project of result.projects) {
    console.log(`- ${project.name} (${project.file})`);
    console.log(`  requirements=${project.requirements} features=${project.features} done=${project.doneFeatures} missingEvidence=${project.missingEvidence} weakBehavior=${project.weakBehavior}`);
  }

  if (result.backupDirs.length > 0) {
    console.log('');
    console.log('Archive backup directories:');
    for (const backup of result.backupDirs) {
      console.log(`- ${backup.dir} readme=${backup.hasReadme ? 'yes' : 'no'} files=${backup.fileCount}`);
    }
  }

  if (result.findings.length > 0) {
    console.log('');
    console.log('Findings:');
    for (const finding of result.findings) {
      const extra = finding.count != null ? ` count=${finding.count}` : '';
      const files = finding.files ? ` files=${finding.files.join(',')}` : '';
      console.log(`- [${finding.severity}] ${finding.type}: ${finding.target}${extra}${files}`);
    }
  }
}

const result = runAudit();
if (json) {
  console.log(JSON.stringify(result, null, 2));
} else {
  printText(result);
}

if (outputFile) {
  const dir = dirname(outputFile);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  writeFileSync(outputFile, JSON.stringify(result, null, 2), 'utf-8');
  console.error(`SSoT audit results written to: ${outputFile}`);
}

if (strict && result.findings.length > 0) {
  process.exitCode = 1;
}
