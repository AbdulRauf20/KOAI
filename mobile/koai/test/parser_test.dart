import 'package:flutter_test/flutter_test.dart';

import 'package:koai/services/parser_service.dart';

void main() {
  final parser = ParserService();

  group('ParserService', () {
    test('parses dot-separated options (A. UDP)', () {
      final result = parser.parse(
          'Which protocol is connection-oriented?\nA. UDP\nB. IP\nC. TCP\nD. ICMP');
      expect(result, isNotNull);
      expect(result!.question, 'Which protocol is connection-oriented?');
      expect(result.options, ['UDP', 'IP', 'TCP', 'ICMP']);
    });

    test('parses parenthesis options (A) UDP)', () {
      final result =
          parser.parse('Pick one\nA) First\nB) Second\nC) Third');
      expect(result, isNotNull);
      expect(result!.options, ['First', 'Second', 'Third']);
    });

    test('parses dash and colon options (A - / A:)', () {
      final result = parser.parse('Pick one\nA - First\nB: Second');
      expect(result, isNotNull);
      expect(result!.options, ['First', 'Second']);
    });

    test('parses bare letter options (A UDP) as OCR often outputs', () {
      final result =
          parser.parse('Which protocol?\nA UDP\nB IP\nC TCP\nD ICMP');
      expect(result, isNotNull);
      expect(result!.options, ['UDP', 'IP', 'TCP', 'ICMP']);
    });

    test('joins a multi-line question', () {
      final result = parser.parse(
          'Which protocol is\nconnection-oriented?\nA. UDP\nB. TCP');
      expect(result, isNotNull);
      expect(result!.question, 'Which protocol is connection-oriented?');
    });

    test('ignores noise lines after the options (timer, suggestions)', () {
      final result = parser.parse(
          'Which protocol?\nA. UDP\nB. TCP\nKOAI suggests: B (99%)\nNext question');
      expect(result, isNotNull);
      expect(result!.options, ['UDP', 'TCP']);
    });

    test('rejects text without enough options', () {
      expect(parser.parse('Just a sentence with no options'), isNull);
      expect(parser.parse('Question?\nA. only one option'), isNull);
    });

    test('rejects non-consecutive option letters (stray OCR match)', () {
      expect(parser.parse('Question?\nB. first\nD. second'), isNull);
    });

    test('rejects empty input', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('\n\n  \n'), isNull);
    });

    test('same question produces same fingerprint', () {
      final a = parser.parse('Q one?\nA. x\nB. y');
      final b = parser.parse('Q ONE?\nA. X\nB. Y');
      expect(a!.fingerprint, b!.fingerprint);
    });
  });
}
