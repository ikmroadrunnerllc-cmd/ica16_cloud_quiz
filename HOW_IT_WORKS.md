# How the ICA16 app works

`main.dart` calls `startApp()` in `ica16_app.dart`. Firebase starts before the sign-in
screen appears. If Firebase is not configured, a setup screen explains what is
missing. The app uses email and password accounts already created in Firebase.

After sign-in, the user's UID identifies where their attempts can be saved. The
app asks Open Trivia Database for ten easy General Knowledge questions. It checks
the HTTP status, JSON structure, API response code, and number of results. The
question class checks category, difficulty, type, and all four decoded choices.
An invalid round never reaches the play screen.

Each question's answer choices are shuffled once. Tapping an answer saves its
index. Further taps cannot score it again. Correct choices turn green and an
incorrect selected choice turns red. The tenth answer opens a review of all ten
questions and freezes the score payload.

A round receives one Firestore-generated ID. Submit uses that ID in a transaction.
The transaction reads first: a missing document is created; a matching document is
reused; a different document produces a collision. It never overwrites an attempt.
The callback does not generate IDs or change the screen because Firestore can
run the callback more than once.

After submitting, the app reads the same document with `Source.server`. It checks
the saved fields and timestamp and rejects pending or cache-only results. Only
then does it show Cloud verified. The path, score, round ID, and timestamp on that
screen come from the checked result.

If the outcome is uncertain, the app keeps the round and offers reconciliation.
It does not assume a timeout means failure. If a server read finds no document,
Retry same attempt uses the original ID and payload. If different values exist,
the app reports a collision and preserves them.

The bug menu deliberately injects faults. The chosen fault stays visible. Use
Restart round for request faults and Submit for write faults. Lost ack deliberately
hides an acknowledged transaction from the UI so the recovery path can be tested.
Unavailable and quota are injected errors, not proof of a real outage.

Async callbacks check that the screen is still mounted, the operation is current,
and the same user is signed in. A late result from another round or user is ignored.
The stale-response fault signs out after submitting and resumes the old callback
five seconds later to exercise that guard.

Use the history icon to read a saved attempt by its full round ID after restart.
The app does not maintain a local history or restore an unfinished round.

The rules allow an owner to create a valid attempt and read a valid saved attempt.
They also allow checking a missing attempt path, which the transaction needs.
Updates, deletes, cross-user access, invalid fields, and listing are blocked.
The rules check the server timestamp at creation; a later read only checks that
it is a valid stored timestamp. The score is still client-computed.
