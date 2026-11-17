# ICA16 written answers

These answers describe the implementation and local rules observations. Device
test references remain planned evidence until their observed results are filled
in `TEST_LOG.md`.

## 1. Two success layers

The app checks more than whether an HTTP request returned. A status of 200 means
the server returned a successful HTTP response, but the response body can still
report an API error. After checking the status, the app decodes the JSON and
requires `response_code` to be zero. It then requires exactly ten results. Each
question must have the expected category, difficulty, and type, along with a
nonempty question and four distinct answers after HTML decoding. This prevents a
partly valid response from starting a round. The API-code fault deliberately
changes the parsed response code to 5, while the fault label remains visible.
T02 and T03 are the planned device evidence for this distinction; they have not
yet been recorded. The [OpenTDB documentation](https://opentdb.com/api_config.php)
describes its response codes and five-second rate limit.

## 2. Unknown is not failed

A timeout does not prove a write was rejected. The server might have committed
the document even though the client did not receive a conclusive response. This
app therefore uses a Save unknown state. It keeps the existing round ID and
payload instead of creating another attempt. The Reconcile button performs a
server-only read. Success requires a matching document, a resolved timestamp,
and no pending writes or cache-only result. The lost-ack fault is an explicit
simulation: it runs after the transaction returns, then routes the interface to
Save unknown. T09 will check that reconciliation finds the same single document.
That UI test is still pending. The local emulator tests already show that a valid
stored document can be read later by its owner. See Firebase's
[transaction guidance](https://firebase.google.com/docs/firestore/manage-data/transactions).

## 3. Retry identity

The round ID is generated once when a round starts. Finishing the round freezes
the six-field payload. Retrying a submission reuses both values. This matters
because generating a fresh ID after an uncertain response could create duplicate
documents. The transaction reads the chosen path before writing. If the document
does not exist, it creates it. If an existing document matches the five stable
fields, it reuses that attempt without changing its timestamp. Different values
produce a collision instead of overwriting the original. A server read reporting
no document allows Retry same attempt, which still uses the original ID. Even if
an earlier operation later completes, the same-path transaction remains the
idempotency mechanism. G01 and G02 are planned two-client checks of concurrency
and collision behavior; they have not been run.

## 4. Cloud trust

The rules establish ownership and document shape. They require the authenticated
UID to match the user path, exactly six fields, fixed schema/category/variant
values, ten questions, and an integer score between zero and ten. Creation also
requires a server timestamp. Updates and deletes are denied. These checks do not
prove the score was earned: a modified client can still submit an in-range score.
A competitive system would need a trusted backend to issue the questions, verify
the answers, and write the score. The current app is a client-scored class demo.
Eight local emulator tests passed for the rule restrictions, but this is not a
claim of server-authoritative scoring. Firebase documents the difference between
client rule enforcement and privileged server access in its
[security-rule conditions guide](https://firebase.google.com/docs/firestore/security/rules-conditions).

## 5. Critique of the supplied recovery design

The supplied rules reused one validator for both creation and reads. That
validator required `submittedAt == request.time`. This is appropriate when
accepting a new server timestamp, but an existing timestamp will normally differ
from a later read time. It would block the read-back that the success screen
depends on. The rules also needed to let an owner read a missing document so the
create-once transaction could check for its absence. The revised rules separate
stored-data validation from the creation-time requirement and explicitly permit
that missing-document check. Local emulator tests passed for both corrected
cases. Another issue was reading a verified document a second time to populate
the success screen. The implementation now returns the checked snapshot's values
from one read, with session guards after asynchronous work. These findings came
from review and local testing, not invented device screenshots.

## 6. Design defense

The interface separates committing, verifying, unknown, collision, and confirmed
states because each state supports a different honest action. A successful
transaction alone does not display Cloud verified. The app must first complete a
matching server-only read. An ambiguous result offers reconciliation rather than
replay with a fresh ID. A conflicting document is preserved and shown as a
collision. Each asynchronous result is checked against the current signed-in UID,
the screen's lifetime, and the current operation number. This prevents a result
from a previous user or round from changing the current screen. The full round ID
can be copied, and the history button can reopen a saved attempt after restart.
Pending local state is not persisted, so restarting during an unresolved write
still requires keeping the ID externally. Device evidence for these behaviors is
planned in T07–T09 and G03 and remains to be collected.
