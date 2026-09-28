/// A structured multiple-choice question extracted from OCR text.
class ParsedQuestion {
  final String question;
  final List<String> options;

  ParsedQuestion({required this.question, required this.options});

  /// Two captures of the same on-screen question should compare equal,
  /// so the pipeline can skip questions it already answered.
  String get fingerprint =>
      '${question.toLowerCase().trim()}|${options.map((o) => o.toLowerCase().trim()).join('|')}';

  @override
  String toString() => 'ParsedQuestion("$question", options: $options)';
}
