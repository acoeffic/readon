import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

enum Feature {
  advancedReactions,
  flowManualFreeze,
  advancedStats,
  customThemes,
  premiumBadges,
  flowHistory,
  kindleAutoSync,
  customLists,
  aiChat,
}

class FeatureFlags {
  /// Limite de listes personnalisées pour les utilisateurs gratuits
  static const maxFreeCustomLists = 5;

  /// Limite de clubs de lecture pour les utilisateurs gratuits
  static const maxFreeGroups = 5;

  /// Limite de messages IA par mois pour les utilisateurs gratuits
  static const maxFreeAiMessages = 3;

  static const _premiumFeatures = <Feature>{
    Feature.advancedReactions,
    Feature.flowManualFreeze,
    Feature.advancedStats,
    Feature.customThemes,
    Feature.premiumBadges,
    Feature.flowHistory,
    Feature.kindleAutoSync,
    Feature.aiChat,
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
      case Feature.flowManualFreeze:
        return 'Freeze manuel';
      case Feature.advancedStats:
        return 'Statistiques avancées';
      case Feature.customThemes:
        return 'Thèmes personnalisés';
      case Feature.premiumBadges:
        return 'Badges Premium';
      case Feature.flowHistory:
        return 'Historique du flow';
      case Feature.kindleAutoSync:
        return 'Sync Kindle automatique';
      case Feature.customLists:
        return 'Listes de lecture';
      case Feature.aiChat:
        return 'Muse - Conseillère lecture';
    }
  }

  static String description(Feature feature) {
    switch (feature) {
      case Feature.advancedReactions:
        return 'Réagis aux activités de tes amis avec des emojis uniques';
      case Feature.flowManualFreeze:
        return 'Protège manuellement ton flow quand tu ne peux pas lire';
      case Feature.advancedStats:
        return 'Accède à des statistiques détaillées sur ta lecture';
      case Feature.customThemes:
        return 'Personnalise l\'apparence de ton application';
      case Feature.premiumBadges:
        return 'Débloquez 65+ badges exclusifs, animés et secrets';
      case Feature.flowHistory:
        return 'Navigue dans tout ton historique de lecture mois par mois';
      case Feature.kindleAutoSync:
        return 'Synchronise automatiquement ta bibliothèque Kindle à chaque ouverture';
      case Feature.customLists:
        return 'Crée tes propres listes de lecture personnalisées';
      case Feature.aiChat:
        return 'Discute avec Muse pour obtenir des recommandations de livres personnalisées';
    }
  }

  static IconData icon(Feature feature) {
    switch (feature) {
      case Feature.advancedReactions:
        return Icons.emoji_emotions;
      case Feature.flowManualFreeze:
        return Icons.shield;
      case Feature.advancedStats:
        return Icons.bar_chart;
      case Feature.customThemes:
        return Icons.palette;
      case Feature.premiumBadges:
        return Icons.workspace_premium;
      case Feature.flowHistory:
        return Icons.calendar_month;
      case Feature.kindleAutoSync:
        return Icons.sync;
      case Feature.customLists:
        return Icons.playlist_add;
      case Feature.aiChat:
        return Icons.auto_awesome;
    }
  }
}
