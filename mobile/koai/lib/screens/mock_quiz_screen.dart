import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/pipeline_service.dart';

class _QuizItem {
  final String question;
  final List<String> options;
  final String correct; // letter, for feedback only — KOAI never sees this
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

class MockQuizScreen extends StatefulWidget {
  final bool autoTap;
  final String baseUrl;

  const MockQuizScreen(
      {super.key, required this.autoTap, required this.baseUrl});

  @override
  State<MockQuizScreen> createState() => _MockQuizScreenState();
}

class _MockQuizScreenState extends State<MockQuizScreen> {
  late final PipelineService _pipeline;

  int _index = 0;
  String? _selectedLetter;
  bool _selectedByKoai = false;
  PipelineOutcome? _outcome;
  bool _realCapture = false;
  bool _starting = true;

  _QuizItem get _item => _quizItems[_index];

  @override
  void initState() {
    super.initState();
    _pipeline = PipelineService(api: ApiService(baseUrl: widget.baseUrl));
    _startPipeline();
  }

  Future<void> _startPipeline() async {
    // On Android this shows the system screen-capture consent dialog and
    // starts the MediaProjection foreground service. Elsewhere it returns
    // false and the pipeline runs in simulated-capture mode.
    final real = await _pipeline.startCapture();
    if (!mounted) return;
    setState(() {
      _realCapture = real;
      _starting = false;
    });

    _pipeline.startLoop(
      // Fallback for platforms without screen capture: feed the current
      // question rendered the way OCR would read it off this screen.
      simulatedOcrText: () {
        final letters = ['A', 'B', 'C', 'D'];
        final lines = [
          _item.question,
          for (var i = 0; i < _item.options.length; i++)
            '${letters[i]}. ${_item.options[i]}',
        ];
        return lines.join('\n');
      },
      onResult: (outcome) {
        if (!mounted) return;
        setState(() => _outcome = outcome);
        if (widget.autoTap &&
            outcome.answerLetter != null &&
            _selectedLetter == null) {
          // Small delay so the suggestion is visible before the tap lands.
          Timer(const Duration(milliseconds: 400), () {
            if (!mounted || _selectedLetter != null) return;
            _select(outcome.answerLetter!, byKoai: true);
          });
        }
      },
    );
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
      _outcome = null;
    });
  }

  @override
  void dispose() {
    _pipeline.stop();
    _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];
    return Scaffold(
      // No title text: less noise for OCR to misread as question text.
      appBar: AppBar(),
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
                    _optionButton(letters[i], _item.options[i],
                        _optionColors[i]),
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
        backgroundColor: answered && !selected ? color.withValues(alpha: 0.35) : color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(
                  color: isCorrect ? Colors.white : Colors.black,
                  width: 4,
                )
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
    final outcome = _outcome;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _starting
                      ? Icons.hourglass_top
                      : (_realCapture ? Icons.screenshot_monitor : Icons.science),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _starting
                        ? 'Starting KOAI…'
                        : (_realCapture
                            ? 'KOAI running — real screen capture + OCR'
                            : 'KOAI running — simulated capture (no Android)'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _nextQuestion,
                  child: const Text('Next question'),
                ),
              ],
            ),
            if (outcome?.error != null)
              Text('Pipeline error: ${outcome!.error}',
                  style: const TextStyle(color: Colors.red)),
            if (outcome?.answerLetter != null) ...[
              Text(
                'KOAI suggests: ${outcome!.answerLetter}'
                '  (${((outcome.confidence ?? 0) * 100).toStringAsFixed(0)}%)'
                '${_selectedByKoai ? '  — auto-tapped' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _metricsLine(outcome.metrics),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _metricsLine(Map<String, int> m) {
    final parts = <String>[];
    void add(String label, String key) {
      if (m.containsKey(key)) parts.add('$label ${m[key]} ms');
    }

    add('capture', 'capture_ms');
    add('ocr', 'ocr_ms');
    add('parse', 'parse_ms');
    add('ai', 'ai_ms');
    add('round trip', 'api_round_trip_ms');
    add('total', 'total_ms');
    return parts.join('  ·  ');
  }
}
