import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/constrained_content.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.statsPageTitle),
      ),
      body: ConstrainedContent(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(l.statsPageHeading),
              const SizedBox(height: 8),
              Text(
                l.statsPageComingSoon,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
