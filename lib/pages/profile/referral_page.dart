import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/referral_service.dart';
import '../../widgets/constrained_content.dart';

/// Écran de parrainage : l'utilisateur voit son code, le partage, suit ses
/// filleuls, et peut saisir un code s'il a été invité.
///
/// NOTE i18n : les chaînes sont ici en dur pour rester compilable sans
/// régénérer gen-l10n. À déplacer vers AppLocalizations (app_fr/en/es.arb)
/// puis `flutter gen-l10n`.
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final _service = ReferralService();
  final _codeController = TextEditingController();

  String? _myCode;
  String? _shareLink;
  int _total = 0;
  int _rewarded = 0;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await _service.getMyCode();
      final link = await _service.getShareLink();
      final stats = await _service.getStats();
      if (!mounted) return;
      setState(() {
        _myCode = code;
        _shareLink = link;
        _total = stats.total;
        _rewarded = stats.rewarded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    if (_shareLink == null) return;
    await Share.share(
      'Rejoins-moi sur LexDay 📚 On gagne tous les deux 14 jours de premium '
      'quand tu commences à lire !\n$_shareLink',
      subject: 'Rejoins-moi sur LexDay',
    );
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    _snack('Code copié !');
  }

  Future<void> _applyEnteredCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _applying) return;
    setState(() => _applying = true);
    final result = await _service.applyCode(code);
    if (!mounted) return;
    setState(() => _applying = false);
    _snack(_messageFor(result));
    if (result == ApplyReferralResult.success) {
      _codeController.clear();
    }
  }

  String _messageFor(ApplyReferralResult r) {
    switch (r) {
      case ApplyReferralResult.success:
        return 'Code appliqué ! Commence à lire pour débloquer vos 14 jours de premium.';
      case ApplyReferralResult.invalidCode:
        return 'Ce code n\'existe pas.';
      case ApplyReferralResult.selfReferral:
        return 'Tu ne peux pas utiliser ton propre code.';
      case ApplyReferralResult.alreadyReferred:
        return 'Tu as déjà utilisé un code de parrainage.';
      case ApplyReferralResult.notEligible:
        return 'Le parrainage est réservé aux nouveaux comptes.';
      case ApplyReferralResult.error:
        return 'Une erreur est survenue. Réessaie.';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Parrainage')),
      body: ConstrainedContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Invite un ami, gagnez tous les deux 14 jours de premium',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Partage ton code. Dès que ton ami commence à lire, '
                      'vous recevez chacun 14 jours de premium.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    // Carte du code
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Ton code',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _copyCode,
                            child: Text(
                              _myCode ?? '—',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copier'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    FilledButton.icon(
                      onPressed: _shareLink == null ? null : _share,
                      icon: const Icon(Icons.share),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Partager mon lien'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '$_total',
                            label: 'Amis invités',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: '$_rewarded',
                            label: 'Récompenses',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Saisie d'un code reçu
                    Text(
                      'Tu as un code ?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'CODE',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _applying ? null : _applyEnteredCode,
                          child: _applying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Valider'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
