# ICA16 Class A - Cloud Quiz

Flutter quiz using Open Trivia Database, Firebase Email/Password Authentication,
and create-once Cloud Firestore attempts. The project folder and Dart package
remain named `ica16_cloud_quiz`.

## Current status

The ICA16 source, Firebase rules, configuration, tests, and documentation are
prepared. Eight local Firestore emulator test methods passed. Firebase project
`ica16-cloud-quiz-ceab96`, its Standard/Native Firestore database, Firebase
configuration, Email/Password provider, and Firestore rules are set up. Dependency
resolution completed. Test-user import, Flutter analysis/tests, device testing,
and a release build are still pending. Do not reuse the previous five-question
app's analysis result as evidence for this version. `pubspec.lock` was generated
by the successful dependency resolution and should be included in the project.

## Finish setup from your normal terminal

The assistant environment cannot download the missing packages or write to the
installed Flutter SDK cache. Run the prepared setup script outside that restricted
session, from this project folder:

```powershell
node Complete-Setup.mjs
```

Keep `Complete-Setup.mjs` and `setup_tools.mjs` together. The setup helper uses
project-specific Git trust for its commands so a folder created by an isolated
Windows account can be used from your normal account. It does not modify global
Git trust settings. The ownership regression tests and local privacy check passed:

```powershell
node --test test/setup_tools.test.mjs
node Complete-Setup.mjs --check-private
```

The script resumes setup for the project above. It creates two test users, then
runs analysis and tests and builds `evidence/ICA16_A_MarioGutierrez.apk`.
It stops on failed commands and saves their output under `evidence/`.
It does not change PowerShell execution policy or machine security settings.

Test passwords are saved only in `.local/test-users.json`, which the script
excludes through local Git rules before creating it. Setup state lets the script
resume the same project. For an existing configured project, use:

```powershell
node Complete-Setup.mjs --project=YOUR_PROJECT_ID --existing
```

For a different new-database region, pass `--location=REGION`. An existing-project
run assumes its Firestore database already exists. The script's syntax, local
tool discovery, and command launcher have been checked. Its cloud setup and build
cloud setup has completed through Firebase deployment. Installing the APK,
collecting actual device screenshots, and filling T01-T12 remain required.

## Connect Firebase and run

Run these commands from this folder on your computer:

```powershell
flutter pub get
npx -y firebase-tools@latest login
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_PROJECT_ID --platforms android,web
npx -y firebase-tools@latest deploy --only firestore:rules --project YOUR_PROJECT_ID
flutter analyze
flutter test
flutter clean
flutter run
```

Use a Firebase project with Firestore **Standard edition, Native mode** and
Email/Password authentication enabled. Create two test users in Firebase
Authentication. Keep their passwords out of the repository. There is no signup
screen in this assignment app.

`flutterfire configure` generates the real `lib/firebase_options.dart` for the
selected project. The included version accepts explicit Dart-defined client
configuration and otherwise shows a setup message. It contains no made-up live
project configuration. FlutterFire should replace it before a production run.

Commit the generated public client configuration: `firebase_options.dart`,
`google-services.json`, and `GoogleService-Info.plist` when applicable. Service
accounts, signing files, and environment secrets remain ignored. Local private
rules also exclude assistant tooling and `.gitignore` files; these rules are not
pushed and must be reapplied in another clone.

## Files

- `lib/main.dart`: starts the app.
- `lib/ica16_app.dart`: Firebase startup, sign-in, quiz screens, and recovery.
- `lib/question.dart`: HTML decoding and question/round validation.
- `lib/attempt_repository.dart`: create-once transaction and server read-back.
- `firestore.rules`: owner-only, create-only attempt permissions.
- `firebase.json`: rules path and local emulator settings.
- `HOW_IT_WORKS.md`: plain-language code walkthrough.
- `WRITTEN_ANSWERS.md`: six answers, with pending evidence identified honestly.
- `TEST_LOG.md`: T01-T12 and optional G01-G03 evidence checklist.
- `EVIDENCE.md`: recording, deployment, and APK checklist.

The application Dart source contains no comments. It uses ordinary classes,
conditions, loops, and small methods. The extra states are needed to distinguish
an uncertain write from a verified saved attempt.

## Cloud contract

`users/{uid}/attempts/{roundId}` contains exactly:

| Field | Value |
| --- | --- |
| schemaVersion | integer 1 |
| variant | string A |
| categoryId | integer 9 |
| questionCount | integer 10 |
| correctCount | integer 0 through 10 |
| submittedAt | server timestamp |

The ID comes from `attempts.doc().id` once per round. The payload is frozen after
the tenth answer. A transaction creates the document only if it is missing,
reuses a matching existing attempt, and reports a collision for different data.
Success requires one `Source.server` read with matching fields, a resolved
timestamp, and no pending writes or cache-only metadata.

The supplied rules were corrected: `submittedAt == request.time` is checked only
on create, not on later reads. Owners can get a missing path so transactions can
check for absence. Updates, deletes, and collection-list queries are denied.
A privileged Console/Admin SDK write bypasses client rules; T11 uses a client.

## Fault demonstrations

Use the bug menu. The selected fault is displayed above the quiz.

- Bad JSON, api code 5, and nine results: select, then use Restart round.
- Lost ack: finish a round, select, submit, and reconcile the same ID.
- Unavailable and quota: injected before a transaction; display distinct codes.
  Switch to none, reconcile, then retry the same ID if the server reports missing.
- Stale response: submit; after the transaction, the app signs out and resumes an
  old callback five seconds later. Session guards discard that old result.

Faults are deliberate simulations and are labeled. A real offline test still
requires airplane mode. Network requests and submissions have timeouts. Request
retry waits five seconds; retries are user-triggered. OpenTDB can repeat questions
because this app does not use session tokens.

## Reopen an attempt

Copy the full round ID from the review or verified screen. After restarting and
signing in, use the history icon and paste that ID. The app reads that user's
attempt from the server and validates it before showing the saved score. It does
not list every attempt or persist an unfinished round locally. Keep the ID before
closing during an unresolved write.

## Local emulator rules tests

Python 3 and Java are needed for the optional rules test suite. No Python or Node
packages need to be installed for the test itself.

```powershell
npx -y firebase-tools@latest emulators:exec --only firestore --project demo-ica16-local "python test/firestore_rules_test.py"
```

The suite uses unsigned emulator-only identity tokens. It is guarded to require
`FIRESTORE_EMULATOR_HOST` and uses a demo project, not a production database.

To run the app against Auth and Firestore emulators:

```powershell
npx -y firebase-tools@latest emulators:start --only auth,firestore --project demo-ica16-local
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The demo configuration is explicitly emulator-only. Create test accounts with
the Auth emulator REST API before signing in. The emulator UI is disabled by
this configuration. Android emulator host defaults to `10.0.2.2`; a physical device
needs a reachable emulator host supplied with `--dart-define=FIREBASE_EMULATOR_HOST=...`
and appropriate emulator binding. The screen labels emulator use. OpenTDB still
needs an internet connection.

## Limits

Scoring is client-side. Rules cannot prove that an in-range score was earned.
There is no shared ranking, server scoring, auto-retry loop, or saved local round.
A timeout does not cancel an already-started transaction, which is why retries
preserve the same ID. Emulator tests do not replace the device evidence checklist.

## References

- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Firestore rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Open Trivia Database API and CC BY-SA 4.0 data license](https://opentdb.com/api_config.php)
