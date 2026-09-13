// lib/widgets/kindle_connect_sheet.dart
//
// Proposition de connexion Kindle, sortie de l'onboarding le 15/08/2026.
//
// Avant, l'écran de connexion Amazon était imposé à la 3e étape de
// l'onboarding aux profils « liseuse » et « mix » : un formulaire Amazon dans
// une WebView demandé à la 60e seconde, avant que l'app ait rien prouvé. Ce
// parcours activait 2,5 fois moins bien que le parcours papier.
//
// La proposition arrive désormais **après la première session de lecture
// terminée**, une seule fois, et refusable définitivement. Elle ne s'adresse
// qu'aux gens qui ont déclaré lire sur liseuse et qui n'ont pas déjà connecté
// leur compte. La connexion reste par ailleurs accessible à tout moment
// depuis Réglages → Kindle.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../pages/profile/kindle_login_page.dart';
import '../services/kindle_auto_sync_service.dart';
import '../theme/app_theme.dart';

const _kDismissedKey = 'kindle_connect_suggested';

bool _shownThisLaunch = false;

/// Propose la connexion Kindle si — et seulement si — toutes ces conditions
/// sont réunies : utilisateur authentifié, habitude de lecture « liseuse » ou
/// « mix », Kindle pas déjà connecté, proposition jamais faite auparavant.
///
/// Retourne `true` si la feuille a été présentée, pour que l'appelant
/// n'enchaîne pas une seconde sollicitation dans le même lancement.
Future<bool> maybeShowKindleConnectSheet(BuildContext context) async {
  if (_shownThisLaunch) return false;

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;

  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDismissedKey) == true) return false;

    if (await KindleAutoSyncService().isKindleConnected()) {
      // Déjà connecté : on n'aura jamais à le redemander.
      await prefs.setBool(_kDismissedKey, true);
      return false;
    }

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('reading_habit')
        .eq('id', user.id)
        .maybeSingle();
    final habit = profile?['reading_habit'] as String?;
    if (habit != 'liseuse' && habit != 'mix') return false;

    if (!context.mounted) return false;
    _shownThisLaunch = true;
    // Posé avant l'affichage : une proposition présentée est une proposition
    // consommée, même si l'utilisateur ferme la feuille en balayant.
    await prefs.setBool(_kDismissedKey, true);
  } catch (e) {
    debugPrint('Erreur maybeShowKindleConnectSheet: $e');
    return false;
  }

  if (!context.mounted) return false;

  final connect = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _KindleConnectSheet(),
  );

  if (connect == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KindleLoginPage()),
    );
  }

  return true;
}

class _KindleConnectSheet extends StatelessWidget {
  const _KindleConnectSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.tablet_android,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.l),
            Text(
              l10n.kindleOnboardingTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpace.m),
            Text(
              l10n.kindleOnboardingSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpace.l),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.link, size: 20),
                label: Text(
                  l10n.kindleOnboardingButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                l10n.later,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
