import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { execute, findTool } from '../setup_tools.mjs';

function isolateGit(folder) {
  const keys = ['GIT_CONFIG_COUNT', 'GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL'];
  const saved = keys.map(key => [key, process.env[key]]);
  const config = path.join(folder, 'test-global-config');
  fs.writeFileSync(config, '');
  process.env.GIT_CONFIG_COUNT = '0';
  process.env.GIT_CONFIG_NOSYSTEM = '1';
  process.env.GIT_CONFIG_GLOBAL = config;
  return () => {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
}

test('private Git lookup works for a project owned by another account', () => {
  const originalDirectory = process.cwd();
  const temporaryRoot = path.resolve('.tmp');
  fs.mkdirSync(temporaryRoot, { recursive: true });
  const project = fs.mkdtempSync(path.join(temporaryRoot, 'git-owner-'));
  const oldAssumption = process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER;
  const git = findTool('git.exe');
  const restoreGit = isolateGit(project);
  const previousGlobal = spawnSync(git, ['config', '--global', '--get-all', 'safe.directory'], { encoding: 'utf8' });
  try {
    assert.equal(spawnSync(git, ['init', '-b', 'main', project]).status, 0);
    process.chdir(project);
    process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER = '1';
    const refused = spawnSync(git, ['-c', 'safe.directory=', 'rev-parse', '--git-path', 'info/exclude'], { encoding: 'utf8' });
    assert.equal(refused.status, 128);
    assert.match(refused.stderr, /dubious ownership/);
    const result = execute(git, ['rev-parse', '--path-format=absolute', '--git-path', 'info/exclude']);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(path.resolve(result.stdout.trim()), path.join(project, '.git', 'info', 'exclude'));
    const currentGlobal = spawnSync(git, ['config', '--global', '--get-all', 'safe.directory'], { encoding: 'utf8' });
    assert.equal(currentGlobal.stdout, previousGlobal.stdout);
    assert.equal(currentGlobal.status, previousGlobal.status);
  } finally {
    process.chdir(originalDirectory);
    if (oldAssumption === undefined) delete process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER;
    else process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER = oldAssumption;
    restoreGit();
    assert.equal(path.dirname(path.resolve(project)), temporaryRoot);
    fs.rmSync(project, { recursive: true, force: true });
  }
});

test('project trust does not extend to a different repository', () => {
  const originalDirectory = process.cwd();
  const temporaryRoot = path.resolve('.tmp');
  fs.mkdirSync(temporaryRoot, { recursive: true });
  const sibling = fs.mkdtempSync(path.join(temporaryRoot, 'git-sibling-'));
  const oldAssumption = process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER;
  const git = findTool('git.exe');
  const restoreGit = isolateGit(sibling);
  try {
    assert.equal(spawnSync(git, ['init', '-b', 'main', sibling]).status, 0);
    process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER = '1';
    const result = execute(git, ['-C', sibling, 'rev-parse', '--git-path', 'info/exclude']);
    assert.equal(result.status, 128);
    assert.match(result.stderr, /dubious ownership/);
  } finally {
    if (oldAssumption === undefined) delete process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER;
    else process.env.GIT_TEST_ASSUME_DIFFERENT_OWNER = oldAssumption;
    restoreGit();
    process.chdir(originalDirectory);
    assert.equal(path.dirname(path.resolve(sibling)), temporaryRoot);
    fs.rmSync(sibling, { recursive: true, force: true });
  }
});
