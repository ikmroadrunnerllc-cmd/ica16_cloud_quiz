import 'package:cloud_firestore/cloud_firestore.dart';

enum CommitOutcome { created, reused, collision }

enum VerifyResult {
  verified,
  missing,
  mismatch,
  pendingWrites,
  unresolvedTimestamp,
}

class AttemptVerification {
  const AttemptVerification(
    this.result, {
    this.path,
    this.correctCount,
    this.submittedAt,
  });

  final VerifyResult result;
  final String? path;
  final int? correctCount;
  final Timestamp? submittedAt;
}

bool isValidStoredAttempt(Map<String, dynamic> data) {
  if (data.length != 6) return false;
  if (data['schemaVersion'] is! int || data['schemaVersion'] != 1) return false;
  if (data['variant'] != 'A') return false;
  if (data['categoryId'] is! int || data['categoryId'] != 9) return false;
  if (data['questionCount'] is! int || data['questionCount'] != 10) {
    return false;
  }
  final score = data['correctCount'];
  if (score is! int || score < 0 || score > 10) return false;
  return data['submittedAt'] is Timestamp;
}

bool matchesAttempt(Map<String, dynamic> stored, Map<String, dynamic> payload) {
  if (!isValidStoredAttempt(stored)) return false;
  for (final key in [
    'schemaVersion',
    'variant',
    'categoryId',
    'questionCount',
    'correctCount',
  ]) {
    if (stored[key] != payload[key]) return false;
  }
  return true;
}

class AttemptRepository {
  AttemptRepository(this.db);

  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> refFor(String uid, String roundId) {
    return db.collection('users').doc(uid).collection('attempts').doc(roundId);
  }

  String newRoundId(String uid) {
    return db.collection('users').doc(uid).collection('attempts').doc().id;
  }

  Future<CommitOutcome> commit({
    required String uid,
    required String roundId,
    required Map<String, dynamic> payload,
  }) {
    final reference = refFor(uid, roundId);
    return db.runTransaction<CommitOutcome>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.set(reference, payload);
        return CommitOutcome.created;
      }
      if (matchesAttempt(snapshot.data()!, payload)) {
        return CommitOutcome.reused;
      }
      return CommitOutcome.collision;
    });
  }

  Future<AttemptVerification> verify({
    required String uid,
    required String roundId,
    Map<String, dynamic>? expectedPayload,
  }) async {
    final snapshot = await refFor(uid, roundId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (!snapshot.exists) {
      return const AttemptVerification(VerifyResult.missing);
    }
    if (snapshot.metadata.hasPendingWrites || snapshot.metadata.isFromCache) {
      return const AttemptVerification(VerifyResult.pendingWrites);
    }
    final data = snapshot.data()!;
    if (data['submittedAt'] is! Timestamp) {
      return const AttemptVerification(VerifyResult.unresolvedTimestamp);
    }
    if (!isValidStoredAttempt(data)) {
      return const AttemptVerification(VerifyResult.mismatch);
    }
    if (expectedPayload != null && !matchesAttempt(data, expectedPayload)) {
      return const AttemptVerification(VerifyResult.mismatch);
    }
    return AttemptVerification(
      VerifyResult.verified,
      path: snapshot.reference.path,
      correctCount: data['correctCount'] as int,
      submittedAt: data['submittedAt'] as Timestamp,
    );
  }
}
