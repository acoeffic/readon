// lib/pages/profile/manage_subscription_page.dart
// Écran de gestion d'abonnement : infos + redirection vers le store pour
// se désabonner. Conforme aux directives Apple (cancel = écran natif).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/subscription_provider.dart';
import '../../services/native_paywall_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';

class ManageSubscriptionPage extends StatefulWidget {
  const ManageSubscriptionPage({super.key});

  @override
  State<ManageSubscriptionPage> createState() => _ManageSubscriptionPageState();
}

class _ManageSubscriptionPageState extends State<ManageSubscriptionPage> {
  final SubscriptionService _service = SubscriptionService();
  SubscriptionDetails? _details;
  bool _loading = true;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final details = await _service.getSubscriptionDetails();
    if (!mounted) return;
    setState(() {
      _details = details;
      _loading = false;
    });
  }

  Future<void> _openManageSubscriptions() async {
    await _service.showManageSubscriptions();
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final ok = await _service.restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.purchasesRestored : l.noPurchasesToRestore),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) {
      await context.read<SubscriptionProvider>().refreshStatus();
      await _load();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _planLabel(String? productId) {
    if (productId == null) return '—';
    if (productId.contains('yearly') || productId.contains('annual')) {
      return 'Annuel';
    }
    if (productId.contains('monthly')) return 'Mensuel';
    return productId;
  }

  String _priceLabel(String? productId) {
    if (productId == null) return '';
    if (productId.contains('yearly') || productId.contains('annual')) {
      return '39,99 €/an';
    }
    if (productId.contains('monthly')) return '3,99 €/mois';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        title: Text(l.manageSubscriptionTitle),
        backgroundColor: colors.scaffoldBg,
        elevation: 0,
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(l, colors),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, AppThemeColors colors) {
    final details = _details;
    final isPremium = details?.isPremium ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPremium && details != null) ..._buildPremiumCard(l, colors, details),
          if (!isPremium) ..._buildFreeCard(l, colors),
          const SizedBox(height: AppSpace.l),
          GestureDetector(
            onTap: _restoring ? null : _restore,
            child: _restoring
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(
                    l.restorePurchases,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary.withValues(alpha: 0.6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPremiumCard(
    AppLocalizations l,
    AppThemeColors colors,
    SubscriptionDetails details,
  ) {
    final plan = _planLabel(details.productId);
    final price = _priceLabel(details.productId);
    return [
      Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'LexDay Premium',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: details.status == 'trial'
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    details.status == 'trial' ? l.freeTrial : l.premiumActive,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: details.status == 'trial'
                          ? AppColors.primary
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            _DetailRow(label: l.subPlanLabel, value: plan),
            if (price.isNotEmpty)
              _DetailRow(label: l.subPriceLabel, value: price),
            if (details.originalPurchaseDate != null)
              _DetailRow(
                label: l.subStartDateLabel,
                value: _formatDate(details.originalPurchaseDate!),
              ),
            if (details.expiresAt != null)
              _DetailRow(
                label: details.willRenew
                    ? l.subNextRenewalLabel
                    : l.subEndsOnLabel,
                value: _formatDate(details.expiresAt!),
              ),
            _DetailRow(
              label: l.subAutoRenewLabel,
              value: details.willRenew ? l.enabled : l.disabled,
              valueColor: details.willRenew
                  ? AppColors.primary
                  : AppColors.error,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.l),
      Text(
        l.manageSubscriptionHint,
        style: TextStyle(
          fontSize: 12,
          color: colors.textPrimary.withValues(alpha: 0.55),
          height: 1.4,
        ),
      ),
      const SizedBox(height: AppSpace.m),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _openManageSubscriptions,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(
            l.manageSubscriptionButton,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            elevation: 0,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildFreeCard(AppLocalizations l, AppThemeColors colors) {
    return [
      Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.noActiveSubscription,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.noActiveSubscriptionHint,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.l),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => NativePaywallService.present(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            elevation: 0,
          ),
          child: Text(
            l.upgradeToPremium,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ];
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
