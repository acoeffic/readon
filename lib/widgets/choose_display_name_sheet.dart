// lib/widgets/choose_display_name_sheet.dart
//
// Rattrapage des comptes sans « vrai » nom : si le display_name est vide ou
// dérivé de l'email (adresse complète ou partie locale), on propose une fois
// par lancement de choisir comment apparaître. Ignorable (« Plus tard »),
// re-proposé au prochain lancement tant qu'aucun nom n'est choisi.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

bool _shownThisLaunch = false;

/// À appeler après le premier build de MainNavigation. Ne fait rien pour les
/// invités, les profils déjà nommés, ou si déjà proposé pendant ce lancement.
Future<void> maybeShowChooseDisplayNameSheet(BuildContext context) async {
  if (_shownThisLaunch) return;
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return;

  String? displayName;
  String? email;
  try {
    final profile = await supabase
        .from('profiles')
        .select('display_name, email')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) return;
    displayName = (profile['display_name'] as String?)?.trim();
    email = profile['email'] as String? ?? user.email;
  } catch (e) {
    debugPrint('Erreur maybeShowChooseDisplayNameSheet: $e');
    return;
  }

  final localPart = (email ?? '').split('@').first;
  final derivedFromEmail = displayName == null ||
      displayName.isEmpty ||
      displayName == email ||
      (localPart.isNotEmpty && displayName == localPart);
  if (!derivedFromEmail) return;

  if (!context.mounted) return;
  _shownThisLaunch = true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ChooseDisplayNameSheet(initialName: localPart),
  );
}

class _ChooseDisplayNameSheet extends StatefulWidget {
  final String initialName;

  const _ChooseDisplayNameSheet({required this.initialName});

  @override
  State<_ChooseDisplayNameSheet> createState() =>
      _ChooseDisplayNameSheetState();
}

class _ChooseDisplayNameSheetState extends State<_ChooseDisplayNameSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final cleaned =
        _controller.text.trim().replaceAll(RegExp(r'<[^>]*>'), '');
    if (cleaned.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.nameMinLength)),
      );
      return;
    }
    if (cleaned.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.nameMaxLength)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'display_name': cleaned})
          .eq('id', user.id);

      // Synchroniser les metadata auth pour que le trigger handle_new_user
      // ne réintroduise pas l'ancien nom à la prochaine connexion.
      await supabase.auth.updateUser(
        UserAttributes(data: {'display_name': cleaned}),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.nameUpdated)),
        );
      }
    } catch (e) {
      debugPrint('Erreur choose_display_name save: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.chooseNameTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.chooseNameSubtitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: l.yourName,
              counterText: '',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.save),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(),
              child: Text(
                l.later,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
