// lib/widgets/update_available_banner.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/app_update_service.dart';

class UpdateAvailableBanner extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onDismissed;

  const UpdateAvailableBanner({
    super.key,
    required this.updateInfo,
    required this.onDismissed,
  });

  Future<void> _openStore() async {
    final uri = Uri.parse(updateInfo.storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _dismiss() async {
    await AppUpdateService.dismiss(updateInfo.latestVersion);
    onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.updateAvailableBanner,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _openStore,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.updateAvailableAction,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            InkWell(
              onTap: _dismiss,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
