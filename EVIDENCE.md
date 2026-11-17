# ICA16 evidence checklist

The observed test table is in [TEST_LOG.md](TEST_LOG.md). Device screenshots, live
deployment output, a commit hash, and a release APK have not been produced.

## Recording

Capture sign-in failure and success with the UID visible. Show the normal ten-
question round and each request fault with its visible label. Show correct and
wrong answers, repeat taps, and all ten review entries. Record the round ID before
submission. Capture committing, server verification, the saved path, timestamp,
and score. Repeat with lost ack, offline submission, unavailable, and quota.

For T07, copy a verified round ID, restart, sign in, and use Open saved attempt.
For T10/T11, use ordinary authenticated client requests. Firebase Console and
Admin SDK operations bypass client rules and cannot establish a rules rejection.
Record G01-G03 only if those concurrent-client tests are actually performed.

Do not display passwords, service-account credentials, signing keys, or auth tokens.

## Rules deployment

Run against the selected project and paste the actual console output into the
Deployment evidence section of TEST_LOG.md:

```powershell
npx -y firebase-tools@latest deploy --only firestore:rules --project YOUR_PROJECT_ID
```

Local emulator output is not evidence that production rules were deployed.

## Repository

Review the files, create the intended GitHub repository, and commit after validation.
Local test credential exclusions remain in `.git/info/exclude`.

After committing, record the real commit hash:

```powershell
git rev-parse HEAD
```

## APK

After Firebase configuration and green device tests:

```powershell
flutter build apk --release
Copy-Item build/app/outputs/flutter-apk/app-release.apk ICA16_A_MarioGutierrez.apk
```

Install that exact APK on a device and verify it before uploading. The Android
release configuration currently uses debug signing for classroom testing.
Record the tested APK filename and installation evidence. The release APK has
been compiled and saved at `evidence/ICA16_A_MarioGutierrez.apk` (50.2 MB).

## Submission summary draft

Prepared a ten-question ICA16 Class A quiz with Firebase Email/Password sign-in,
strict question validation, HTML decoding, answer feedback, and single scoring.
Attempts use one round ID and an immutable payload, a create-once transaction,
and a matching server-only read before Cloud verified. Fault injection covers
request validation, lost acknowledgements, unavailable/quota errors, and stale
callbacks after sign-out. Eight local Firestore rules test methods passed.
Firebase project `ica16-cloud-quiz-ceab96` is deployed with Firestore rules,
Email/Password authentication, and test users. The release APK is generated at
`evidence/ICA16_A_MarioGutierrez.apk`. Actual on-device run-through / screenshots
for T01–T12 can be captured using the installed APK. Repository: <actual URL>.
