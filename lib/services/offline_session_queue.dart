// lib/services/offline_session_queue.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_session.dart';
import 'challenge_service.dart';

class OfflineSessionQueue {
  static const _startKey = 'offline_pending_start_sessions';
  static const _endKey = 'offline_pending_end_sessions';

  final SupabaseClient _supabase = Supabase.instance.client;
  final ChallengeService _challengeService = ChallengeService();

  /// Queue une nouvelle session de lecture (démarrage offline)
  Future<ReadingSession> queueStartSession({
    required String bookId,
    required int startPage,
    String? startImagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _getList(prefs, _startKey);

    final now = DateTime.now();
    final tempId = 'offline_${now.microsecondsSinceEpoch}';
    final userId = _supabase.auth.currentUser!.id;

    final entry = {
      'temp_id': tempId,
      'book_id': bookId,
      'start_page': startPage,
      'start_time': now.toUtc().toIso8601String(),
      'user_id': userId,
      if (startImagePath != null) 'start_image_path': startImagePath,
    };

    pending.add(entry);
    await prefs.setString(_startKey, jsonEncode(pending));

    return ReadingSession(
      id: tempId,
      userId: userId,
      bookId: bookId,
      startPage: startPage,
      startTime: now,
      startImagePath: startImagePath,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Queue la fin d'une session (terminaison offline)
  Future<ReadingSession> queueEndSession({
    required ReadingSession activeSession,
    required int endPage,
    String? endImagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _getList(prefs, _endKey);

    final now = DateTime.now();

    final entry = {
      'session_id': activeSession.id,
      'end_page': endPage,
      'end_time': now.toUtc().toIso8601String(),
      if (endImagePath != null) 'end_image_path': endImagePath,
      // Stocker les infos du livre pour la mise à jour des défis au sync
      'book_id': activeSession.bookId,
      'start_page': activeSession.startPage,
      'start_time': activeSession.startTime.toUtc().toIso8601String(),
    };

    pending.add(entry);
    await prefs.setString(_endKey, jsonEncode(pending));

    return activeSession.copyWith(
      endPage: endPage,
      endTime: now,
      endImagePath: endImagePath,
      updatedAt: now,
    );
  }

  /// Nombre total d'opérations en attente
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final starts = _getList(prefs, _startKey);
    final ends = _getList(prefs, _endKey);
    return starts.length + ends.length;
  }

  /// Vérifie s'il existe une session active offline pour un livre donné
  Future<ReadingSession?> getOfflineActiveSession(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final starts = _getList(prefs, _startKey);

    for (final entry in starts) {
      if (entry['book_id'] == bookId) {
        return ReadingSession(
          id: entry['temp_id'] as String,
          userId: entry['user_id'] as String,
          bookId: entry['book_id'] as String,
          startPage: entry['start_page'] as int,
          startTime: DateTime.parse(entry['start_time'] as String).toLocal(),
          startImagePath: entry['start_image_path'] as String?,
          createdAt: DateTime.parse(entry['start_time'] as String).toLocal(),
          updatedAt: DateTime.parse(entry['start_time'] as String).toLocal(),
        );
      }
    }
    return null;
  }

  /// Récupère toutes les sessions actives offline
  Future<List<ReadingSession>> getAllOfflineActiveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final starts = _getList(prefs, _startKey);

    return starts.map((entry) => ReadingSession(
      id: entry['temp_id'] as String,
      userId: entry['user_id'] as String,
      bookId: entry['book_id'] as String,
      startPage: entry['start_page'] as int,
      startTime: DateTime.parse(entry['start_time'] as String).toLocal(),
      startImagePath: entry['start_image_path'] as String?,
      createdAt: DateTime.parse(entry['start_time'] as String).toLocal(),
      updatedAt: DateTime.parse(entry['start_time'] as String).toLocal(),
    )).toList();
  }

  /// Synchronise toutes les opérations en attente avec Supabase
  /// Retourne le nombre d'opérations synchronisées avec succès
  Future<int> syncAll() async {
    int synced = 0;

    // 1. Synchroniser les démarrages d'abord
    synced += await _syncStarts();

    // 2. Puis les fins de session
    synced += await _syncEnds();

    return synced;
  }

  Future<int> _syncStarts() async {
    final prefs = await SharedPreferences.getInstance();
    final starts = _getList(prefs, _startKey);
    if (starts.isEmpty) return 0;

    int synced = 0;
    final remaining = <Map<String, dynamic>>[];
    // Mapping temp_id -> real_id pour résoudre les fins qui référencent un temp_id
    final idMapping = <String, String>{};

    for (final entry in starts) {
      try {
        final insertData = <String, dynamic>{
          'book_id': entry['book_id'],
          'start_page': entry['start_page'],
          'start_time': entry['start_time'],
          'user_id': entry['user_id'],
        };
        if (entry['start_image_path'] != null) {
          insertData['start_image_path'] = entry['start_image_path'];
        }

        final response = await _supabase
            .from('reading_sessions')
            .insert(insertData)
            .select()
            .single();

        final realId = response['id'] as String;
        idMapping[entry['temp_id'] as String] = realId;
        synced++;
      } catch (e) {
        debugPrint('Erreur sync start session: $e');
        remaining.add(entry);
      }
    }

    await prefs.setString(_startKey, jsonEncode(remaining));

    // Mettre à jour les fins de session qui référencent des temp_ids
    if (idMapping.isNotEmpty) {
      await _updateEndSessionIds(idMapping);
    }

    return synced;
  }

  Future<void> _updateEndSessionIds(Map<String, String> idMapping) async {
    final prefs = await SharedPreferences.getInstance();
    final ends = _getList(prefs, _endKey);
    bool updated = false;

    for (final entry in ends) {
      final sessionId = entry['session_id'] as String;
      if (idMapping.containsKey(sessionId)) {
        entry['session_id'] = idMapping[sessionId];
        updated = true;
      }
    }

    if (updated) {
      await prefs.setString(_endKey, jsonEncode(ends));
    }
  }

  Future<int> _syncEnds() async {
    final prefs = await SharedPreferences.getInstance();
    final ends = _getList(prefs, _endKey);
    if (ends.isEmpty) return 0;

    int synced = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final entry in ends) {
      final sessionId = entry['session_id'] as String;

      // Si c'est encore un temp_id, on ne peut pas synchroniser
      if (sessionId.startsWith('offline_')) {
        remaining.add(entry);
        continue;
      }

      try {
        final updateData = <String, dynamic>{
          'end_page': entry['end_page'],
          'end_time': entry['end_time'],
        };
        if (entry['end_image_path'] != null) {
          updateData['end_image_path'] = entry['end_image_path'];
        }

        await _supabase
            .from('reading_sessions')
            .update(updateData)
            .eq('id', sessionId);

        // Mettre à jour la progression des défis
        try {
          final startPage = entry['start_page'] as int;
          final endPage = entry['end_page'] as int;
          final startTime = DateTime.parse(entry['start_time'] as String);
          final endTime = DateTime.parse(entry['end_time'] as String);
          final pagesRead = endPage - startPage;
          final durationMinutes = endTime.difference(startTime).inMinutes;

          await _challengeService.updateProgressAfterSession(
            bookId: entry['book_id'] as String,
            pagesRead: pagesRead,
            durationMinutes: durationMinutes,
          );
        } catch (e) {
          debugPrint('Erreur sync challenge progress: $e');
        }

        synced++;
      } catch (e) {
        debugPrint('Erreur sync end session: $e');
        remaining.add(entry);
      }
    }

    await prefs.setString(_endKey, jsonEncode(remaining));
    return synced;
  }

  /// Supprime une session offline démarrée (pour annulation)
  Future<void> removeOfflineStartSession(String tempId) async {
    final prefs = await SharedPreferences.getInstance();
    final starts = _getList(prefs, _startKey);
    starts.removeWhere((entry) => entry['temp_id'] == tempId);
    await prefs.setString(_startKey, jsonEncode(starts));
  }

  List<Map<String, dynamic>> _getList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      debugPrint('Erreur parse offline queue ($key): $e');
      return [];
    }
  }
}
