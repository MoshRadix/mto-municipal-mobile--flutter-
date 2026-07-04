import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static const int batchSize = 5;
  final ApiService _apiService;
  final DatabaseService _dbService;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  // Callback when sync finishes (used to notify Providers)
  void Function()? onSyncComplete;
  void Function(String message)? onSyncError;

  SyncService({required this._apiService, required this._dbService});

  // Initialize connectivity monitoring
  void initMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasConnection) {
        debugPrint('Network connection detected, triggering auto sync...');
        syncNow();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  bool get isSyncing => _isSyncing;

  // Trigger sync of all offline drafts
  Future<void> syncNow() async {
    if (_isSyncing) return;

    // Check if we actually have internet before attempting
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      onSyncError?.call('No internet connection available.');
      return;
    }

    // Verify authentication
    String? cookie;
    try {
      cookie = await _apiService.getSessionCookie();
    } catch (_) {}

    if (cookie == null) {
      debugPrint('Sync skipped: User is not authenticated.');
      return;
    }

    final drafts = await _dbService.getDrafts();
    if (drafts.isEmpty) {
      debugPrint('Sync: No local drafts to sync.');
      return;
    }

    _isSyncing = true;
    debugPrint('Sync: Starting sync for ${drafts.length} drafts...');

    int successCount = 0;
    int failCount = 0;

    for (var start = 0; start < drafts.length; start += batchSize) {
      final batch = drafts.skip(start).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((draft) async {
          try {
            await _apiService.createIssue(
              title: draft.title,
              category: draft.category,
              description: draft.description,
              gpsLocation: draft.gpsLocation,
              localPhotoPaths: draft.localPhotoPaths,
            );
            await _dbService.deleteDraft(draft.id);
            return true;
          } catch (e) {
            debugPrint('Error syncing draft ${draft.id}: $e');
            return false;
          }
        }),
      );
      for (final succeeded in results) {
        succeeded ? successCount++ : failCount++;
      }
    }

    _isSyncing = false;

    if (successCount > 0) {
      onSyncComplete?.call();
    }

    if (failCount > 0) {
      onSyncError?.call(
        'Failed to sync $failCount issues. They will be retried later.',
      );
    }
  }
}
