import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'live_capture_screen.dart';
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

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
              'capture → OCR → parse → AI → answer',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                helperText: 'Physical phone: use your PC\'s LAN IP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.screen_share),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: const Text('Live screen capture (any app)'),
              onPressed: () =>
                  _open(LiveCaptureScreen(baseUrl: _urlController.text)),
            ),
            const SizedBox(height: 20),
            const Divider(),
            Text('Demos & testing',
                style: Theme.of(context).textTheme.labelLarge),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-tap in mock quiz'),
              subtitle:
                  const Text('KOAI taps the suggested option automatically'),
              value: _autoTap,
              onChanged: (v) => setState(() => _autoTap = v),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.quiz),
              label: const Text('Mock quiz demo'),
              onPressed: () => _open(MockQuizScreen(
                autoTap: _autoTap,
                baseUrl: _urlController.text,
              )),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.keyboard),
              label: const Text('Manual question mode'),
              onPressed: () =>
                  _open(ManualScreen(baseUrl: _urlController.text)),
            ),
            const SizedBox(height: 28),
            Text(
              'Live capture reads the whole Android display (MediaProjection + '
              'ML Kit OCR) and shows the AI answer here or in a floating '
              'overlay. You still tap the answer yourself.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
