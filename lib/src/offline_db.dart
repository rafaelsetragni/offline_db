part of '../offline_db.dart';

typedef PushCallback = Future<void> Function(Map<String, dynamic> objects);
typedef PullCallback = Future<Map<String, dynamic>> Function(DateTime? since);

class OfflineDB {
  static OfflineDB? _instance;
  late final List<OfflineNode> _nodes;
  final OfflineLocalDBDelegate _localDB;

  static OfflineDB get instance {
    if (_instance == null) {
      throw StateError(
        'OfflineDB not initialized. Call OfflineDB.initialize() first.',
      );
    }
    return _instance!;
  }

  OfflineLocalDBDelegate get localDB => _localDB;

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

  OfflineNode getNodeByName(String name) {
    return _nodes.firstWhere((node) => node.nodeName == name);
  }

  Future<void> initialize() async {
    await _localDB.initialize();

    for (var node in _nodes) {
      await node.initialize();
    }
  }

  Future<void> clearAllData() async {
    await _localDB.clearAllData();

    for (var node in _nodes) {
      node.reset();
      await node.initialize();
    }
  }

  Future<void> sync({
    required PushCallback onPush,
    required PullCallback onPull,
  }) async {
    await _pullRemoteChanges(onPull);
    await _pushPendingChanges(onPush);
  }

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
      final response = _buildOfflineResponse(map);

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

  OfflineResponse _buildOfflineResponse(Map<String, dynamic> json) {
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
        final deletes = (nodeChangeJson['delete'] as List);
        for (var element in deletes) {
          final object = OfflineObject(
            item: node.adapter.fromJson(Map<String, dynamic>.from(element)),
            status: SyncStatus.ok,
            operation: SyncOperation.delete,
            node: node,
          );
          objects.add(object);
        }
      }

      nodeObjects[node] = objects;
    }
    return OfflineResponse(changes: nodeObjects, timestamp: timestamp);
  }
}
