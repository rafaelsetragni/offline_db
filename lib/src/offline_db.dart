part of '../offline_db.dart';

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

  final List<DataSyncStrategy> syncStrategies;
  static final Completer _onInitialize = Completer();

  static Future get awaitInitialization => _onInitialize.future;

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
    required this.syncStrategies,
  }) : assert(
         syncStrategies.isNotEmpty,
         'You need to provide at least one sync strategy.',
       ),
       _localDB = localDB {
    final names = nodes.map((n) => n.nodeName).toSet();
    if (names.length != nodes.length) {
      throw ArgumentError('Duplicate node names');
    }
    for (var node in nodes) {
      node._db = this;
      node._syncStrategies = syncStrategies;
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
    _onInitialize.complete();
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

  /// Disposes the OfflineDB instance and closes the local database.
  ///
  /// Call this when you're done using the OfflineDB instance.
  Future<void> dispose() async {
    await _localDB.close();
  }

  Future<void> _pullRemoteChanges(Map<String, dynamic> map) async {
    final OfflineResponse response = await _buildOfflineResponse(map);

    for (final MapEntry<OfflineNode, OfflineObjects> entry
        in response.changes.entries) {
      final OfflineNode node = entry.key;
      final OfflineObjects remoteObjects = entry.value;
      await node._mergeRemoteItems(remoteObjects);
    }

    await _setLastSyncAt(response.timestamp);
  }

  Future<OfflineObjects> getAllPendingObjects() async {
    final results = await Future.wait([
      for (var node in _nodes) node.getPendingObjects(),
    ]);
    return results.expand((e) => e).toList();
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
