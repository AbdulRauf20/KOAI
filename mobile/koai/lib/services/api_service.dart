import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/answer.dart';

class ApiResult {
  final Answer? answer;
  final String? error;
  final int roundTripMs;

  ApiResult({this.answer, this.error, required this.roundTripMs});
}

class ApiService {
  // Android emulator reaches your PC's localhost via 10.0.2.2.
  // Desktop/web run on the same machine as the backend, so localhost works.
  // For a PHYSICAL phone, enter your PC's LAN IP on the home screen,
  // e.g. 'http://192.168.1.20:8000', and start uvicorn with --host 0.0.0.0
  static final String defaultBaseUrl = (!kIsWeb && Platform.isAndroid)
      ? 'http://10.0.2.2:8000'
      : 'http://127.0.0.1:8000';

  final String baseUrl;

  ApiService({String? baseUrl})
      : baseUrl = (baseUrl == null || baseUrl.trim().isEmpty)
            ? defaultBaseUrl
            : baseUrl.trim();

  final http.Client _client = http.Client(); // reused across requests

  Future<ApiResult> askQuestion(String question, List<String> options) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/answer'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question, 'options': options}),
          )
          .timeout(const Duration(seconds: 15));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return ApiResult(
          answer: Answer.fromJson(jsonDecode(response.body)),
          roundTripMs: stopwatch.elapsedMilliseconds,
        );
      }

      String message = 'HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error']?.toString() ?? message;
      } catch (_) {
        // Non-JSON error body; keep the HTTP status message.
      }
      return ApiResult(error: message, roundTripMs: stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      return ApiResult(
        error: 'Network error: $e',
        roundTripMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}
