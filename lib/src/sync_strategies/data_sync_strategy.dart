part of '../../offline_db.dart';

/// Defines the contract for different data synchronization strategies.
///
/// Implement this class to create custom sync strategies, such as:
/// - [PeriodicSyncStrategy]: Synchronizes data at a fixed time interval.
/// - [ManualSyncStrategy]: Triggers synchronization on demand.
/// - [ConnectivitySyncStrategy]: Synchronizes when network connectivity is restored.
/// - [WorkManagerSyncStrategy]: Uses a background service for robust synchronization.
/// - [WebSocketSyncStrategy]: Listens to a WebSocket for real-time updates.
abstract class DataSyncStrategy {
  Future<SyncStatus> onPushToRemote(OfflineObject localData);

  Future<List<OfflineObject>> getPendingObjects() {
    return OfflineDB.instance.getAllPendingObjects();
  }

  Future<void> pullChangesToLocal(Map<String, dynamic> remoteChanges) {
    return OfflineDB.instance._pullRemoteChanges(remoteChanges);
  }
}
