// lib/services/notion_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class NotionService {
  static final NotionService _instance = NotionService._internal();
  factory NotionService() => _instance;
  NotionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const _keyConnected = 'notion_connected';
  static const _keyWorkspaceName = 'notion_workspace_name';

  /// Callback invoked when the OAuth deep link is received.
  void Function(String code)? onOAuthCallback;

  // ── Local cache ──────────────────────────────────────────

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConnected) ?? false;
  }

  Future<String?> getWorkspaceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkspaceName);
  }

  Future<void> _cacheConnection(String workspaceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConnected, true);
    await prefs.setString(_keyWorkspaceName, workspaceName);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConnected);
    await prefs.remove(_keyWorkspaceName);
  }

  // ── OAuth URL ────────────────────────────────────────────

  String getOAuthUrl() {
    final clientId = Env.notionClientId;
    const redirectUri = 'lexday://notion/callback';
    return 'https://api.notion.com/v1/oauth/authorize'
        '?client_id=$clientId'
        '&response_type=code'
        '&owner=user'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}';
  }

  // ── Exchange code for token ──────────────────────────────

  Future<String> exchangeCode(String code) async {
    final response = await _supabase.functions.invoke(
      'notion-oauth-callback',
      body: {'code': code, 'redirect_uri': 'lexday://notion/callback'},
    );

    final data = _parseResponse(response.data);

    if (data.containsKey('error')) {
      throw Exception(data['message'] as String? ?? data['error'] as String? ?? 'Erreur Notion');
    }

    final workspaceName = data['workspace_name'] as String? ?? 'Notion';
    await _cacheConnection(workspaceName);
    return workspaceName;
  }

  // ── Sync reading sheet ───────────────────────────────────

  Future<String> syncReadingSheet(int bookId) async {
    final response = await _supabase.functions.invoke(
      'sync-notion-reading-sheet',
      body: {'book_id': bookId.toString()},
    );

    final data = _parseResponse(response.data);

    if (data.containsKey('error')) {
      final errorCode = data['error'] as String?;
      if (errorCode == 'notion_not_connected') {
        await _clearCache();
      }
      throw Exception(data['message'] as String? ?? data['error'] as String? ?? 'Erreur sync Notion');
    }

    return data['notion_url'] as String? ?? '';
  }

  // ── Disconnect ───────────────────────────────────────────

  Future<void> disconnect() async {
    await _supabase.functions.invoke(
      'notion-oauth-callback',
      body: {'action': 'disconnect'},
    );
    await _clearCache();
  }

  // ── Deep link handler ────────────────────────────────────

  void handleDeepLink(Uri uri) {
    if (uri.scheme == 'lexday' && uri.host == 'notion' && uri.path.startsWith('/callback')) {
      final code = uri.queryParameters['code'];
      if (code != null && onOAuthCallback != null) {
        onOAuthCallback!(code);
      }
    }
  }

  // ── Load connection from server (at startup or settings open) ──

  Future<void> refreshConnectionStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        await _clearCache();
        return;
      }

      final data = await _supabase
          .from('profiles')
          .select('notion_workspace_name, notion_connected_at')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && data['notion_connected_at'] != null) {
        final name = data['notion_workspace_name'] as String? ?? 'Notion';
        await _cacheConnection(name);
      } else {
        await _clearCache();
      }
    } catch (e) {
      debugPrint('NotionService.refreshConnectionStatus: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw Exception('Réponse inattendue du serveur');
  }
}
