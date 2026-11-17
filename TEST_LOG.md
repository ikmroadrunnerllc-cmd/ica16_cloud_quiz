# ICA16 test log

Device tests have not been run. Replace “Not run” only after observing the result.
Record the device, app version, Firebase project, date, commit hash, and evidence
filename. Emulator evidence is separate from deployed-project evidence.

| ID | Precondition and action | Expected | Observed | Pass | Ref |
| --- | --- | --- | --- | --- | --- |
| T01 | Signed out; use bad password, then valid credentials | Auth error, then signed-in UID | Not run | Pending | |
| T02 | Signed in; normal request | Ten valid, decoded questions | Not run | Pending | |
| T03 | Select bad JSON, api code 5, or nine results; restart for each | Request blocked with Retry | Not run | Pending | |
| T04 | Play; choose correct, wrong, and double-tap an answer | Green/red feedback, at most one point per question | Not run | Pending | |
| T05 | Finish ten questions; review and replay | Ten review entries and a new round ID | Not run | Pending | |
| T06 | Submit an attempt; double-tap submit | One document and a matching server read | Not run | Pending | |
| T07 | Copy a verified round ID; restart, sign in, and use Open saved attempt | Original attempt read from server | Not run | Pending | |
| T08 | Submit offline, then reconnect and reconcile | No false success; same ID retained | Not run | Pending | |
| T09 | Select lost ack, submit, then reconcile | Save unknown, then verified; one document | Not run | Pending | |
| T10 | Use user B's client credentials against user A's path | Read and write denied | Not run on device; emulator isolation check passed | Pending device check | Local rules suite |
| T11 | Use a client to create score 11/extra fields or update an attempt | Rejected by rules | Emulator validation/update checks passed | Pending device check | Local rules suite |
| T12 | Select unavailable and quota; submit each, then reconcile | Distinct codes, no false success | Not run | Pending | |
| G01 | Two clients submit identical values with one chosen ID concurrently | One immutable document; other transaction reuses it | Not run | Pending | |
| G02 | Two clients use one ID with different valid scores | Collision; original document preserved | Not run | Pending | |
| G03 | Select stale response; submit, then sign in as another user | Old response cannot change the new user's screen | Not run | Pending | |

T11 must use a client SDK, REST client authenticated as a test user, or an emulator
rules test. Firebase Console and Admin SDK writes use privileged access and do not
test client security rules. The local suite also admin-seeds an invalid document
and checks that an ordinary owner client cannot read it.

## Observed local validation

Date: 2026-11-16.

- Fresh results for this project: [local-rules-tests.txt](evidence/local-rules-tests.txt).
- Ran the cached Firestore emulator v1.22.0 with Standard edition, Native mode,
  project `demo-ica16-local`, and this project's `firestore.rules`.
- `python test/firestore_rules_test.py`: 8 test methods passed. The tests include
  multiple invalid-schema and authorization subcases.
- Confirmed owner create, later owner read, and owner get of a missing document.
- Confirmed rejection of cross-user/unauthenticated access, malformed fields,
  extra fields, invalid ranges, updates, deletes, forged timestamps, collection
  listing, unknown paths, and reads of an invalid admin-seeded record.
- Dart formatting parsed the source successfully.
- Flutter package resolution, full static analysis of this Firebase version,
  Flutter tests, device execution, live rule deployment, and APK build remain
  pending. The environment blocks the installed SDK cache and external package
  downloads; the requested older Firebase packages are not cached.

These results do not establish that T01–T12 or G01–G03 passed on a device.

## Deployment evidence

Firebase project ID: `ica16-cloud-quiz-ceab96`

Rules deployment command:
```powershell
npx -y firebase-tools@latest deploy --only auth,firestore:rules --project ica16-cloud-quiz-ceab96
```

Deployment output:
```
=== Deploying to 'ica16-cloud-quiz-ceab96'...

i  deploying firestore, auth
i  firestore: ensuring required API firestore.googleapis.com is enabled...
+  firestore: required API firestore.googleapis.com is enabled
i  cloud.firestore: checking firestore.rules for compilation errors...
+  cloud.firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
Enabling auth providers: email/password...
+  Auth providers enabled: email/password
+  firestore: released rules firestore.rules to cloud.firestore

+  Deploy complete!

Project Console: https://console.firebase.google.com/project/ica16-cloud-quiz-ceab96/overview
```

Commit hash: `edeffa1` (prior to setup completion updates)

Release APK build:
```powershell
flutter build apk --release
```
Output:
```
Running Gradle task 'assembleRelease'...
√ Built build\app\outputs\flutter-apk\app-release.apk (50.2MB)
Copied to: evidence/ICA16_A_MarioGutierrez.apk (52,668,121 bytes)
```
