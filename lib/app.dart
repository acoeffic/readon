import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'pages/welcome/welcome_page.dart';
import 'providers/theme_provider.dart';

class ReadOnApp extends StatelessWidget {
  const ReadOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ReadOn',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const WelcomePage(),
            routes: {
              '/welcome': (context) => const WelcomePage(),
            },
          );
        },
      ),
    );
  }
}