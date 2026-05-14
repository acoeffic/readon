// lib/widgets/require_account_sheet.dart
// Modal qui invite l'utilisateur invité à créer un compte ou se connecter
// pour effectuer une action gated (like, comment, follow, ajouter à biblio,
// participer à un club, etc.).
//
// Helper `requireAccount(context, action: () { ... })` :
//   - si l'utilisateur est connecté → exécute action() directement
//   - si invité → présente la modal ; au tap "Créer un compte" / "Se connecter"
//     l'utilisateur quitte le mode invité et atterrit sur la page d'auth
//     correspondante (option B : on ne reprend pas l'action après login).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../pages/auth/auth_gate.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/signup_page.dart';
import '../providers/guest_mode_provider.dart';
import '../theme/app_theme.dart';

/// Helper principal : appeler depuis n'importe quelle action gated.
/// Retourne `true` si l'action a été exécutée (utilisateur connecté).
Future<bool> requireAccount(
  BuildContext context, {
  required VoidCallback action,
}) async {
  final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
  if (isLoggedIn) {
    action();
    return true;
  }
  await showRequireAccountSheet(context);
  return false;
}

/// Variante async : si l'utilisateur est connecté, on attend `action()`.
Future<bool> requireAccountAsync(
  BuildContext context, {
  required Future<void> Function() action,
}) async {
  final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
  if (isLoggedIn) {
    await action();
    return true;
  }
  await showRequireAccountSheet(context);
  return false;
}

/// Affiche la modal sans pré-vérifier l'auth (utile pour les taps sur tabs
/// gated où on veut toujours afficher le prompt).
Future<void> showRequireAccountSheet(BuildContext context) async {
  final colors = context.appColors;
  final l = AppLocalizations.of(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colors.scaffoldBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.guestRequireAccountTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.guestRequireAccountSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _exitGuestAndOpen(ctx, signup: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l.guestSignUpCta,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => _exitGuestAndOpen(ctx, signup: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l.guestSignInCta,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                l.guestCancelCta,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _exitGuestAndOpen(BuildContext sheetContext,
    {required bool signup}) async {
  final navigator = Navigator.of(sheetContext, rootNavigator: true);
  await sheetContext.read<GuestModeProvider>().exitGuestMode();
  if (!sheetContext.mounted) return;
  // Ferme la modal
  Navigator.of(sheetContext).pop();
  // Push l'écran d'auth approprié sur la stack root.
  // Quand l'utilisateur s'auth avec succès, le LoginPage/SignUpPage
  // pushe AuthGate qui détecte la nouvelle session et route vers MainNavigation.
  navigator.push(
    MaterialPageRoute(
      builder: (_) => signup ? const SignUpPage() : const LoginPage(),
    ),
  );
}

// Ré-export utilitaire pour n'avoir qu'un import dans les call sites
typedef AuthGateRef = AuthGate;
