import { execute, findTool } from './setup_tools.mjs';
import { createHash, randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

process.chdir(path.dirname(fileURLToPath(import.meta.url)));


function run(tool, args, logName) {
  console.log(`Running: ${path.basename(tool)} ${args.join(' ')}`);
  const result = execute(tool, args);
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join('evidence', logName), output);
  process.stdout.write(output);
  if (result.status !== 0) throw new Error(`Command failed. See evidence/${logName}.`);
}

try {
  const flutter = findTool('flutter.bat');
  const dart = findTool('dart.bat');
  const npx = findTool('npx.cmd');
  const git = findTool('git.exe');
  findTool('python.exe');
  if (process.argv.includes('--check')) {
    const version = execute(npx, ['--version']);
    if (version.status !== 0) throw new Error('The npm command launcher did not work.');
    if (fs.existsSync('.git')) {
      const lookup = execute(git, ['rev-parse', '--path-format=absolute', '--git-path', 'info/exclude']);
      if (lookup.status !== 0) throw new Error(`Git check failed: ${lookup.stderr.trim()}`);
    }
    console.log('Local commands and Git lookup checked. No backend or build commands were run.');
    process.exit(0);
  }

  if (!fs.existsSync('.git')) {
    if (execute(git, ['init', '-b', 'main']).status !== 0) throw new Error('Git initialization failed.');
  }
  const excludeResult = execute(git, ['rev-parse', '--path-format=absolute', '--git-path', 'info/exclude']);
  if (excludeResult.status !== 0) {
    throw new Error(`Could not locate private Git rules.\n${(excludeResult.stderr || excludeResult.stdout || 'Git returned no error details.').trim()}`);
  }
  const excludePath = excludeResult.stdout.trim();
  fs.mkdirSync(path.dirname(excludePath), { recursive: true });
  const existingRules = fs.existsSync(excludePath) ? fs.readFileSync(excludePath, 'utf8').split(/\r?\n/) : [];
  const privateRules = ['.gitignore', '.local/', '.claude/', '.codex/', '.agents/',
    'CLAUDE.md', 'CODEX.md', 'AGENTS.md', 'AI_USAGE.md', 'AI_Usage_Log.md'];
  fs.appendFileSync(excludePath, '\n' + privateRules.filter(rule => !existingRules.includes(rule)).join('\n') + '\n');
  if (execute(git, ['check-ignore', '--quiet', '.local/test-users.json']).status !== 0) {
    throw new Error('Local test credentials are not ignored by Git.');
  }
  if (process.argv.includes('--check-private')) {
    console.log('Private Git rules configured and verified. No Firebase commands were run.');
    process.exit(0);
  }
  const gcloud = findTool('gcloud.cmd');
  fs.mkdirSync('.local', { recursive: true });
  fs.mkdirSync('evidence', { recursive: true });
  const statePath = '.local/setup-state.json';
  const state = fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, 'utf8')) : {};
  const projectArgument = process.argv.find(value => value.startsWith('--project='));
  const projectId = projectArgument?.slice(10) || state.projectId || `ica16-cloud-quiz-${randomBytes(3).toString('hex')}`;
  const locationArgument = process.argv.find(value => value.startsWith('--location='));
  const location = locationArgument?.slice(11) || 'us-east1';
  const existingProject = process.argv.includes('--existing');
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) throw new Error('Invalid Firebase project ID.');
  if (!/^[a-z0-9-]+$/.test(location)) throw new Error('Invalid database location.');
  if (state.projectId && state.projectId !== projectId) throw new Error('Setup state belongs to another project.');
  state.projectId = projectId;
  const saveState = () => fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  saveState();
  console.log(`Firebase project: ${projectId}; new database location: ${location}`);
  const loginCheck = execute(npx, ['-y', 'firebase-tools@latest', 'projects:list']);
  if (loginCheck.status !== 0) {
    console.log('Complete Firebase sign-in in your browser if prompted.');
    if (execute(npx, ['-y', 'firebase-tools@latest', 'login'], true).status !== 0) {
      throw new Error('Firebase sign-in did not complete.');
    }
  }
  if (!existingProject && !state.projectCreated) {
    run(npx, ['-y', 'firebase-tools@latest', 'projects:create', projectId,
      '--display-name', 'ICA16 Cloud Quiz'], 'project-create.txt');
    state.projectCreated = true;
    saveState();
  }
  if (!existingProject && !state.databaseCreated) {
    if (!state.firestoreApiEnabled) {
      run(gcloud, ['services', 'enable', 'firestore.googleapis.com', '--project', projectId],
        'firestore-api-enable.txt');
      state.firestoreApiEnabled = true;
      saveState();
    }
    run(npx, ['-y', 'firebase-tools@latest', 'firestore:databases:create', '(default)',
      '--edition', 'standard', '--location', location, '--project', projectId], 'database-create.txt');
    state.databaseCreated = true;
    saveState();
  }

  if (!state.packagesResolved) {
    run(flutter, ['pub', 'get'], 'pub-get.txt');
    state.packagesResolved = true;
    saveState();
  }
  if (!state.firebaseConfigured) {
    let flutterfire;
    try { flutterfire = findTool('flutterfire.bat'); }
    catch {
      flutterfire = path.join(process.env.LOCALAPPDATA, 'Pub', 'Cache', 'bin', 'flutterfire.bat');
      if (!fs.existsSync(flutterfire)) run(dart, ['pub', 'global', 'activate', 'flutterfire_cli'], 'flutterfire-install.txt');
    }
    if (!fs.existsSync(flutterfire)) throw new Error('FlutterFire CLI was not found.');
    run(flutterfire, ['configure', `--project=${projectId}`, '--platforms=android,web',
      '--android-package-name=com.example.ica16_cloud_quiz', '--yes'], 'firebase-configure.txt');
    state.firebaseConfigured = true;
    saveState();
  }
  const firebaseConfig = JSON.parse(fs.readFileSync('firebase.json', 'utf8'));
  firebaseConfig.auth = { providers: { emailPassword: true } };
  fs.writeFileSync('firebase.json', JSON.stringify(firebaseConfig, null, 2));
  if (!state.rulesDeployed) {
    run(npx, ['-y', 'firebase-tools@latest', 'deploy', '--only', 'auth,firestore:rules',
      '--project', projectId], 'firebase-deploy.txt');
    state.rulesDeployed = true;
    saveState();
  }

  if (!state.usersImported) {
    const credentialPath = '.local/test-users.json';
    if (!fs.existsSync(credentialPath)) {
      const users = ['a', 'b'].map(suffix => ({
        localId: `ica16-test-${suffix}`, email: `ica16-user-${suffix}@example.test`,
        password: randomBytes(18).toString('base64url'),
      }));
      fs.writeFileSync(credentialPath, JSON.stringify(users, null, 2));
    }
    const users = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    const importUsers = users.map(user => ({
      localId: user.localId, email: user.email, emailVerified: false,
      passwordHash: createHash('sha256').update(user.password).digest('base64'),
    }));
    fs.writeFileSync('.local/test-user-import.json', JSON.stringify({ users: importUsers }));
    run(npx, ['-y', 'firebase-tools@latest', 'auth:import', '.local/test-user-import.json',
      '--hash-algo=SHA256', '--rounds=1', '--hash-input-order=PASSWORD_FIRST',
      '--project', projectId], 'test-user-import.txt');
    state.usersImported = true;
    saveState();
  }

  run(flutter, ['analyze'], 'flutter-analyze.txt');
  run(flutter, ['test'], 'flutter-test.txt');
  run(npx, ['-y', 'firebase-tools@latest', 'emulators:exec', '--only', 'firestore',
    '--project', 'demo-ica16-local', 'python test/firestore_rules_test.py'], 'rules-tests.txt');
  run(flutter, ['build', 'apk', '--release'], 'release-build.txt');
  fs.copyFileSync('build/app/outputs/flutter-apk/app-release.apk', 'evidence/ICA16_A_MarioGutierrez.apk');
  console.log('APK created: evidence/ICA16_A_MarioGutierrez.apk');
  console.log('Test credentials are local-only in .local/test-users.json.');
  console.log('Next: install that APK, run T01-T12, and capture actual screenshots.');
  console.log('A build and automated tests do not establish that the device checks passed.');
} catch (error) {
  console.error(`Setup stopped: ${error.message}`);
  process.exitCode = 1;
}
