import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/constrained_content.dart';

/// Écran de parrainage : l'utilisateur voit son code, le partage, suit ses
/// filleuls, et peut saisir un code s'il a été invité.
class ReferralPage extends StatefulWidget {
  /// D'où l'écran est ouvert (analytics) : settings | profile_header | …
  final String source;

  const ReferralPage({super.key, this.source = 'settings'});

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
    unawaited(AnalyticsService().track(
      AnalyticsEvent.referralPageOpened,
      properties: {'source': widget.source},
    ));
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
    final l = AppLocalizations.of(context);
    unawaited(AnalyticsService().track(
      AnalyticsEvent.referralShareTapped,
      properties: {'source': 'referral_page'},
    ));
    await Share.share(
      l.referralPromptShareText(_shareLink!),
      subject: l.referralPageShareSubject,
    );
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    _snack(AppLocalizations.of(context).referralPageCopied);
  }

  /// Colle le contenu du presse-papier dans le champ, s'il ressemble à un
  /// code de parrainage. Déclenché uniquement par un tap de l'utilisateur.
  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = (data?.text ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,16}$').hasMatch(text)) {
      _snack(AppLocalizations.of(context).referralPageNoClipboardCode);
      return;
    }
    setState(() => _codeController.text = text);
  }

  Future<void> _applyEnteredCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _applying) return;
    setState(() => _applying = true);
    final result = await _service.applyCode(code);
    if (!mounted) return;
    setState(() => _applying = false);
    unawaited(AnalyticsService().track(
      AnalyticsEvent.referralCodeApplied,
      properties: {'result': result.name, 'source': 'referral_page'},
    ));
    _snack(_messageFor(result));
    if (result == ApplyReferralResult.success) {
      _codeController.clear();
    }
  }

  String _messageFor(ApplyReferralResult r) {
    final l = AppLocalizations.of(context);
    switch (r) {
      case ApplyReferralResult.success:
        return l.referralPageApplied;
      case ApplyReferralResult.invalidCode:
        return l.referralPageInvalidCode;
      case ApplyReferralResult.selfReferral:
        return l.referralPageSelfReferral;
      case ApplyReferralResult.alreadyReferred:
        return l.referralPageAlreadyReferred;
      case ApplyReferralResult.notEligible:
        return l.referralPageNotEligible;
      case ApplyReferralResult.error:
        return l.referralPageError;
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.referralSection)),
      body: ConstrainedContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.referralPageHeadline,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.referralPageSubtitle,
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
                            l.referralPageYourCode,
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
                            label: Text(l.referralPageCopy),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    FilledButton.icon(
                      onPressed: _shareLink == null ? null : _share,
                      icon: const Icon(Icons.share),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(l.referralPageShareButton),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '$_total',
                            label: l.referralPageInvited,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: '$_rewarded',
                            label: l.referralPageRewards,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MilestoneProgress(rewarded: _rewarded),
                    const SizedBox(height: 32),

                    // Saisie d'un code reçu
                    Text(
                      l.referralPageHaveCode,
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
                        // iOS n'a pas d'attribution différée : le filleul
                        // arrive avec le code dans le presse-papier (la page
                        // /r/CODE propose de le copier). Lecture uniquement
                        // sur action explicite — un accès silencieux
                        // déclencherait l'alerte système « a collé depuis ».
                        IconButton(
                          tooltip: l.referralPagePasteTooltip,
                          icon: const Icon(Icons.content_paste_rounded),
                          onPressed: _applying ? null : _pasteCode,
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: _applying ? null : _applyEnteredCode,
                          child: _applying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(l.referralPageValidate),
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

/// Paliers de récompense du parrain. Doivent rester alignés sur l'Edge
/// Function `grant-referral-reward` (3e filleul récompensé : +30 j, 5e : +90 j).
const List<int> kReferralMilestones = [3, 5];

/// Barre de progression vers le prochain palier. Un filleul n'est compté
/// qu'une fois « récompensé », c'est-à-dire après sa première session de
/// lecture terminée : on le dit, pour que personne ne croie à un bug.
class _MilestoneProgress extends StatelessWidget {
  final int rewarded;
  const _MilestoneProgress({required this.rewarded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    int? target;
    for (final m in kReferralMilestones) {
      if (rewarded < m) {
        target = m;
        break;
      }
    }

    final decoration = BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    );

    if (target == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Text(l.referralProgressDone, style: theme.textTheme.bodyMedium),
      );
    }

    final reward = target == 3 ? l.referralReward3 : l.referralReward5;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.referralProgressTitle(target),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$rewarded/$target',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (rewarded / target).clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reward,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.referralProgressHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
