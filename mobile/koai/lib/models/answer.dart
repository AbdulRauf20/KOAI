class Answer {
  final String answer;
  final double confidence;
  final int aiMs;
  final int serverTotalMs;

  Answer({
    required this.answer,
    required this.confidence,
    required this.aiMs,
    required this.serverTotalMs,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>;
    return Answer(
      answer: json['answer'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      aiMs: metrics['ai_ms'] as int,
      serverTotalMs: metrics['server_total_ms'] as int,
    );
  }
}
