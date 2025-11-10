part of '../offline_db.dart';

/// Callback function type for pushing local changes to the server.
///
/// Receives a map containing all pending changes grouped by node name.
typedef PushCallback = Future<void> Function(Map<String, dynamic> objects);

/// Callback function type for pulling remote changes from the server.
///
/// Receives the last sync timestamp and should return a map with server changes.
typedef PullCallback = Future<Map<String, dynamic>> Function(DateTime? since);

/// The central class that manages all nodes and coordinates synchronization.
///
/// This class is responsible for:
/// - Managing multiple [OfflineNode] instances
/// - Coordinating bidirectional synchronization (push/pull)
/// - Maintaining sync state across nodes
/// - Providing access to the local database delegate
class OfflineDB {
  static OfflineDB? _instance;
  late final List<OfflineNode> _nodes;
  final OfflineLocalDBDelegate _localDB;

  /// Gets the singleton instance of OfflineDB.
  ///
  /// Throws [StateError] if OfflineDB hasn't been initialized yet.
  /// Call [initialize] before accessing this instance.
  static OfflineDB get instance {
    if (_instance == null) {
      throw StateError(
        'OfflineDB not initialized. Call OfflineDB.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Gets the local database delegate used for storage.
  OfflineLocalDBDelegate get localDB => _localDB;

  /// Creates an instance of OfflineDB.
  ///
  /// Parameters:
  /// - [nodes]: List of [OfflineNode] instances to be managed
  /// - [localDB]: The local database delegate for storage operations
  ///
  /// Throws [ArgumentError] if there are duplicate node names.
  OfflineDB({
    required List<OfflineNode> nodes,
    required OfflineLocalDBDelegate localDB,
  }) : _localDB = localDB {
    final names = nodes.map((n) => n.nodeName).toSet();
    if (names.length != nodes.length) {
      throw ArgumentError('Duplicate node names');
    }
    for (var node in nodes) {
      node._db = this;
    }

    _nodes = List.unmodifiable(nodes);
    _instance = this;
  }

  /// Gets a node by its name.
  ///
  /// Throws [StateError] if no node with the given name exists.
  OfflineNode getNodeByName(String name) {
    return _nodes.firstWhere((node) => node.nodeName == name);
  }

  /// Initializes the OfflineDB and all its nodes.
  ///
  /// This must be called before using any OfflineDB functionality.
  /// It initializes the local database and all registered nodes.
  Future<void> initialize() async {
    await _localDB.initialize();

    for (var node in _nodes) {
      await node.initialize();
    }
  }

  /// Clears all data from the local database.
  ///
  /// This will delete all stored data and reset all nodes.
  /// Use with caution as this operation cannot be undone.
  Future<void> clearAllData() async {
    await _localDB.clearAllData();

    for (var node in _nodes) {
      node.reset();
      await node.initialize();
    }
  }

  /// Performs bidirectional synchronization with the server.
  ///
  /// First pulls remote changes from the server, then pushes
  /// pending local changes.
  ///
  /// Parameters:
  /// - [onPush]: Callback to send local changes to the server
  /// - [onPull]: Callback to fetch remote changes from the server
  Future<void> sync({
    required PushCallback onPush,
    required PullCallback onPull,
  }) async {
    await _pullRemoteChanges(onPull);
    await _pushPendingChanges(onPush);
  }

  /// Disposes the OfflineDB instance and closes the local database.
  ///
  /// Call this when you're done using the OfflineDB instance.
  Future<void> dispose() async {
    await _localDB.close();
  }

  Future<void> _pushPendingChanges(PushCallback onPush) async {
    final pushMap = <String, dynamic>{};
    final pendingObjects = <OfflineNode, List<OfflineObject>>{};

    for (var node in _nodes) {
      final offlineObjects = await node._getPendingObjects();
      if (offlineObjects.isEmpty) continue;
      pendingObjects[node] = offlineObjects;
      pushMap[node.nodeName] = offlineObjects.toJson();
    }

    if (pendingObjects.isEmpty) {
      return;
    }

    try {
      await onPush(pushMap);

      for (var entry in pendingObjects.entries) {
        final node = entry.key;
        final objects = entry.value;
        await node._updateObjectsStatus(
          objects,
          (obj) => obj.copyWith(status: SyncStatus.ok),
        );
      }
    } catch (e) {
      for (var entry in pendingObjects.entries) {
        final node = entry.key;
        final objects = entry.value;
        await node._updateObjectsStatus(
          objects,
          (obj) => obj.copyWith(status: SyncStatus.failed),
        );
      }
    }
  }

  Future<void> _pullRemoteChanges(PullCallback onPull) async {
    try {
      final lastSyncAt = await _getLastSyncAt();
      final map = await onPull(lastSyncAt);
      final response = await _buildOfflineResponse(map);

      for (var node in response.changes.keys) {
        final objects = response.changes[node]!;
        await node._mergeRemoteItems(objects);
      }

      await _setLastSyncAt(response.timestamp);
    } catch (e) {
      rethrow;
    }
  }

  Future<DateTime?> _getLastSyncAt() async {
    return await localDB.getLastSyncAt('__sync_version__ ');
  }

  Future<void> _setLastSyncAt(DateTime time) async {
    await localDB.setLastSyncAt('__sync_version__', time);
  }

  Future<OfflineResponse> _buildOfflineResponse(
    Map<String, dynamic> json,
  ) async {
    if (json['timestamp'] == null || json['changes'] == null) {
      throw FormatException('Invalid offline response format');
    }

    final timestamp = DateTime.parse(json['timestamp'] as String);
    final changesJson = json['changes'] as Map;
    final nodeObjects = <OfflineNode, List<OfflineObject>>{};

    for (var nodeName in changesJson.keys) {
      final node = getNodeByName(nodeName as String);
      final objects = <OfflineObject>[];

      final nodeChangeJson = changesJson[nodeName] as Map<String, dynamic>;

      if (nodeChangeJson.containsKey('insert')) {
        final inserts = (nodeChangeJson['insert'] as List);
        for (var element in inserts) {
          final object = OfflineObject(
            item: node.adapter.fromJson(Map<String, dynamic>.from(element)),
            status: SyncStatus.ok,
            operation: SyncOperation.insert,
            node: node,
          );
          objects.add(object);
        }
      } else if (nodeChangeJson.containsKey('update')) {
        final updates = (nodeChangeJson['update'] as List);
        for (var element in updates) {
          final object = OfflineObject(
            item: node.adapter.fromJson(Map<String, dynamic>.from(element)),
            status: SyncStatus.ok,
            operation: SyncOperation.update,
            node: node,
          );
          objects.add(object);
        }
      } else if (nodeChangeJson.containsKey('delete')) {
        final deleteIds = (nodeChangeJson['delete'] as List<String>);
        for (var id in deleteIds) {
          final object = await node._getById(id);
          if (object != null) {
            objects.add(
              object.copyWith(
                status: SyncStatus.ok,
                operation: SyncOperation.delete,
              ),
            );
          }
        }
      }

      nodeObjects[node] = objects;
    }
    return OfflineResponse(changes: nodeObjects, timestamp: timestamp);
  }
}
