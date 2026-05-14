import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'pages/splash/splash_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/guest_mode_provider.dart';

import 'providers/connectivity_provider.dart';
import 'services/monthly_notification_service.dart';
import 'utils/responsive.dart';

class LexDayApp extends StatelessWidget {
  const LexDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => GuestModeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: MonthlyNotificationService.navigatorKey,
            title: 'LexDay',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(variant: themeProvider.variant),
            darkTheme: AppTheme.dark(variant: themeProvider.variant),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              // Sur iPad, on agrandit toute la typographie de ~15 % pour
              // compenser l'effet "petit" lié à la distance d'usage et à la
              // largeur d'écran. On préserve le réglage système (Dynamic
              // Type) en multipliant le scaler de l'utilisateur.
              final mq = MediaQuery.of(context);
              final ipadBoost = Responsive.isWide(context) ? 1.15 : 1.0;
              final systemScale = mq.textScaler.scale(1.0);
              final scaler = TextScaler.linear(systemScale * ipadBoost);
              return MediaQuery(
                data: mq.copyWith(textScaler: scaler),
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: child,
                ),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
