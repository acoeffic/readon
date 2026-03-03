// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';
import '../models/feature_flags.dart';
import '../models/reading_sheet.dart';

/// Exception levée quand l'utilisateur gratuit a atteint sa limite mensuelle de résumés.
class AiSummaryLimitReachedException implements Exception {
  final String message;
  const AiSummaryLimitReachedException(this.message);
  @override
  String toString() => message;
}

/// Exception levée quand une fonctionnalité est réservée aux utilisateurs Premium.
class AiPremiumRequiredException implements Exception {
  final String message;
  const AiPremiumRequiredException(this.message);
  @override
  String toString() => message;
}

class AiService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Résume une annotation via la Edge Function summarize-passage.
  /// Retourne le résumé généré et le nombre de résumés restants ce mois.
  /// remaining = -1 si premium (illimité).
  Future<({String summary, int remaining})> summarizeAnnotation(
    String annotationId,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'summarize-passage',
        body: {'annotation_id': annotationId},
      );

      final data = _parseResponse(response.data);

      if (data.containsKey('error')) {
        _throwFromErrorData(data);
      }

      return (
        summary: data['summary'] as String? ?? '',
        remaining: data['remaining'] as int? ?? -1,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map<String, dynamic>) {
        _throwFromErrorData(details);
      }
      if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map<String, dynamic>) {
            _throwFromErrorData(decoded);
          }
        } catch (_) {}
      }
      throw Exception('Erreur du serveur');
    }
  }

  /// Nombre de résumés IA restants ce mois-ci.
  /// Retourne -1 si premium (illimité).
  Future<int> getRemainingAiSummaries() async {
    try {
      final premium = await _subscriptionService.isPremium();
      if (premium) return -1;

      final count = await _supabase.rpc(
        'get_ai_usage_count',
        params: {'p_feature': 'summary'},
      );
      return FeatureFlags.maxFreeAiSummaries - ((count as int?) ?? 0);
    } catch (e) {
      debugPrint('Erreur getRemainingAiSummaries: $e');
      return FeatureFlags.maxFreeAiSummaries;
    }
  }

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw Exception('Réponse inattendue du serveur');
  }

  Never _throwFromErrorData(Map<String, dynamic> data) {
    final errorCode = data['error'] as String?;
    final message =
        data['message'] as String? ?? data['error'] as String? ?? 'Erreur inconnue';
    if (errorCode == 'limit_reached') {
      throw AiSummaryLimitReachedException(message);
    }
    if (errorCode == 'premium_required') {
      throw AiPremiumRequiredException(message);
    }
    throw Exception(message);
  }

  /// Génère une fiche de lecture IA pour un livre à partir de toutes ses annotations.
  /// Feature 100% premium.
  /// Si [force] est true, regénère même si une fiche existe déjà.
  Future<ReadingSheet> generateReadingSheet(
    int bookId, {
    bool force = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-reading-sheet',
        body: {'book_id': bookId.toString(), 'force': force},
      );

      final data = _parseResponse(response.data);

      if (data.containsKey('error')) {
        _throwFromErrorData(data);
      }

      return ReadingSheet.fromJson(
        data['reading_sheet'] as Map<String, dynamic>,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map<String, dynamic>) {
        _throwFromErrorData(details);
      }
      if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map<String, dynamic>) {
            _throwFromErrorData(decoded);
          }
        } catch (_) {}
      }
      throw Exception('Erreur du serveur');
    }
  }

  /// Récupère la fiche de lecture en cache (stockée dans user_books).
  /// Retourne null si aucune fiche n'a été générée.
  Future<ReadingSheet?> getCachedReadingSheet(int bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _supabase
          .from('user_books')
          .select('reading_sheet, reading_sheet_generated_at')
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (data == null || data['reading_sheet'] == null) return null;

      DateTime? generatedAt;
      if (data['reading_sheet_generated_at'] != null) {
        generatedAt = DateTime.parse(data['reading_sheet_generated_at'] as String).toLocal();
      }

      return ReadingSheet.fromJson(
        data['reading_sheet'] as Map<String, dynamic>,
        generatedAt: generatedAt,
      );
    } catch (e) {
      debugPrint('Erreur getCachedReadingSheet: $e');
      return null;
    }
  }
}
