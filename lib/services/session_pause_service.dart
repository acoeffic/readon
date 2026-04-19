// lib/services/session_pause_service.dart
//
// Persists session pause state across app restarts and background transitions.
// Uses SharedPreferences so there is no database migration required.

import 'package:shared_preferences/shared_preferences.dart';

class SessionPauseService {
  static const _kPausedAt = 'session_paused_at';
  static const _kAccumulatedSecs = 'session_accumulated_pause_secs';
  static const _kBackgroundedAt = 'session_backgrounded_at';

  // ── pause state ──────────────────────────────────────────────────────────

  /// Save the start of a pause together with the duration already accumulated
  /// before this pause (so it can be restored exactly on the next init).
  Future<void> savePause({
    required DateTime pausedAt,
    required Duration alreadyAccumulated,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPausedAt, pausedAt.toIso8601String());
    await prefs.setInt(_kAccumulatedSecs, alreadyAccumulated.inSeconds);
  }

  /// Clear pause state (call when session resumes from pause, or session ends).
  Future<void> clearPause() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPausedAt);
    await prefs.remove(_kAccumulatedSecs);
  }

  /// Returns the DateTime at which the current pause started, or null if not paused.
  Future<DateTime?> getPausedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPausedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Returns the accumulated pause duration that was already stored before the
  /// current pause began. Defaults to Duration.zero.
  Future<Duration> getAccumulatedPauseDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final secs = prefs.getInt(_kAccumulatedSecs) ?? 0;
    return Duration(seconds: secs);
  }

  // ── background timestamp ─────────────────────────────────────────────────

  /// Record when the app went into the background (used for auto-pause logic).
  Future<void> saveBackgroundedAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackgroundedAt, time.toIso8601String());
  }

  /// Remove the background timestamp (call when app comes to the foreground).
  Future<void> clearBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackgroundedAt);
  }

  /// Returns the last background timestamp, or null if not set.
  Future<DateTime?> getBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBackgroundedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
