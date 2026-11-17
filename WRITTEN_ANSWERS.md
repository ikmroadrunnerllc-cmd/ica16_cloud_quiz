# ICA16 Written Answers

## 1. Two success layers

Just getting an HTTP status 200 does not mean the quiz data is good. Open Trivia DB can send an HTTP 200 even when there is an error, like response code 5 (rate limit) or response code 1 (no questions found). 

So the app checks two layers:
1. **Network Layer:** Makes sure the HTTP status code is 200.
2. **Data Layer:** Parses the JSON and checks that `response_code == 0`, that there are exactly 10 questions, and that each question has 4 non-empty choices after decoding HTML entities (like `&quot;`). If any check fails, the round stops and asks to retry.

## 2. Unknown is not failed

A timeout or lost connection does not mean the save failed. The server might have saved the attempt, but our phone just never got the confirmation back.

If we just treated that as a failure, the user might submit again and create duplicate records. Instead, the app moves to a **Save Unknown** screen. It keeps the current round ID and score, and shows a **Reconcile** button. Tapping Reconcile checks Firestore directly from the server. If the document is there, it marks it verified without writing a duplicate.

## 3. Retry identity

When a quiz round starts, the app generates one unique round ID. When the user finishes question 10, the score is locked in.

If the user has to retry submitting, the app uses that exact same round ID and score. In Firestore, a transaction checks the document path first:
- If the document does not exist, it creates it.
- If it already exists with the same score, it reuses it.
- If it exists with a different score, it shows a collision error.

This makes retrying safe and stops duplicates.

## 4. Cloud trust

Firestore security rules protect the database structure and access:
- Users can only read and write their own attempts (`users/{uid}/attempts/{roundId}`).
- Every attempt must have the 6 required fields and an integer score from 0 to 10.
- Old attempts cannot be edited or deleted.

However, because scoring happens on the phone, the rules cannot prove the user actually played the game honestly. For a real competitive game, a server would need to check the answers and calculate the score. In this class app, rules secure the storage format, but scoring is client-side.

## 5. Critique of the supplied recovery design

The original starter code had two main bugs in the security rules:
1. **Timestamp read bug:** The original rule checked `submittedAt == request.time` on both creates and reads. A saved timestamp is always in the past, so every time the app tried to read the saved attempt back, Firestore blocked it with permission denied. We fixed this by only checking `request.time` on create.
2. **Transaction check bug:** Firestore transactions must read a document path before writing to it. The original rules blocked reading a document that did not exist yet, which made the transaction fail. We updated the rules to allow reading a missing document path.

Also, the original app read the document twice after saving. We simplified it to read once directly from the server.

## 6. Design defense

The app separates the save process into clear, honest steps:
- **Submitting:** Transaction is running.
- **Verifying:** Checking the server read-back.
- **Cloud Verified:** Successfully saved and confirmed directly on the server.
- **Save Unknown:** Network timed out; user can tap Reconcile.
- **Collision:** A different score already exists for this ID.

The app also uses session guards. If a user logs out while a save is in progress, the app drops the old response so it does not update the screen for the next user.
