import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_conversation.dart';
import '../models/ai_message.dart';
import '../models/feature_flags.dart';
import 'subscription_service.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();

  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  /// Vérifie que l'utilisateur gratuit n'a pas dépassé sa limite mensuelle de messages
  Future<void> _enforceMessageLimit() async {
    final premium = await _subscriptionService.isPremium();
    if (premium) return;

    final count = await getMonthlyMessageCount();
    if (count >= FeatureFlags.maxFreeAiMessages) {
      throw Exception(
        'Limite de ${FeatureFlags.maxFreeAiMessages} messages par mois atteinte. '
        'Abonne-toi pour une utilisation illimitée !',
      );
    }
  }

  /// Récupérer toutes les conversations de l'utilisateur
  Future<List<AiConversation>> getConversations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      final response = await _supabase
          .from('ai_conversations')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => AiConversation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getConversations: $e');
      return [];
    }
  }

  /// Récupérer les messages d'une conversation
  Future<List<AiMessage>> getMessages(int conversationId) async {
    try {
      final response = await _supabase
          .from('ai_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => AiMessage.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur getMessages: $e');
      return [];
    }
  }

  /// Envoyer un message et recevoir la réponse de l'IA.
  /// Si [conversationId] est null, crée une nouvelle conversation.
  Future<Map<String, dynamic>> sendMessage({
    int? conversationId,
    required String message,
  }) async {
    final isNew = conversationId == null;

    // Enforce monthly message limit client-side (also enforced server-side)
    await _enforceMessageLimit();

    final response = await _supabase.functions.invoke(
      'ai-chat',
      body: {
        'conversation_id': conversationId,
        'message': message,
        'is_new_conversation': isNew,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        throw Exception(data['message'] ?? data['error']);
      }
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          throw Exception(decoded['message'] ?? decoded['error']);
        }
        return decoded;
      }
    }

    throw Exception('Réponse inattendue du serveur');
  }

  /// Supprimer une conversation
  Future<void> deleteConversation(int conversationId) async {
    await _supabase
        .from('ai_conversations')
        .delete()
        .eq('id', conversationId);
  }

  /// Nombre de messages envoyés par l'utilisateur ce mois-ci
  Future<int> getMonthlyMessageCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final result = await _supabase.rpc('get_ai_monthly_message_count');
    return (result as int?) ?? 0;
  }

  /// Nombre de messages restants ce mois-ci.
  /// Retourne -1 si l'utilisateur est premium (illimité).
  Future<int> getRemainingMessages() async {
    final premium = await _subscriptionService.isPremium();
    if (premium) return -1;

    final count = await getMonthlyMessageCount();
    return FeatureFlags.maxFreeAiMessages - count;
  }
}
