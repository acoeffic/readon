// lib/pages/profile/upgrade_page.dart
// Page paywall pour s'abonner à LexDay Premium

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/feature_flags.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../../widgets/constrained_content.dart';
import '../../theme/app_theme.dart';

/// Ordre d'affichage des features dans le tableau comparatif.
/// On exclut flowHistory car il est fusionné avec flowManualFreeze.
const _displayFeatures = [
  Feature.advancedStats,
  Feature.premiumBadges,
  Feature.aiChat,
  Feature.customLists,
  Feature.kindleAutoSync,
  Feature.flowManualFreeze,
  Feature.advancedReactions,
  Feature.customThemes,
  Feature.aiSummary,
];

const _freeIncluded = [
  'Sessions illimitées',
  'Bibliothèque illimitée',
  'Feed social',
  'Objectifs & badges de base',
  'Wrapped mensuel & annuel',
  'Widget iOS',
];

class UpgradePage extends StatefulWidget {
  final Feature? highlightedFeature;

  const UpgradePage({super.key, this.highlightedFeature});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  final SubscriptionService _service = SubscriptionService();
  Offerings? _offerings;
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;
  String? _error;
  bool _annualSelected = true;
  bool _showAllFeatures = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await _service.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'cannotLoadOffers';
          _loading = false;
        });
      }
    }
  }

  Package? get _selectedPackage {
    final offering = _offerings?.current;
    if (offering == null) return null;

    if (_annualSelected) {
      return offering.annual ?? offering.availablePackages.firstOrNull;
    } else {
      return offering.monthly ?? offering.availablePackages.firstOrNull;
    }
  }

  Future<void> _purchase() async {
    final package = _selectedPackage;
    if (package == null || _purchasing) return;

    setState(() => _purchasing = true);

    try {
      final success = await _service.purchasePackage(package);

      if (success && mounted) {
        await context.read<SubscriptionProvider>().onPurchaseCompleted();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).welcomePremium),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);

    try {
      final success = await _service.restorePurchases();

      if (mounted) {
        if (success) {
          await context.read<SubscriptionProvider>().onPurchaseCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).subscriptionRestored),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).noSubscriptionFound),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.l,
              vertical: AppSpace.m,
            ),
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpace.s),

                // Icon
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, Color(0xFF5C8377)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Title
                Text(
                  l.upgradeToLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  l.lexdayPremium,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  l.unlockPotential,
                  style: TextStyle(
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 22),

                // Section divider
                _SectionDivider(label: l.whatPremiumUnlocks, isDark: isDark),

                const SizedBox(height: 14),

                // Comparison table
                _buildComparisonTable(isDark, onSurface),

                // Show more/less
                if (_displayFeatures.length > 5)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAllFeatures = !_showAllFeatures),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showAllFeatures
                                ? l.seeLess
                                : l.moreFeatures(_displayFeatures.length - 5),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _showAllFeatures ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Free tier reminder
                _buildFreeTierReminder(isDark, onSurface),

                const SizedBox(height: 22),

                // Plan section
                _SectionDivider(label: l.choosePlan, isDark: isDark),

                const SizedBox(height: 14),

                // Plan cards
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Center(
                    child: Text(
                      l.cannotLoadOffers,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else ...[
                  _buildPlanCards(isDark, onSurface),

                  const SizedBox(height: AppSpace.l),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFF5C8377)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _purchasing ? null : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _purchasing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _annualSelected
                                    ? l.startFreeTrial
                                    : l.subscribe,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpace.m),

                  // Subtitle
                  Text(
                    _annualSelected
                        ? l.freeTrialInfo
                        : l.monthlyBillingInfo,
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.35),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpace.s),

                  // Restore
                  GestureDetector(
                    onTap: _restoring ? null : _restorePurchases,
                    child: _restoring
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l.restorePurchases,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.35),
                              decoration: TextDecoration.underline,
                              decorationColor: onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                  ),

                  const SizedBox(height: 10),

                  // Legal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://readon.app/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          l.termsOfUse,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://readon.app/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          'Politique de confidentialité',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.l),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(bool isDark, Color onSurface) {
    final l = AppLocalizations.of(context);
    final features =
        _showAllFeatures ? _displayFeatures : _displayFeatures.take(5).toList();
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;
    final altRowColor = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : AppColors.primary.withValues(alpha: 0.02);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.featureHeader,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    l.freeHeader,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.3),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    l.premiumHeader,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...features.asMap().entries.map((entry) {
            final i = entry.key;
            final feature = entry.value;
            final isHighlighted = feature == widget.highlightedFeature;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (i.isEven ? cardColor : altRowColor),
                border: i < features.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.06),
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Feature name with icon
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          FeatureFlags.icon(feature),
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            FeatureFlags.title(feature),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Free
                  SizedBox(
                    width: 68,
                    child: Text(
                      FeatureFlags.freeDescription(feature),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Premium
                  SizedBox(
                    width: 88,
                    child: Text(
                      FeatureFlags.premiumDescription(feature),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF3D5E53),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFreeTierReminder(bool isDark, Color onSurface) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.04),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          // Dash not available in Flutter borders, using normal thin border
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.alreadyFree,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: onSurface.withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _freeIncluded
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.primary
                            .withValues(alpha: isDark ? 0.1 : 0.08),
                      ),
                      child: Text(
                        '✓ $item',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.primary
                              : const Color(0xFF3D5E53),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCards(bool isDark, Color onSurface) {
    final l = AppLocalizations.of(context);
    final offering = _offerings?.current;
    final annual = offering?.annual;
    final monthly = offering?.monthly;

    // Calcul du prix mensuel équivalent pour l'annuel
    String? annualMonthlyPrice;
    String? savingsPercent;
    if (annual != null && monthly != null) {
      final monthlyAmount = monthly.storeProduct.price;
      final annualMonthly = annual.storeProduct.price / 12;
      annualMonthlyPrice =
          '${annualMonthly.toStringAsFixed(2).replaceAll('.', ',')} ${annual.storeProduct.currencyCode == 'EUR' ? '€' : annual.storeProduct.currencyCode}';
      final savings =
          ((1 - annualMonthly / monthlyAmount) * 100).round();
      if (savings > 0) savingsPercent = 'Économisez $savings%';
    }

    return Column(
      children: [
        // Annual
        if (annual != null)
          _PlanCard(
            title: l.annual,
            isSelected: _annualSelected,
            onTap: () => setState(() => _annualSelected = true),
            isDark: isDark,
            onSurface: onSurface,
            isRecommended: true,
            trialBadge: '7 jours gratuits',
            mainPrice: annualMonthlyPrice ?? annual.storeProduct.priceString,
            mainPeriod: '/mois',
            subtitle: 'puis ${annual.storeProduct.priceString}/an',
            savingsLabel: savingsPercent,
          ),

        const SizedBox(height: 10),

        // Monthly
        if (monthly != null)
          _PlanCard(
            title: l.monthly,
            isSelected: !_annualSelected,
            onTap: () => setState(() => _annualSelected = false),
            isDark: isDark,
            onSurface: onSurface,
            mainPrice: monthly.storeProduct.priceString,
            mainPeriod: '/mois',
            subtitle: 'Sans engagement',
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section divider
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionDivider({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.2);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, lineColor],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lineColor, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Plan card
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color onSurface;
  final bool isRecommended;
  final String? trialBadge;
  final String mainPrice;
  final String mainPeriod;
  final String? subtitle;
  final String? savingsLabel;

  const _PlanCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.onSurface,
    this.isRecommended = false,
    this.trialBadge,
    required this.mainPrice,
    required this.mainPeriod,
    this.subtitle,
    this.savingsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              18,
              isRecommended ? 22 : 18,
              18,
              18,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
                  : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.15),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (trialBadge != null)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                trialBadge!,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3D5E53),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                          ],
                        )
                      else if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          mainPrice,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        Text(
                          mainPeriod,
                          style: TextStyle(
                            fontSize: 11,
                            color: onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    if (savingsLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          savingsLabel!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3D5E53),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Recommended badge
          if (isRecommended)
            Positioned(
              top: -10,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5C8377)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '✦ Recommandé',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Radio indicator
          Positioned(
            top: isRecommended ? 22 : 18,
            right: 18,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
