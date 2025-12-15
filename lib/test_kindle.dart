import 'package:flutter/material.dart';
import 'screens/kindle_sync_screen.dart';

void main() {
  runApp(const TestKindleApp());
}

class TestKindleApp extends StatelessWidget {
  const TestKindleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Kindle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const KindleSyncScreen(),
    );
  }
}