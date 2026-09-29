import 'dart:async';

import '../models/question.dart';
import 'api_service.dart';
import 'capture_service.dart';
import 'ocr_service.dart';
import 'parser_service.dart';

/// Tunable pipeline parameters, exposed in the debug UI.
class LiveConfig {
  /// How many capture attempts per second.
  final double captureFps;

  /// Frame downscale factor sent to OCR (lower = faster, less accurate).
  final double scale;

  /// Crop fractions (0..1). Defaults keep the full frame.
  final double cropTop;
  final double cropBottom;

  /// Minimum mean per-pixel change (0..255) to treat the screen as changed.
  final double changeThreshold;

  /// Draw the floating overlay while running.
  final bool overlayEnabled;

  const LiveConfig({
    this.captureFps = 2.0,
    this.scale = 0.5,
    this.cropTop = 0.0,
    this.cropBottom = 1.0,
    this.changeThreshold = 6.0,
    this.overlayEnabled = false,
  });

  Duration get interval =>
      Duration(milliseconds: (1000 / captureFps).round().clamp(150, 5000));

  LiveConfig copyWith({
    double? captureFps,
    double? scale,
    double? cropTop,
    double? cropBottom,
    double? changeThreshold,
    bool? overlayEnabled,
  }) {
    return LiveConfig(
      captureFps: captureFps ?? this.captureFps,
      scale: scale ?? this.scale,
      cropTop: cropTop ?? this.cropTop,
      cropBottom: cropBottom ?? this.cropBottom,
      changeThreshold: changeThreshold ?? this.changeThreshold,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
    );
  }
}

/// A single loop iteration reported back to the UI.
class LiveUpdate {
  final String status;
  final Map<String, double> metrics; // stage -> ms
  final ParsedQuestion? question;
  final String? answerLetter;
  final double? confidence;
  final String? error;

  LiveUpdate({
    required this.status,
    this.metrics = const {},
    this.question,
    this.answerLetter,
    this.confidence,
    this.error,
  });
}

/// Orchestrates the real-time capture loop against the whole device display.
///
/// Each tick: capture (native, with change detection) -> if changed: OCR ->
/// parse -> dedupe -> AI. Unchanged screens stop at the capture stage, so we
/// never waste OCR or a network call on a static screen.
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
  LiveConfig _config = const LiveConfig();

  bool get isRunning => _timer != null;

  /// Request screen-capture permission and start the native service.
  Future<bool> startCapture() async {
    captureAvailable = await _capture.startCapture();
    return captureAvailable;
  }

  /// Push the current config to the native layer.
  Future<void> applyConfig(LiveConfig config) async {
    _config = config;
    await _capture.configure(
      scale: config.scale,
      cropL: 0.0,
      cropT: config.cropTop,
      cropR: 1.0,
      cropB: config.cropBottom,
      threshold: config.changeThreshold,
    );
  }

  /// Enable/disable the overlay, handling the permission flow. Returns whether
  /// the overlay is now active.
  Future<bool> setOverlay(bool enabled) async {
    _config = _config.copyWith(overlayEnabled: enabled);
    if (!enabled) {
      await _capture.hideOverlay();
      return false;
    }
    if (!await _capture.hasOverlayPermission()) {
      await _capture.requestOverlayPermission();
      return false; // user must grant, then toggle again
    }
    await _capture.showOverlay();
    return true;
  }

  void startLoop({
    required LiveConfig config,
    required void Function(LiveUpdate) onUpdate,
  }) {
    _timer?.cancel();
    _lastFingerprint = null;
    _config = config;
    _timer = Timer.periodic(config.interval, (_) async {
      if (_busy) return; // never overlap two passes
      _busy = true;
      try {
        await _tick(onUpdate);
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _tick(void Function(LiveUpdate) onUpdate) async {
    final total = Stopwatch()..start();
    final metrics = <String, double>{};

    final frame = await _capture.captureFrame();
    if (frame == null) {
      onUpdate(LiveUpdate(status: 'Capture unavailable on this platform'));
      return;
    }
    metrics['capture'] = frame.captureMs;
    metrics['detect'] = frame.detectMs;

    if (frame.noFrame) {
      _overlay('KOAI\nListening…');
      onUpdate(LiveUpdate(status: 'Listening… (no new frame)', metrics: metrics));
      return;
    }
    if (!frame.changed || frame.path == null) {
      _overlay('KOAI\nListening…');
      onUpdate(LiveUpdate(status: 'Listening… (screen unchanged)', metrics: metrics));
      return;
    }

    final ocrWatch = Stopwatch()..start();
    final text = await _ocr.extractText(frame.path!);
    metrics['ocr'] = ocrWatch.elapsedMilliseconds.toDouble();

    final parseWatch = Stopwatch()..start();
    final parsed = _parser.parse(text);
    metrics['parse'] = parseWatch.elapsedMilliseconds.toDouble();

    if (parsed == null) {
      _overlay('KOAI\nNo question on screen');
      onUpdate(LiveUpdate(
        status: 'Screen changed — no question found',
        metrics: metrics,
      ));
      return;
    }

    if (parsed.fingerprint == _lastFingerprint) {
      onUpdate(LiveUpdate(
        status: 'Same question (already answered)',
        metrics: metrics,
        question: parsed,
      ));
      return;
    }
    _lastFingerprint = parsed.fingerprint;
    _overlay('KOAI\nThinking…');

    final result = await api.askQuestion(parsed.question, parsed.options);
    metrics['api'] = result.roundTripMs.toDouble();
    if (result.answer != null) {
      metrics['ai'] = result.answer!.aiMs.toDouble();
    }
    metrics['total'] = total.elapsedMilliseconds.toDouble();

    if (result.error != null) {
      _lastFingerprint = null; // allow retry
      _overlay('KOAI\nAI error');
      onUpdate(LiveUpdate(
        status: 'AI error',
        error: result.error,
        metrics: metrics,
        question: parsed,
      ));
      return;
    }

    final answer = result.answer!;
    _overlay(
      'KOAI — Answer: ${answer.answer}\n'
      '${(answer.confidence * 100).toStringAsFixed(0)}%  ·  '
      '${total.elapsedMilliseconds} ms',
    );
    onUpdate(LiveUpdate(
      status: 'Question detected',
      metrics: metrics,
      question: parsed,
      answerLetter: answer.answer,
      confidence: answer.confidence,
    ));
  }

  void _overlay(String text) {
    if (_config.overlayEnabled) {
      _capture.updateOverlay(text);
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _capture.hideOverlay();
    await _capture.stopCapture();
  }

  void dispose() {
    _timer?.cancel();
    _ocr.dispose();
  }
}
