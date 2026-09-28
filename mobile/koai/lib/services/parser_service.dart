import '../models/question.dart';

/// Converts raw OCR text into a structured question + options.
///
/// Tolerates common OCR/layout variations of option markers:
///   "A. UDP"   "A) UDP"   "A - UDP"   "A: UDP"   "A UDP"
class ParserService {
  // Letter A-F followed by an optional separator, then the option text.
  static final RegExp _optionPattern =
      RegExp(r'^([A-F])\s*[\.\):\-]?\s+(\S.*)$', caseSensitive: false);

  ParsedQuestion? parse(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    final questionLines = <String>[];
    // Letter -> option text. A map (not a list) so a duplicated/re-read
    // option overwrites instead of duplicating.
    final options = <String, String>{};
    var seenFirstOption = false;

    for (final line in lines) {
      final match = _optionPattern.firstMatch(line);
      if (match != null) {
        seenFirstOption = true;
        options[match.group(1)!.toUpperCase()] = match.group(2)!.trim();
      } else if (!seenFirstOption) {
        // Everything before the first option marker is the question,
        // possibly wrapped across multiple lines.
        questionLines.add(line);
      }
      // Non-option text after options started (timer, score, header noise)
      // is ignored.
    }

    final question = questionLines.join(' ').trim();
    if (question.length < 3 || options.length < 2) return null;

    // Options must be consecutive letters starting at A. This rejects
    // garbage like a stray "D" match without A/B/C.
    final letters = options.keys.toList()..sort();
    for (var i = 0; i < letters.length; i++) {
      if (letters[i] != String.fromCharCode(65 + i)) return null;
    }

    return ParsedQuestion(
      question: question,
      options: letters.map((l) => options[l]!).toList(),
    );
  }
}
