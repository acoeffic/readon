// lib/widgets/terms_acceptance_checkbox.dart
// Widget pour accepter les CGU avec lien vers la page complète

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../pages/auth/terms_of_service_page.dart';
import '../theme/app_theme.dart';

class TermsAcceptanceCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: l.iAcceptThe),
                  TextSpan(
                    text: l.termsOfUseLink,
                    style: const TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServicePage(
                              requireAcceptance: false,
                            ),
                          ),
                        );
                      },
                  ),
                  TextSpan(text: l.ofLexDay),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}