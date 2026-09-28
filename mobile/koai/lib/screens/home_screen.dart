import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'manual_screen.dart';
import 'mock_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController =
      TextEditingController(text: ApiService.defaultBaseUrl);
  bool _autoTap = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KOAI'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Kahoot Optimization AI',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'capture → OCR → AI → answer → tap',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                helperText: 'Physical phone: use your PC\'s LAN IP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-tap correct answer'),
              subtitle: const Text(
                  'KOAI taps the suggested option in the mock quiz'),
              value: _autoTap,
              onChanged: (v) => setState(() => _autoTap = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: const Text('Start KOAI'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MockQuizScreen(
                      autoTap: _autoTap,
                      baseUrl: _urlController.text,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.keyboard),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: const Text('Manual question mode'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManualScreen(baseUrl: _urlController.text),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'KOAI runs against the built-in mock quiz only. '
              'On Android it captures the real screen (MediaProjection + '
              'ML Kit OCR); on desktop it simulates the capture stage.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
