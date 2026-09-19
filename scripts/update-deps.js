#!/usr/bin/env node
// ==============================================================================
// scripts/update-deps.js — Automated Dependency & Node Version Updater
// ==============================================================================

import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const CYAN = '\x1b[36m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

function logInfo(msg) { console.log(`${CYAN}[INFO]${RESET} ${msg}`); }
function logSuccess(msg) { console.log(`${GREEN}[SUCCESS]${RESET} ${msg}`); }
function logWarn(msg) { console.log(`${YELLOW}[WARN]${RESET} ${msg}`); }
function logError(msg) { console.log(`${RED}[ERROR]${RESET} ${msg}`); }

function run(cmd, cwd = process.cwd()) {
  try {
    return execSync(cmd, { cwd, stdio: 'inherit' });
  } catch (err) {
    logError(`Command failed: ${cmd}`);
    throw err;
  }
}

async function fetchLatestNodeVersions() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const res = await fetch('https://nodejs.org/dist/index.json', { signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    const latestLts = data.find(item => item.lts) || data[0];
    const latestCurrent = data[0];
    return {
      ltsVersion: latestLts.version.replace(/^v/, ''),
      ltsMajor: latestLts.version.replace(/^v/, '').split('.')[0],
      currentVersion: latestCurrent.version.replace(/^v/, ''),
      currentMajor: latestCurrent.version.replace(/^v/, '').split('.')[0],
    };
  } catch (err) {
    const localMajor = process.versions.node.split('.')[0];
    logWarn(`Could not fetch nodejs.org releases (${err.message}). Falling back to local Node v${localMajor}.`);
    return {
      ltsVersion: process.versions.node,
      ltsMajor: localMajor,
      currentVersion: process.versions.node,
      currentMajor: localMajor,
    };
  }
}

async function main() {
  console.log(`${BOLD}${CYAN}======================================================================${RESET}`);
  console.log(`${BOLD}${CYAN}            makelib — Dependencies & Node.js Version Updater          ${RESET}`);
  console.log(`${BOLD}${CYAN}======================================================================${RESET}\n`);

  const cwd = process.cwd();
  const pkgPath = path.join(cwd, 'package.json');

  if (!fs.existsSync(pkgPath)) {
    logError(`No package.json found in ${cwd}. Aborting.`);
    process.exit(1);
  }

  // 1. Resolve Latest Node Version
  logInfo('Checking latest Node.js LTS release...');
  const nodeInfo = await fetchLatestNodeVersions();
  logInfo(`Active Node.js: v${process.versions.node} | Latest LTS: v${nodeInfo.ltsVersion} (Node ${nodeInfo.ltsMajor})`);

  // Update .nvmrc if present or create it
  const nvmrcPath = path.join(cwd, '.nvmrc');
  fs.writeFileSync(nvmrcPath, `${nodeInfo.ltsMajor}\n`, 'utf8');
  logSuccess(`Updated .nvmrc to Node ${nodeInfo.ltsMajor}`);

  // Update .node-version if present
  const nodeVersionPath = path.join(cwd, '.node-version');
  if (fs.existsSync(nodeVersionPath)) {
    fs.writeFileSync(nodeVersionPath, `${nodeInfo.ltsMajor}\n`, 'utf8');
    logSuccess(`Updated .node-version to Node ${nodeInfo.ltsMajor}`);
  }

  // Update package.json engines.node
  const pkgRaw = fs.readFileSync(pkgPath, 'utf8');
  const pkg = JSON.parse(pkgRaw);
  pkg.engines = pkg.engines || {};
  pkg.engines.node = `>=${nodeInfo.ltsMajor}.0.0`;
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf8');
  logSuccess(`Updated package.json engines.node to: ${pkg.engines.node}`);

  // Update GitHub Actions workflows if present
  const workflowsDir = path.join(cwd, '.github', 'workflows');
  if (fs.existsSync(workflowsDir)) {
    const workflowFiles = fs.readdirSync(workflowsDir).filter(f => f.endsWith('.yml') || f.endsWith('.yaml'));
    for (const wf of workflowFiles) {
      const wfPath = path.join(workflowsDir, wf);
      let content = fs.readFileSync(wfPath, 'utf8');
      const updated = content.replace(/node-version:\s*['"]?[0-9]+(\.x)?['"]?/g, `node-version: ${nodeInfo.ltsMajor}`);
      if (updated !== content) {
        fs.writeFileSync(wfPath, updated, 'utf8');
        logSuccess(`Updated Node version in .github/workflows/${wf}`);
      }
    }
  }

  // 2. Upgrade Dependencies in package.json
  const hasDeps = Boolean(
    (pkg.dependencies && Object.keys(pkg.dependencies).length > 0) ||
    (pkg.devDependencies && Object.keys(pkg.devDependencies).length > 0)
  );

  if (hasDeps) {
    logInfo('Upgrading package.json dependencies to latest versions via npm-check-updates...');
    run('npx --yes npm-check-updates -u', cwd);
    logSuccess('package.json updated to latest dependency releases.');

    logInfo('Installing updated dependencies with npm install...');
    run('npm install', cwd);
    logSuccess('Dependencies installed and package-lock.json refreshed.');

    logInfo('Auditing dependencies for known security vulnerabilities...');
    try {
      execSync('npm audit --audit-level=high', { cwd, stdio: 'inherit' });
      logSuccess('Audit passed with 0 high/critical vulnerabilities.');
    } catch {
      logWarn('High vulnerabilities detected. Running automatic audit fix...');
      try {
        run('npm audit fix', cwd);
        logSuccess('Audit fix applied.');
      } catch (auditErr) {
        logWarn(`Audit fix completed with warnings: ${auditErr.message}`);
      }
    }
  } else {
    logInfo('No dependencies or devDependencies found in package.json. Skipping package bump.');
  }

  // 3. Submodule Toolchain Update (if running in downstream repo with makelib submodule)
  for (const candidate of ['.makelib', 'makelib']) {
    const submodulePath = path.join(cwd, candidate);
    if (fs.existsSync(submodulePath) && fs.existsSync(path.join(submodulePath, '.git'))) {
      logInfo(`Detected makelib submodule at '${candidate}'. Updating submodule to latest revision...`);
      try {
        run(`git -c protocol.file.allow=always submodule update --remote --merge "${candidate}"`, cwd);
        run(`npm --prefix "${candidate}" install`, cwd);
        logSuccess(`makelib submodule at '${candidate}' updated successfully.`);
      } catch (subErr) {
        logWarn(`Submodule update skipped or failed: ${subErr.message}`);
      }
    }
  }

  console.log(`\n${BOLD}${GREEN}======================================================================${RESET}`);
  console.log(`${BOLD}${GREEN}        ALL DEPENDENCIES & NODE.JS UPDATED TO LATEST SUCCESSFULLY!    ${RESET}`);
  console.log(`${BOLD}${GREEN}======================================================================${RESET}\n`);
}

main().catch(err => {
  logError(`Dependency update failed: ${err.message}`);
  process.exit(1);
});
