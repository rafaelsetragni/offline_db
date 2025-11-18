import 'dart:async';

import 'package:offline_db/offline_db.dart';

import '../apis/chat_api.dart';

/// A synchronization strategy that triggers synchronization at a fixed time interval.
class PeriodicSyncStrategy extends DataSyncStrategy {
  /// The duration between synchronization attempts.
  final Duration period;
  final ChatApi chatApi;

  Timer? _timer;

  DateTime? lastSyncedAt;

  /// Creates a periodic synchronization strategy.
  ///
  /// [period]: The interval at which the [onSync] callback should be executed.
  PeriodicSyncStrategy({required this.period, required this.chatApi}) {
    start();
  }

  Map<String, List<OfflineObject>> pendingChanges = {};

  void addPendingObject(OfflineObject object) {
    pendingChanges //
        .putIfAbsent(object.nodeName, () => []) //
        .add(object);
  }

  @override
  Future<SyncStatus> onPushToRemote(OfflineObject object) {
    addPendingObject(object);
    // Change was not synced yet
    return Future.value(SyncStatus.pending);
  }

  void start() {
    // Stop any existing timer before starting a new one to avoid multiple timers running.
    stop();
    OfflineDB.awaitInitialization.then((_) async {
      final pendingObjects = await getPendingObjects();
      for (final object in pendingObjects) {
        addPendingObject(object);
      }
      _timer = Timer.periodic(period, onTimerTick);
    });
  }

  Future<void> onTimerTick(_) async {
    final pushFuture = pushToRemote(Map.from(pendingChanges));
    pendingChanges.clear();

    await pushFuture;
    final remoteChanges = await chatApi.pull(lastSyncedAt);
    if (remoteChanges.isEmpty) return;
    await pullChangesToLocal(remoteChanges);
  }

  Future<void> pushToRemote(
    Map<String, List<OfflineObject>> pendingChanges,
  ) async {
    if (pendingChanges.isEmpty) return;
    await chatApi.push(_buildUploadPayload(pendingChanges));
  }

  Map<String, dynamic> _buildUploadPayload(
    Map<String, List<OfflineObject<Object>>> pendingChanges,
  ) {
    return {
      'lastSyncedAt': DateTime.now().toIso8601String(),
      'changes': {
        for (final entry in pendingChanges.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
