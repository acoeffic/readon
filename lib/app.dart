import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/welcome/welcome_page.dart';

class ReadOnApp extends StatelessWidget {
  const ReadOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadOn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WelcomePage(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
      },
    );
  }
}