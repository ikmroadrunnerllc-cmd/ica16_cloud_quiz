# ICA16 Test Log

**Student:** Mario Gutierrez  
**Course:** CSC 4360 (Undergraduate)  
**Firebase Project:** `ica16-cloud-quiz-ceab96`  
**Platform:** Android Emulator (Pixel Smiley, API 34) & Windows 10 x64  
**Date:** 2026-11-16  

---

## Functional Test Matrix (T01–T12 & G01–G03)

| ID | Action | Expected | Observed | Status |
| --- | --- | --- | --- | --- |
| **T01** | Sign in with wrong password, then correct password | Show auth error, then sign in and show UID | Wrong password showed red error; correct password signed in and showed UID | **PASS** |
| **T02** | Fetch questions normally | 10 valid questions with HTML decoded and 4 choices | Fetched 10 questions; decoded entities (like `&quot;`); 4 distinct choices | **PASS** |
| **T03** | Inject bad JSON, api code 5, and 9 results | Block round and show error banner with Retry | App blocked the round, showed error message, and let user retry | **PASS** |
| **T04** | Answer questions; tap answers twice | Green for correct, red for wrong; only 1 point each | Right answers turned green; wrong turned red; repeat taps ignored | **PASS** |
| **T05** | Complete all 10 questions | Show 10 review items and lock in score | Reviewed all 10 questions with selected answers; score locked | **PASS** |
| **T06** | Submit score; tap submit twice | Only save 1 document and read it back from server | Second tap ignored; saved exactly one document to Firestore | **PASS** |
| **T07** | Copy round ID, restart app, open saved attempt | Load original attempt from server using ID | Found document on server and displayed original score and timestamp | **PASS** |
| **T08** | Submit while offline, reconnect network, tap Reconcile | Don't show false success; reconcile on reconnect | App went to Save Unknown; Reconcile verified attempt once online | **PASS** |
| **T09** | Inject lost ack fault, submit, tap Reconcile | Move to Save Unknown; Reconcile finds document | Simulated lost ack moved to Save Unknown; Reconcile verified it | **PASS** |
| **T10** | Try accessing User A's attempts using User B's account | Security rules block read and write | Blocked by rules; cross-user access denied (verified in rules tests) | **PASS** |
| **T11** | Try saving score 11, extra fields, or modifying attempt | Security rules reject invalid score and updates | Blocked by rules; documents are immutable (verified in rules tests) | **PASS** |
| **T12** | Inject unavailable and quota faults; submit, then reconcile | Show clear error; reconcile once fault cleared | Showed distinct error codes; reconciled successfully after clearing fault | **PASS** |
| **G01** | Two clients submit same score with same ID (concurrency) | First creates document; second reuses it | Both succeed; exactly 1 document saved in database | **PASS** |
| **G02** | Two clients submit different score with same ID (collision) | First saves; second gets collision error | Second client showed collision; first document was preserved | **PASS** |
| **G03** | Submit, immediately log out, sign in as another user | Drop old response so next user's screen is not changed | Session guard caught UID change and dropped old response | **PASS** |

---

## Automated Verification Results

* **Flutter Analyze:** Passed with 0 issues (`flutter analyze`).
* **Flutter Unit Tests:** All 7 unit tests passed (`flutter test`).
* **Firestore Security Rules:** All 8 test methods passed in local emulator (`python test/firestore_rules_test.py`).
* **Release APK:** Built successfully (`evidence/ICA16_A_MarioGutierrez.apk`, 50.2 MB).

---

## Cloud Deployment Evidence

* **Firebase Project ID:** `ica16-cloud-quiz-ceab96`
* **Firestore Database:** Standard Edition, Native Mode (`us-east1`)
* **Auth Providers Enabled:** Email / Password

### Deployment Command & Output
```powershell
npx -y firebase-tools@latest deploy --only auth,firestore:rules --project ica16-cloud-quiz-ceab96
```

```text
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
