import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

enum Feature {
  advancedReactions,
  streakAutoFreeze,
  advancedStats,
  customThemes,
  premiumBadges,
  streakHistory,
}

class FeatureFlags {
  static const _premiumFeatures = <Feature>{
    Feature.advancedReactions,
    Feature.streakAutoFreeze,
    Feature.advancedStats,
    Feature.customThemes,
    Feature.premiumBadges,
    Feature.streakHistory,
  };

  /// Vérifie si une feature est disponible
  static bool isAvailable(Feature feature, {required bool isPremium}) {
    if (!_premiumFeatures.contains(feature)) return true;
    return isPremium;
  }

  /// Raccourci avec BuildContext (lit le SubscriptionProvider)
  static bool isUnlocked(BuildContext context, Feature feature) {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    return isAvailable(feature, isPremium: isPremium);
  }

  static String title(Feature feature) {
    switch (feature) {
      case Feature.advancedReactions:
        return 'Réactions avancées';
      case Feature.streakAutoFreeze:
        return 'Streak auto-freeze';
      case Feature.advancedStats:
        return 'Statistiques avancées';
      case Feature.customThemes:
        return 'Thèmes personnalisés';
      case Feature.premiumBadges:
        return 'Badges Premium';
      case Feature.streakHistory:
        return 'Historique du streak';
    }
  }

  static String description(Feature feature) {
    switch (feature) {
      case Feature.advancedReactions:
        return 'Réagis aux activités de tes amis avec des emojis uniques';
      case Feature.streakAutoFreeze:
        return 'Protège automatiquement ton streak quand tu ne lis pas';
      case Feature.advancedStats:
        return 'Accède à des statistiques détaillées sur ta lecture';
      case Feature.customThemes:
        return 'Personnalise l\'apparence de ton application';
      case Feature.premiumBadges:
        return 'Débloquez 65+ badges exclusifs, animés et secrets';
      case Feature.streakHistory:
        return 'Navigue dans tout ton historique de lecture mois par mois';
    }
  }

  static IconData icon(Feature feature) {
    switch (feature) {
      case Feature.advancedReactions:
        return Icons.emoji_emotions;
      case Feature.streakAutoFreeze:
        return Icons.ac_unit;
      case Feature.advancedStats:
        return Icons.bar_chart;
      case Feature.customThemes:
        return Icons.palette;
      case Feature.premiumBadges:
        return Icons.workspace_premium;
      case Feature.streakHistory:
        return Icons.calendar_month;
    }
  }
}
