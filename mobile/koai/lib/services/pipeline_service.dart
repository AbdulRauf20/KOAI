import 'dart:async';

import '../models/question.dart';
import 'api_service.dart';
import 'capture_service.dart';
import 'ocr_service.dart';
import 'parser_service.dart';

/// Result of one full pipeline pass:
/// capture -> OCR -> parse -> AI -> answer.
class PipelineOutcome {
  final ParsedQuestion? question;
  final String? answerLetter;
  final double? confidence;
  final String? error;
  final bool simulated; // true when capture/OCR were skipped (non-Android)
  final Map<String, int> metrics;

  PipelineOutcome({
    this.question,
    this.answerLetter,
    this.confidence,
    this.error,
    this.simulated = false,
    this.metrics = const {},
  });
}

/// Orchestrates the real-time loop. Every [interval] it:
///  1. captures the screen (MediaProjection, Android only)
///  2. runs ML Kit OCR on the frame
///  3. parses question + options out of the OCR text
///  4. skips if it's the same question it already answered
///  5. asks the backend AI and reports the outcome
///
/// On platforms without screen capture it falls back to [simulatedOcrText],
/// which the mock quiz screen provides (its current question rendered as
/// OCR-like text), so capture/OCR are skipped but parser + AI still run.
class PipelineService {
  final CaptureService _capture = CaptureService();
  final OcrService _ocr = OcrService();
  final ParserService _parser = ParserService();
  final ApiService api;

  PipelineService({required this.api});

  Timer? _timer;
  bool _busy = false;
  bool captureAvailable = false;
  String? _lastFingerprint;

  bool get isRunning => _timer != null;

  /// Request capture permission. Returns true if real screen capture is on.
  Future<bool> startCapture() async {
    captureAvailable = await _capture.startCapture();
    return captureAvailable;
  }

  void startLoop({
    Duration interval = const Duration(milliseconds: 2500),
    required String? Function() simulatedOcrText,
    required void Function(PipelineOutcome outcome) onResult,
  }) {
    _timer?.cancel();
    _lastFingerprint = null;
    _timer = Timer.periodic(interval, (_) async {
      if (_busy) return; // never overlap two passes
      _busy = true;
      try {
        final outcome = await _runOnce(simulatedOcrText);
        if (outcome != null) onResult(outcome);
      } finally {
        _busy = false;
      }
    });
  }

  Future<PipelineOutcome?> _runOnce(
      String? Function() simulatedOcrText) async {
    final total = Stopwatch()..start();
    final metrics = <String, int>{};
    String ocrText;
    var simulated = !captureAvailable;

    if (captureAvailable) {
      final captureWatch = Stopwatch()..start();
      final framePath = await _capture.captureFrame();
      metrics['capture_ms'] = captureWatch.elapsedMilliseconds;
      if (framePath == null) return null; // no frame yet, try next tick

      final ocrWatch = Stopwatch()..start();
      ocrText = await _ocr.extractText(framePath);
      metrics['ocr_ms'] = ocrWatch.elapsedMilliseconds;
    } else {
      final text = simulatedOcrText();
      if (text == null) return null;
      ocrText = text;
      metrics['capture_ms'] = 0;
      metrics['ocr_ms'] = 0;
    }

    final parseWatch = Stopwatch()..start();
    final parsed = _parser.parse(ocrText);
    metrics['parse_ms'] = parseWatch.elapsedMilliseconds;
    if (parsed == null) return null; // no question on screen right now

    if (parsed.fingerprint == _lastFingerprint) return null; // already answered
    _lastFingerprint = parsed.fingerprint;

    final result = await api.askQuestion(parsed.question, parsed.options);
    metrics['api_round_trip_ms'] = result.roundTripMs;
    if (result.answer != null) {
      metrics['ai_ms'] = result.answer!.aiMs;
    }
    metrics['total_ms'] = total.elapsedMilliseconds;

    if (result.error != null) {
      // Allow a retry of the same question after a failure.
      _lastFingerprint = null;
      return PipelineOutcome(
        question: parsed,
        error: result.error,
        simulated: simulated,
        metrics: metrics,
      );
    }

    return PipelineOutcome(
      question: parsed,
      answerLetter: result.answer!.answer,
      confidence: result.answer!.confidence,
      simulated: simulated,
      metrics: metrics,
    );
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _capture.stopCapture();
  }

  void dispose() {
    _timer?.cancel();
    _ocr.dispose();
  }
}
