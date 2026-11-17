import 'package:html_unescape/html_unescape.dart';

class Question {
  Question({
    required this.prompt,
    required this.correct,
    required this.choices,
  });

  final String prompt;
  final String correct;
  final List<String> choices;

  factory Question.fromJson(Map<String, dynamic> data) {
    if (data['category'] != 'General Knowledge' ||
        data['difficulty'] != 'easy' ||
        data['type'] != 'multiple') {
      throw const FormatException('Unexpected category, difficulty, or type.');
    }
    if (data['question'] is! String || data['correct_answer'] is! String) {
      throw const FormatException('Question and answer must be text.');
    }
    final wrong = data['incorrect_answers'];
    if (wrong is! List || wrong.length != 3) {
      throw const FormatException('Expected exactly three distractors.');
    }
    final decoder = HtmlUnescape();
    final prompt = decoder.convert(data['question'] as String).trim();
    final correct = decoder.convert(data['correct_answer'] as String).trim();
    if (prompt.isEmpty || correct.isEmpty) {
      throw const FormatException('Empty question or answer.');
    }
    final choices = [correct];
    for (final answer in wrong) {
      if (answer is! String) {
        throw const FormatException('An answer choice was not text.');
      }
      final choice = decoder.convert(answer).trim();
      if (choice.isEmpty) {
        throw const FormatException('Empty answer choice after decoding.');
      }
      if (choices.contains(choice)) {
        throw const FormatException('Duplicate answer choice after decoding.');
      }
      choices.add(choice);
    }
    choices.shuffle();
    return Question(prompt: prompt, correct: correct, choices: choices);
  }
}

List<Question> parseRound(dynamic data) {
  if (data is! Map<String, dynamic>) {
    throw const FormatException('The response was not a JSON object.');
  }
  if (data['response_code'] is! int) {
    throw const FormatException('Missing API response_code.');
  }
  if (data['response_code'] != 0) {
    throw FormatException('API response_code was ${data['response_code']}.');
  }
  final results = data['results'];
  if (results is! List) {
    throw const FormatException('results was not a list.');
  }
  if (results.length != 10) {
    throw FormatException('Expected 10 results, got ${results.length}.');
  }
  final questions = <Question>[];
  for (final result in results) {
    if (result is! Map<String, dynamic>) {
      throw const FormatException('A question was not a JSON object.');
    }
    questions.add(Question.fromJson(result));
  }
  return questions;
}
