import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
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
  aiSummary,
  readingSheet,
}

class FeatureFlags {
  /// Limite de listes personnalisées pour les utilisateurs gratuits
  static const maxFreeCustomLists = 5;

  /// Limite de clubs de lecture pour les utilisateurs gratuits
  static const maxFreeGroups = 5;

  /// Limite de messages IA par mois pour les utilisateurs gratuits
  static const maxFreeAiMessages = 3;

  /// Limite de résumés IA par mois pour les utilisateurs gratuits
  static const maxFreeAiSummaries = 3;

  /// Limite de transcriptions vocales par mois pour les utilisateurs gratuits
  static const maxFreeVoiceTranscriptions = 3;

  static const _premiumFeatures = <Feature>{
    Feature.advancedReactions,
    Feature.flowManualFreeze,
    // Feature.advancedStats — débloqué en gratuit le 19/08/2026 :
    // le suivi des performances alimente la boucle d'activation
    // (livre → 1re session), il ne doit pas être paywallé.
    Feature.customThemes,
    Feature.premiumBadges,
    Feature.flowHistory,
    Feature.kindleAutoSync,
    Feature.aiChat,
    Feature.aiSummary,
    Feature.readingSheet,
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

  static String title(Feature feature, AppLocalizations l) {
    switch (feature) {
      case Feature.advancedReactions:
        return l.ffTitleAdvancedReactions;
      case Feature.flowManualFreeze:
        return l.ffTitleFlowManualFreeze;
      case Feature.advancedStats:
        return l.ffTitleAdvancedStats;
      case Feature.customThemes:
        return l.ffTitleCustomThemes;
      case Feature.premiumBadges:
        return l.ffTitlePremiumBadges;
      case Feature.flowHistory:
        return l.ffTitleFlowHistory;
      case Feature.kindleAutoSync:
        return l.ffTitleKindleAutoSync;
      case Feature.customLists:
        return l.ffTitleCustomLists;
      case Feature.aiChat:
        return l.ffTitleAiChat;
      case Feature.aiSummary:
        return l.ffTitleAiSummary;
      case Feature.readingSheet:
        return l.ffTitleReadingSheet;
    }
  }

  static String description(Feature feature, AppLocalizations l) {
    switch (feature) {
      case Feature.advancedReactions:
        return l.ffDescAdvancedReactions;
      case Feature.flowManualFreeze:
        return l.ffDescFlowManualFreeze;
      case Feature.advancedStats:
        return l.ffDescAdvancedStats;
      case Feature.customThemes:
        return l.ffDescCustomThemes;
      case Feature.premiumBadges:
        return l.ffDescPremiumBadges;
      case Feature.flowHistory:
        return l.ffDescFlowHistory;
      case Feature.kindleAutoSync:
        return l.ffDescKindleAutoSync;
      case Feature.customLists:
        return l.ffDescCustomLists;
      case Feature.aiChat:
        return l.ffDescAiChat;
      case Feature.aiSummary:
        return l.ffDescAiSummary;
      case Feature.readingSheet:
        return l.ffDescReadingSheet;
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
      case Feature.aiSummary:
        return Icons.auto_awesome;
      case Feature.readingSheet:
        return Icons.menu_book;
    }
  }

  static String freeDescription(Feature feature, AppLocalizations l) {
    switch (feature) {
      case Feature.advancedStats:
        return l.ffFreeBasic;
      case Feature.premiumBadges:
        return l.ffFreeLocked;
      case Feature.aiChat:
        return l.ffFreeAiChat;
      case Feature.aiSummary:
        return l.ffFreeAiSummary;
      case Feature.customLists:
        return l.ffFreeCustomLists;
      case Feature.customThemes:
        return l.ffFreeCustomThemes;
      case Feature.kindleAutoSync:
        return l.ffFreeManual;
      case Feature.flowManualFreeze:
        return l.ffFreeSimpleCounter;
      case Feature.flowHistory:
        return l.ffFreeSimpleCounter;
      case Feature.advancedReactions:
        return l.ffFreeLikes;
      case Feature.readingSheet:
        return l.ffFreeUnavailable;
    }
  }

  static String premiumDescription(Feature feature, AppLocalizations l) {
    switch (feature) {
      case Feature.advancedStats:
        return l.ffPremAdvancedStats;
      case Feature.premiumBadges:
        return l.ffPremPremiumBadges;
      case Feature.aiChat:
        return l.ffPremUnlimited;
      case Feature.aiSummary:
        return l.ffPremUnlimited;
      case Feature.customLists:
        return l.ffPremUnlimitedPlural;
      case Feature.customThemes:
        return l.ffPremCustomThemes;
      case Feature.kindleAutoSync:
        return l.ffPremAutomatic;
      case Feature.flowManualFreeze:
        return l.ffPremFreezeHistory;
      case Feature.flowHistory:
        return l.ffPremFreezeHistory;
      case Feature.advancedReactions:
        return l.ffPremAdvancedReactions;
      case Feature.readingSheet:
        return l.ffPremReadingSheet;
    }
  }
}
