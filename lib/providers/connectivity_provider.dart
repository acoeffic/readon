// lib/providers/connectivity_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline_session_queue.dart';

class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Connectivity _connectivity = Connectivity();

  /// Garde anti-réentrance : une seule sync de la file offline à la fois
  /// (le retour au premier plan et la transition de connectivité peuvent
  /// arriver quasi simultanément).
  bool _isSyncing = false;

  /// Nombre de sessions synchronisées lors de la dernière reconnexion
  int _lastSyncCount = 0;
  int get lastSyncCount => _lastSyncCount;

  /// Callback appelé après une synchronisation réussie
  VoidCallback? onSyncCompleted;

  ConnectivityProvider() {
    WidgetsBinding.instance.addObserver(this);
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

    // Au lancement : si on est en ligne, pousser tout de suite la file
    // offline. Sans ça, la sync n'avait lieu que sur une TRANSITION
    // offline→online pendant que l'app tournait : une session enregistrée
    // en mode avion puis l'app fermée n'était jamais uploadée au
    // lancement suivant.
    if (_isOnline) {
      _syncOfflineData();
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

  /// Retour de l'app au premier plan : re-vérifier la connectivité (l'OS ne
  /// notifie pas toujours les changements survenus en arrière-plan) et
  /// retenter la sync de la file offline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAndSync();
    }
  }

  Future<void> _refreshAndSync() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final nowOnline = !result.contains(ConnectivityResult.none);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erreur checkConnectivity (resume): $e');
    }
    if (_isOnline) {
      await _syncOfflineData();
    }
  }

  Future<void> _syncOfflineData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final queue = OfflineSessionQueue();
      final pendingCount = await queue.getPendingCount();
      if (pendingCount == 0) return;

      final syncedCount = await queue.syncAll();
      if (syncedCount > 0) {
        _lastSyncCount = syncedCount;
        notifyListeners();
        onSyncCompleted?.call();
      }
    } catch (e) {
      debugPrint('Erreur syncOfflineData: $e');
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }
}
