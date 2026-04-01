// lib/providers/connectivity_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_session_queue.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final Connectivity _connectivity = Connectivity();

  /// Nombre de sessions synchronisées lors de la dernière reconnexion
  int _lastSyncCount = 0;
  int get lastSyncCount => _lastSyncCount;

  /// Callback appelé après une synchronisation réussie
  VoidCallback? onSyncCompleted;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = !result.contains(ConnectivityResult.none);
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur checkConnectivity: $e');
    }

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        notifyListeners();
        if (_isOnline) {
          _syncOfflineData();
        }
      }
    });
  }

  Future<void> _syncOfflineData() async {
    try {
      final queue = OfflineSessionQueue();
      final pendingCount = await queue.getPendingCount();
      if (pendingCount == 0) return;

      final syncedCount = await queue.syncAll();
      _lastSyncCount = syncedCount;
      notifyListeners();
      onSyncCompleted?.call();
    } catch (e) {
      debugPrint('Erreur syncOfflineData: $e');
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
