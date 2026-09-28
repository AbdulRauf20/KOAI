import 'package:flutter/material.dart';

import '../models/answer.dart';
import '../services/api_service.dart';

/// Manual question entry — the v0.1 flow. Useful for testing the backend
/// without the capture/OCR pipeline.
class ManualScreen extends StatefulWidget {
  final String? baseUrl;

  const ManualScreen({super.key, this.baseUrl});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  late final ApiService _api = ApiService(baseUrl: widget.baseUrl);
  final _questionController =
      TextEditingController(text: 'Which protocol is connection-oriented?');
  final _optionControllers = [
    TextEditingController(text: 'UDP'),
    TextEditingController(text: 'IP'),
    TextEditingController(text: 'TCP'),
    TextEditingController(text: 'ICMP'),
  ];

  bool _loading = false;
  Answer? _answer;
  String? _error;
  int? _roundTripMs;

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      setState(() {
        _answer = null;
        _error = 'Enter a question and at least 2 options.';
        _roundTripMs = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _answer = null;
      _error = null;
    });

    final result = await _api.askQuestion(question, options);

    setState(() {
      _loading = false;
      _answer = result.answer;
      _error = result.error;
      _roundTripMs = result.roundTripMs;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual mode'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _optionControllers.length; i++) ...[
              TextField(
                controller: _optionControllers[i],
                decoration: InputDecoration(
                  labelText: 'Option ${String.fromCharCode(65 + i)}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ask KOAI'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: $_error'
                    '${_roundTripMs != null ? '\nRound trip: $_roundTripMs ms' : ''}',
                  ),
                ),
              ),
            if (_answer != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'AI Answer: ${_answer!.answer}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confidence: '
                        '${(_answer!.confidence * 100).toStringAsFixed(0)}%',
                      ),
                      const Divider(height: 24),
                      Text('AI inference: ${_answer!.aiMs} ms'),
                      Text('Server total: ${_answer!.serverTotalMs} ms'),
                      Text('Round trip: $_roundTripMs ms'),
                      Text(
                        'Network overhead: '
                        '${_roundTripMs! - _answer!.serverTotalMs} ms',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
