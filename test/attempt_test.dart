import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ica16_cloud_quiz/attempt_repository.dart';

Map<String, dynamic> sample() {
  return {
    'schemaVersion': 1,
    'variant': 'A',
    'categoryId': 9,
    'questionCount': 10,
    'correctCount': 7,
    'submittedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
  };
}

void main() {
  test('validates committed shape and resolved timestamp', () {
    expect(isValidStoredAttempt(sample()), isTrue);
    final extra = sample();
    extra['extra'] = true;
    expect(isValidStoredAttempt(extra), isFalse);
    final missing = sample()..remove('variant');
    expect(isValidStoredAttempt(missing), isFalse);
    for (final value in [-1, 11, 7.0, '7']) {
      final data = sample();
      data['correctCount'] = value;
      expect(isValidStoredAttempt(data), isFalse);
    }
    final unresolved = sample();
    unresolved['submittedAt'] = FieldValue.serverTimestamp();
    expect(isValidStoredAttempt(unresolved), isFalse);
  });

  test('same round payload ignores the new timestamp sentinel', () {
    final existing = sample();
    final retry = sample();
    retry['submittedAt'] = FieldValue.serverTimestamp();
    expect(matchesAttempt(existing, retry), isTrue);
    retry['correctCount'] = 8;
    expect(matchesAttempt(existing, retry), isFalse);
  });
}
