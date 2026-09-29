import 'dart:async';

import 'package:flutter/material.dart';

import '../models/answer.dart';
import '../services/api_service.dart';

class _QuizItem {
  final String question;
  final List<String> options;
  final String correct; // for feedback only — KOAI never sees this
  const _QuizItem(this.question, this.options, this.correct);
}

const _quizItems = <_QuizItem>[
  _QuizItem('Which protocol is connection-oriented?',
      ['UDP', 'IP', 'TCP', 'ICMP'], 'C'),
  _QuizItem('What is the output range of the sigmoid function?',
      ['-1 to 1', '0 to 1', '0 to infinity', '-infinity to infinity'], 'B'),
  _QuizItem('Which SQL command removes rows from a table?',
      ['DROP', 'DELETE', 'REMOVE', 'ERASE'], 'B'),
  _QuizItem('Which data structure uses FIFO order?',
      ['Stack', 'Queue', 'Tree', 'Graph'], 'B'),
  _QuizItem('What is the time complexity of binary search?',
      ['O(n)', 'O(log n)', 'O(n log n)', 'O(1)'], 'B'),
];

const _optionColors = [
  Color(0xFFE21B3C), // Kahoot red
  Color(0xFF1368CE), // blue
  Color(0xFFD89E00), // yellow
  Color(0xFF26890C), // green
];

/// Self-contained Kahoot-style demo. It already knows its own question, so it
/// asks the backend AI directly (no capture/OCR needed) and optionally
/// auto-taps the suggested answer. Good for demoing the AI + auto-tap loop
/// on desktop where screen capture isn't available.
class MockQuizScreen extends StatefulWidget {
  final bool autoTap;
  final String baseUrl;

  const MockQuizScreen(
      {super.key, required this.autoTap, required this.baseUrl});

  @override
  State<MockQuizScreen> createState() => _MockQuizScreenState();
}

class _MockQuizScreenState extends State<MockQuizScreen> {
  late final ApiService _api = ApiService(baseUrl: widget.baseUrl);

  int _index = 0;
  String? _selectedLetter;
  bool _selectedByKoai = false;
  bool _loading = false;
  Answer? _answer;
  String? _error;
  int? _roundTripMs;

  _QuizItem get _item => _quizItems[_index];

  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _answer = null;
      _error = null;
    });

    final result = await _api.askQuestion(_item.question, _item.options);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _answer = result.answer;
      _error = result.error;
      _roundTripMs = result.roundTripMs;
    });

    if (widget.autoTap &&
        result.answer != null &&
        _selectedLetter == null) {
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted || _selectedLetter != null) return;
        _select(result.answer!.answer, byKoai: true);
      });
    }
  }

  void _select(String letter, {bool byKoai = false}) {
    setState(() {
      _selectedLetter = letter;
      _selectedByKoai = byKoai;
    });
  }

  void _nextQuestion() {
    setState(() {
      _index = (_index + 1) % _quizItems.length;
      _selectedLetter = null;
      _selectedByKoai = false;
    });
    _ask();
  }

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];
    return Scaffold(
      appBar: AppBar(title: const Text('Mock quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _item.question,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < _item.options.length; i++)
                    _optionButton(
                        letters[i], _item.options[i], _optionColors[i]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _statusPanel(),
          ],
        ),
      ),
    );
  }

  Widget _optionButton(String letter, String text, Color color) {
    final selected = _selectedLetter == letter;
    final answered = _selectedLetter != null;
    final isCorrect = letter == _item.correct;

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            answered && !selected ? color.withValues(alpha: 0.35) : color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(
                  color: isCorrect ? Colors.white : Colors.black, width: 4)
              : BorderSide.none,
        ),
      ),
      onPressed: answered ? null : () => _select(letter),
      child: Text(
        '$letter. $text'
        '${selected && answered ? (isCorrect ? '  ✓' : '  ✗') : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _statusPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _loading
                      ? const Text('KOAI is thinking…')
                      : (_error != null
                          ? Text('Error: $_error',
                              style: const TextStyle(color: Colors.red))
                          : _answer != null
                              ? Text(
                                  'KOAI suggests: ${_answer!.answer}'
                                  '  (${(_answer!.confidence * 100).toStringAsFixed(0)}%)'
                                  '${_selectedByKoai ? '  — auto-tapped' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                )
                              : const Text('—')),
                ),
                TextButton(
                  onPressed: _loading ? null : _nextQuestion,
                  child: const Text('Next question'),
                ),
              ],
            ),
            if (_answer != null)
              Text(
                'AI ${_answer!.aiMs} ms  ·  server ${_answer!.serverTotalMs} ms'
                '  ·  round trip ${_roundTripMs ?? 0} ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
