import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

class ShareAssets {
  final String status; // 'none', 'pending', 'rendering', 'done', 'error'
  final String? videoUrl;
  final String? imageUrl;
  final String? dominantColor;
  final String? secondaryColor;

  ShareAssets({
    required this.status,
    this.videoUrl,
    this.imageUrl,
    this.dominantColor,
    this.secondaryColor,
  });

  factory ShareAssets.fromJson(Map<String, dynamic> json) => ShareAssets(
        status: json['status'] as String? ?? 'none',
        videoUrl: json['videoUrl'] as String?,
        imageUrl: json['imageUrl'] as String?,
        dominantColor: json['dominantColor'] as String?,
        secondaryColor: json['secondaryColor'] as String?,
      );

  bool get hasVideo => status == 'done' && videoUrl != null;
  bool get hasImage => imageUrl != null;
  bool get isRendering => status == 'pending' || status == 'rendering';
}

class ReadonSyncService {
  static final _client = http.Client();

  static String get _baseUrl => Env.readonSyncUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  /// Call when user finishes a book. Returns immediately (server renders async).
  static Future<void> finishBook(int bookId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/books/$bookId/finish'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) {
        debugPrint('readon-sync finishBook error: ${response.body}');
      }
    } catch (e) {
      debugPrint('readon-sync finishBook error: $e');
    }
  }

  /// Poll for share asset availability.
  static Future<ShareAssets> getShareAssets(int bookId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/books/$bookId/share'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      return ShareAssets(status: 'none');
    }
    return ShareAssets.fromJson(jsonDecode(response.body));
  }

  /// Trigger async video render for a monthly wrapped.
  static Future<void> renderMonthlyWrapped(int month, int year) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/wrapped/monthly/$year/$month/render'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) {
        debugPrint('readon-sync renderMonthlyWrapped error: ${response.body}');
      }
    } catch (e) {
      debugPrint('readon-sync renderMonthlyWrapped error: $e');
    }
  }

  /// Poll for monthly wrapped video availability.
  static Future<ShareAssets> getMonthlyWrappedShareAssets(
    int month,
    int year,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/wrapped/monthly/$year/$month/share'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) {
        return ShareAssets(status: 'none');
      }
      return ShareAssets.fromJson(jsonDecode(response.body));
    } catch (e) {
      debugPrint('readon-sync getMonthlyWrappedShareAssets error: $e');
      return ShareAssets(status: 'none');
    }
  }
}
