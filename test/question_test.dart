import 'package:flutter_test/flutter_test.dart';
import 'package:ica16_cloud_quiz/question.dart';

Map<String, dynamic> sample() {
  return {
    'category': 'General Knowledge',
    'difficulty': 'easy',
    'type': 'multiple',
    'question': 'Who said &quot;hello&quot; to Caf&eacute;?',
    'correct_answer': 'Alice &#039;A&#039;',
    'incorrect_answers': ['Bob', 'Carol', 'Dave'],
  };
}

void main() {
  test('decodes HTML entities and keeps four distinct choices', () {
    final question = Question.fromJson(sample());
    expect(question.prompt, 'Who said "hello" to Café?');
    expect(question.correct, "Alice 'A'");
    expect(question.choices.toSet(), {"Alice 'A'", 'Bob', 'Carol', 'Dave'});
    final order = List<String>.from(question.choices);
    expect(question.choices, order);
  });

  test('rejects answers that become duplicates after decoding', () {
    final data = sample();
    data['correct_answer'] = '&quot;A&quot;';
    data['incorrect_answers'] = ['"A"', 'B', 'C'];
    expect(() => Question.fromJson(data), throwsFormatException);
  });

  test('rejects blank answers after entity decoding and trimming', () {
    final data = sample();
    data['incorrect_answers'] = ['&nbsp;', 'B', 'C'];
    expect(() => Question.fromJson(data), throwsFormatException);
  });

  test('rejects malformed metadata and wrong answer types', () {
    for (final key in [
      'category',
      'difficulty',
      'type',
      'question',
      'correct_answer',
    ]) {
      final data = sample();
      data[key] = 7;
      expect(() => Question.fromJson(data), throwsFormatException);
    }
    for (final value in ['Other Category', '', 'Science']) {
      final data = sample();
      data['category'] = value;
      expect(() => Question.fromJson(data), throwsFormatException);
    }
    final data = sample();
    data['incorrect_answers'] = ['A', 7, 'C'];
    expect(() => Question.fromJson(data), throwsFormatException);
  });

  test('requires exactly ten valid questions and response code zero', () {
    final data = {
      'response_code': 0,
      'results': List.generate(10, (_) => sample()),
    };
    expect(parseRound(data).length, 10);
    data['response_code'] = 5;
    expect(() => parseRound(data), throwsFormatException);
    data['response_code'] = 0;
    data['results'] = List.generate(9, (_) => sample());
    expect(() => parseRound(data), throwsFormatException);
    expect(() => parseRound([]), throwsFormatException);
  });
}
