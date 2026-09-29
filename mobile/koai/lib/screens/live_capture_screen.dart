import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/pipeline_service.dart';

/// Real-time, system-wide screen-capture pipeline with a debug interface.
///
/// Flow: Start capture (grant Android permission) -> switch to any app
/// (e.g. Chrome on the test quiz page) -> KOAI keeps reading the display,
/// detects a question, and shows the AI answer + per-stage latency here
/// (and optionally in a floating overlay).
class LiveCaptureScreen extends StatefulWidget {
  final String? baseUrl;

  const LiveCaptureScreen({super.key, this.baseUrl});

  @override
  State<LiveCaptureScreen> createState() => _LiveCaptureScreenState();
}

class _LiveCaptureScreenState extends State<LiveCaptureScreen> {
  late final PipelineService _pipeline =
      PipelineService(api: ApiService(baseUrl: widget.baseUrl));

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  bool _running = false;
  bool _starting = false;
  bool _overlayOn = false;
  LiveConfig _config = const LiveConfig();
  LiveUpdate? _update;

  Future<void> _start() async {
    if (!_isAndroid) {
      _snack(
        'Live screen capture needs an Android phone or emulator. '
        'On Zorin/Linux use Mock quiz or Manual mode instead.',
      );
      return;
    }
    setState(() => _starting = true);
    final ok = await _pipeline.startCapture();
    if (!mounted) return;
    if (!ok) {
      setState(() => _starting = false);
      _snack(
        'Screen-capture permission denied. Tap Start again and allow '
        '"Start recording or casting" in the Android dialog.',
      );
      return;
    }
    await _pipeline.applyConfig(_config);
    _pipeline.startLoop(
      config: _config,
      onUpdate: (u) {
        if (mounted) setState(() => _update = u);
      },
    );
    setState(() {
      _running = true;
      _starting = false;
    });
  }

  Future<void> _stop() async {
    await _pipeline.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _overlayOn = false;
      _update = null;
    });
  }

  Future<void> _restartLoopIfRunning() async {
    await _pipeline.applyConfig(_config);
    if (_running) {
      _pipeline.startLoop(
        config: _config,
        onUpdate: (u) {
          if (mounted) setState(() => _update = u);
        },
      );
    }
  }

  Future<void> _toggleOverlay(bool value) async {
    final active = await _pipeline.setOverlay(value);
    if (!mounted) return;
    setState(() {
      _config = _config.copyWith(overlayEnabled: value);
      _overlayOn = active;
    });
    if (value && !active) {
      _snack('Grant "Display over other apps", then toggle again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _pipeline.stop();
    _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Screen Capture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isAndroid) _notAndroidNotice(),
            _controlCard(),
            const SizedBox(height: 12),
            _statusCard(),
            const SizedBox(height: 12),
            _metricsCard(),
            const SizedBox(height: 12),
            _configCard(),
          ],
        ),
      ),
    );
  }

  Widget _notAndroidNotice() => Card(
        color: Colors.amber.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'You are on Linux (Zorin). Live screen capture uses Android '
            'MediaProjection and does not work on a laptop.\n\n'
            'On this machine use:\n'
            '• Mock quiz demo — tests AI + auto-tap\n'
            '• Manual question mode — type a question\n\n'
            'For real screen capture, install the APK on an Android phone '
            'or run: flutter run (with a phone connected).',
          ),
        ),
      );

  Widget _controlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_running)
              FilledButton.icon(
                icon: _starting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.screen_share),
                label: Text(_starting ? 'Requesting permission…' : 'Start capture'),
                onPressed: (!_isAndroid || _starting) ? null : _start,
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.stop),
                label: const Text('Stop capture'),
                onPressed: _stop,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Floating overlay'),
              subtitle: const Text('Show answer on top of other apps'),
              value: _overlayOn,
              onChanged: _running ? _toggleOverlay : null,
            ),
            if (_running)
              Text(
                'Capture is running. Switch to Chrome and open the test quiz '
                'page — KOAI keeps reading the screen in the background.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final u = _update;
    final detected = u?.answerLetter != null;
    return Card(
      color: detected ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u?.status ?? (_running ? 'Listening…' : 'Idle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (u?.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Error: ${u!.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            if (u?.question != null) ...[
              const Divider(height: 20),
              Text(u!.question!.question,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (var i = 0; i < u.question!.options.length; i++)
                Text('${String.fromCharCode(65 + i)}. ${u.question!.options[i]}'),
            ],
            if (detected) ...[
              const SizedBox(height: 10),
              Text(
                'KOAI answer: ${u!.answerLetter}'
                '  (${((u.confidence ?? 0) * 100).toStringAsFixed(0)}%)',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricsCard() {
    final m = _update?.metrics ?? const <String, double>{};
    const order = [
      ['capture', 'Frame capture'],
      ['detect', 'Change detection'],
      ['ocr', 'OCR'],
      ['parse', 'Question parsing'],
      ['api', 'Network round trip'],
      ['ai', 'AI inference'],
      ['total', 'Total pipeline'],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Latency', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in order)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row[1]),
                    Text(
                      m.containsKey(row[0])
                          ? '${m[row[0]]!.toStringAsFixed(0)} ms'
                          : '—',
                      style: TextStyle(
                        fontWeight: row[0] == 'total'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFeatures: const [],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _configCard() {
    return Card(
      child: ExpansionTile(
        title: const Text('Pipeline settings'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _slider(
            label: 'Capture rate',
            value: _config.captureFps,
            min: 0.5,
            max: 4,
            divisions: 7,
            suffix: '${_config.captureFps.toStringAsFixed(1)} fps',
            onChanged: (v) => setState(
                () => _config = _config.copyWith(captureFps: v)),
            onChangeEnd: (_) => _restartLoopIfRunning(),
          ),
          _slider(
            label: 'Resolution scale',
            value: _config.scale,
            min: 0.25,
            max: 1,
            divisions: 6,
            suffix: '${(_config.scale * 100).toStringAsFixed(0)}%',
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(scale: v)),
            onChangeEnd: (_) => _restartLoopIfRunning(),
          ),
          _slider(
            label: 'Change threshold',
            value: _config.changeThreshold,
            min: 0,
            max: 30,
            divisions: 30,
            suffix: _config.changeThreshold.toStringAsFixed(0),
            onChanged: (v) => setState(
                () => _config = _config.copyWith(changeThreshold: v)),
            onChangeEnd: (_) => _restartLoopIfRunning(),
          ),
          _slider(
            label: 'Crop top',
            value: _config.cropTop,
            min: 0,
            max: 0.4,
            divisions: 8,
            suffix: '${(_config.cropTop * 100).toStringAsFixed(0)}%',
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(cropTop: v)),
            onChangeEnd: (_) => _restartLoopIfRunning(),
          ),
          _slider(
            label: 'Crop bottom',
            value: _config.cropBottom,
            min: 0.6,
            max: 1,
            divisions: 8,
            suffix: '${(_config.cropBottom * 100).toStringAsFixed(0)}%',
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(cropBottom: v)),
            onChangeEnd: (_) => _restartLoopIfRunning(),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(suffix)],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
