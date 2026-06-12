// lib/services/session_pause_service.dart
//
// Persists session pause state across app restarts and background transitions.
// Source of truth for the cumulative pause duration of an active session,
// read by [ReadingSessionService.endSession] to subtract idle time from
// the recorded session length.

import 'package:shared_preferences/shared_preferences.dart';

class SessionPauseService {
  static const _kPausedAt = 'session_paused_at';
  static const _kAccumulatedSecs = 'session_accumulated_pause_secs';
  static const _kBackgroundedAt = 'session_backgrounded_at';

  // ── pause start (current ongoing pause) ─────────────────────────────────

  /// Mark the start of a new pause. Leaves the accumulated total untouched.
  Future<void> savePauseStart(DateTime pausedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPausedAt, pausedAt.toIso8601String());
  }

  /// Returns the DateTime at which the current pause started, or null
  /// if the session is not currently paused.
  Future<DateTime?> getPausedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPausedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── accumulated pause (across multiple pause/resume cycles) ─────────────

  /// Returns the accumulated pause duration from finalized pauses
  /// (does not include the ongoing pause, if any).
  Future<Duration> getAccumulatedPauseDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final secs = prefs.getInt(_kAccumulatedSecs) ?? 0;
    return Duration(seconds: secs);
  }

  /// Finalize the current pause: add its duration to the accumulator and
  /// clear the pause start. No-op if not currently paused. Returns the new
  /// total accumulated pause duration.
  Future<Duration> finalizeCurrentPause() async {
    final prefs = await SharedPreferences.getInstance();
    final pausedAtRaw = prefs.getString(_kPausedAt);
    final existingSecs = prefs.getInt(_kAccumulatedSecs) ?? 0;
    if (pausedAtRaw == null) {
      return Duration(seconds: existingSecs);
    }
    final pausedAt = DateTime.tryParse(pausedAtRaw);
    if (pausedAt == null) {
      await prefs.remove(_kPausedAt);
      return Duration(seconds: existingSecs);
    }
    final elapsed = DateTime.now().difference(pausedAt).inSeconds;
    final newTotal = existingSecs + (elapsed < 0 ? 0 : elapsed);
    await prefs.setInt(_kAccumulatedSecs, newTotal);
    await prefs.remove(_kPausedAt);
    return Duration(seconds: newTotal);
  }

  /// Total pause time = accumulated finalized pauses + the ongoing pause
  /// (if currently paused). Use this when computing effective reading time.
  Future<Duration> getTotalPauseDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final accumulated = prefs.getInt(_kAccumulatedSecs) ?? 0;
    final pausedAtRaw = prefs.getString(_kPausedAt);
    int ongoing = 0;
    if (pausedAtRaw != null) {
      final pausedAt = DateTime.tryParse(pausedAtRaw);
      if (pausedAt != null) {
        final delta = DateTime.now().difference(pausedAt).inSeconds;
        if (delta > 0) ongoing = delta;
      }
    }
    return Duration(seconds: accumulated + ongoing);
  }

  /// Clear all pause state — call when the session ends or is cancelled.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPausedAt);
    await prefs.remove(_kAccumulatedSecs);
  }

  // ── background timestamp (used for 4h auto-pause) ───────────────────────

  Future<void> saveBackgroundedAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackgroundedAt, time.toIso8601String());
  }

  Future<void> clearBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBackgroundedAt);
  }

  Future<DateTime?> getBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBackgroundedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
