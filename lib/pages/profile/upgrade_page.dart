// lib/pages/profile/upgrade_page.dart
// Page paywall pour s'abonner à LexDay Premium

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/feature_flags.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import '../../widgets/constrained_content.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

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
  // Par défaut on sélectionne l'annuel
  bool _annualSelected = true;

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
          _error = 'Impossible de charger les offres';
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
            const SnackBar(
              content: Text('Bienvenue dans LexDay Premium !'),
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
            const SnackBar(
              content: Text('Abonnement restauré !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun abonnement trouvé'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(
                title: 'LexDay Premium',
                titleColor: AppColors.primary,
              ),
              const SizedBox(height: AppSpace.xl),

              // Header illustration
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),
              Center(
                child: Text(
                  'Passe au niveau supérieur',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Center(
                child: Text(
                  'Débloque toutes les fonctionnalités Premium',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpace.xl),

              // Features list
              ...Feature.values.map((feature) => _FeatureRow(
                    feature: feature,
                    isHighlighted: feature == widget.highlightedFeature,
                  )),

              const SizedBox(height: AppSpace.xl),

              // Plan selector
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              else ...[
                _buildPlanCards(isDark),

                const SizedBox(height: AppSpace.l),

                // Bouton d'achat
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _purchasing ? null : _purchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      elevation: 0,
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
                                ? 'Commencer l\'essai gratuit'
                                : 'S\'abonner',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppSpace.m),

                // Restaurer les achats
                Center(
                  child: TextButton(
                    onPressed: _restoring ? null : _restorePurchases,
                    child: _restoring
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Restaurer les achats',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppSpace.s),

                // Liens légaux
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://readon.app/terms'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'CGU',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://readon.app/privacy'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'Politique de confidentialité',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildPlanCards(bool isDark) {
    final offering = _offerings?.current;
    final annual = offering?.annual;
    final monthly = offering?.monthly;

    return Column(
      children: [
        // Annuel
        if (annual != null)
          _PlanCard(
            title: 'Annuel',
            price: annual.storeProduct.priceString,
            period: '/an',
            badge: 'Essai gratuit 7 jours',
            isSelected: _annualSelected,
            onTap: () => setState(() => _annualSelected = true),
            isDark: isDark,
          ),

        const SizedBox(height: AppSpace.s),

        // Mensuel
        if (monthly != null)
          _PlanCard(
            title: 'Mensuel',
            price: monthly.storeProduct.priceString,
            period: '/mois',
            isSelected: !_annualSelected,
            onTap: () => setState(() => _annualSelected = false),
            isDark: isDark,
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final Feature feature;
  final bool isHighlighted;

  const _FeatureRow({
    required this.feature,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: isHighlighted
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Icon(
                FeatureFlags.icon(feature),
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FeatureFlags.title(feature),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FeatureFlags.description(feature),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppSpace.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$price$period',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
