import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export function findTool(name) {
  const folders = [process.env.Path, process.env.PATH].filter(Boolean).join(';').split(';');
  for (const folder of folders) {
    const candidate = path.join(folder.replace(/^"|"$/g, ''), name);
    if (fs.existsSync(candidate)) return candidate;
  }
  if (/^(flutter|dart)\.bat$/.test(name) && process.env.USERPROFILE) {
    const candidate = path.join(process.env.USERPROFILE, 'flutter', 'bin', name);
    if (fs.existsSync(candidate)) return candidate;
  }
  const result = spawnSync('where.exe', [name], { encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Required command missing: ${name}`);
  return result.stdout.trim().split(/\r?\n/)[0];
}

export function execute(tool, args, interactive = false) {
  let command = tool;
  let parameters = args;
  if (/^git(?:\.exe)?$/i.test(path.basename(tool))) {
    parameters = ['-c', `safe.directory=${process.cwd().replaceAll('\\', '/')}`, ...args];
  }
  const batchFile = /\.(cmd|bat)$/i.test(tool);
  if (batchFile) {
    for (const value of [tool, ...args]) {
      if (/[%!&|<>^"\r\n]/.test(value)) throw new Error('Unsupported shell argument.');
    }
    command = process.env.ComSpec || 'C:\\Windows\\System32\\cmd.exe';
    parameters = ['/d', '/s', '/c', `"${[tool, ...args].map(value => `"${value}"`).join(' ')}"`];
  }
  const result = spawnSync(command, parameters, {
    encoding: 'utf8',
    stdio: interactive ? 'inherit' : 'pipe',
    maxBuffer: 64 * 1024 * 1024,
    windowsHide: true,
    windowsVerbatimArguments: batchFile,
  });
  if (result.error) throw result.error;
  return result;
}
