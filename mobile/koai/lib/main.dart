import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const KoaiApp());
}

class KoaiApp extends StatelessWidget {
  const KoaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOAI',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
