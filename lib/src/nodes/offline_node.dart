part of '../../offline_db.dart';

/// Represents a data collection (similar to a table).
///
/// Each node manages a specific type of object and handles CRUD operations
/// independently. Nodes can be used standalone or by inheritance.
///
/// Example:
/// ```dart
/// class ChatService extends OfflineNode<Chat> {
///   ChatService() : super('chat', adapter: ChatAdapter());
/// }
/// ```
abstract class OfflineNode<T extends Object> {
  /// The unique name identifier for this node.
  final String nodeName;

  /// The adapter used to serialize/deserialize objects of type [T].
  final OfflineAdapter<T> adapter;

  late OfflineDB _db;

  late List<DataSyncStrategy> _syncStrategies;

  @visibleForTesting
  void injectDB(OfflineDB db) => _db = db;

  /// Creates a new OfflineNode.
  ///
  /// Parameters:
  /// - [nodeName]: Unique identifier for this node
  /// - [adapter]: Adapter for object serialization
  OfflineNode(this.nodeName, {required this.adapter});

  /// Creates a standalone instance of OfflineNode.
  ///
  /// Use this factory when you prefer not to use inheritance.
  ///
  /// Example:
  /// ```dart
  /// final userNode = OfflineNode.standalone(
  ///   'users',
  ///   adapter: SimpleAdapter<User>(...),
  /// );
  /// ```
  factory OfflineNode.standalone(
    String nodeName, {
    required OfflineAdapter<T> adapter,
  }) = _OfflineNode;

  bool _isInitialized = false;

  /// Initializes the node.
  ///
  /// This is called automatically by [OfflineDB.initialize].
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Resets the node's initialization state.
  ///
  /// Used internally when clearing all data.
  void reset() {
    _isInitialized = false;
  }

  Future<void> _pushLocalObject(OfflineObject<T> object) async {
    for (var strategy in _syncStrategies) {
      try {
        final syncResult = await strategy.onPushToRemote(object);
        if (syncResult != object.status) {
          object._node._updateObjectStatus(object.copyWith(status: syncResult));
        }
        switch (syncResult) {
          case SyncStatus.ok:
            return;
          case SyncStatus.pending:
          case SyncStatus.failed:
            continue;
        }
      } catch (e) {
        object._node._updateObjectStatus(
          object.copyWith(status: SyncStatus.failed),
        );
      }
    }
  }

  /// Inserts or updates an item (upsert operation).
  ///
  /// If an item with the same ID already exists, it will be updated.
  /// Otherwise, a new item will be inserted.
  ///
  /// The operation is marked as pending and will be synced on next [OfflineDB.sync].
  Future<void> upsert(T item) async {
    final json = await _db.localDB.getById(nodeName, adapter.getId(item));
    if (json != null) {
      await _update(_offlineObjectFromJson(json).copyWith(item: item));
    } else {
      await _insert(item);
    }
  }

  Future<void> _insert(T item) async {
    final offlineObj = OfflineObject(
      item: item,
      status: SyncStatus.pending,
      operation: SyncOperation.insert,
      node: this,
    );

    final insertFuture = _db.localDB.insert(
      nodeName,
      offlineObj.toJson(),
      adapter.idFieldName,
    );

    final pushFuture = _pushLocalObject(offlineObj);
    await Future.wait([pushFuture, insertFuture]);
  }

  Future<void> _update(OfflineObject<T> object) async {
    await _db.localDB.update(
      nodeName,
      adapter.getId(object.item),
      object //
          .copyWith(
            status: SyncStatus.pending,
            operation:
                object.needSync && object.operation == SyncOperation.insert
                ? SyncOperation.insert
                : SyncOperation.update,
          )
          .toJson(),
    );
  }

  /// Deletes an item by its ID (soft delete).
  ///
  /// The item is marked as deleted and will be synced on next [OfflineDB.sync].
  /// If the item was inserted locally and not yet synced, it will be permanently
  /// removed from local storage.
  ///
  /// Parameters:
  /// - [id]: The unique identifier of the item to delete
  Future<void> delete(String id) async {
    final json = await _db.localDB.getById(nodeName, id);
    if (json == null) {
      return;
    }

    final object = _offlineObjectFromJson(json);

    if (object.needSync && object.operation == SyncOperation.insert) {
      await _db.localDB.delete(nodeName, id);
      return;
    }

    await _db.localDB.update(
      nodeName,
      adapter.getId(object.item),
      object //
          .copyWith(status: SyncStatus.pending, operation: SyncOperation.delete)
          .toJson(),
    );
  }

  /// Creates a query for this node.
  ///
  /// Use this to perform filtered, ordered, and paginated queries.
  ///
  /// Example:
  /// ```dart
  /// final activeUsers = await userNode
  ///   .query()
  ///   .where('status', isEqualTo: 'active')
  ///   .getAll();
  /// ```
  OfflineQuery<T> query() {
    return OfflineQuery<T>(
      nodeName: nodeName,
      delegate: _db.localDB,
      fromJson: adapter.fromJson,
      node: this,
    );
  }

  Future<void> _mergeRemoteItems(OfflineObjects remoteObjects) async {
    final OfflineObjects<T> allLocal = await _getAll(includeDeleted: true);
    final Map<String, OfflineObject<T>> localMap = {
      for (var obj in allLocal) adapter.getId(obj.item): obj,
    };

    for (final OfflineObject remoteObj in remoteObjects) {
      final remoteId = adapter.getId(remoteObj.item as T);
      final localObj = localMap[remoteId];

      if (remoteObj.isDeleted) {
        if (localObj != null && !localObj.needSync) {
          await _db.localDB.delete(nodeName, remoteId);
        }
        continue;
      }

      if (localObj == null) {
        await _db.localDB.insert(
          nodeName,
          remoteObj.toJson(),
          adapter.idFieldName,
        );
        continue;
      }

      if (localObj.needSync) {
        continue;
      }

      final updatedObj = remoteObj.copyWith(
        status: SyncStatus.ok,
        operation: SyncOperation.update,
      );
      await _db.localDB.update(nodeName, remoteId, updatedObj.toJson());
    }
  }

  Future<List<OfflineObject<T>>> getPendingObjects() async {
    final allObjects = await _getAll(includeDeleted: true);
    return allObjects.where((obj) => obj.needSync).toList();
  }

  Future<List<OfflineObject<T>>> _getAll({bool includeDeleted = false}) async {
    final maps = await _db.localDB.getAll(nodeName);
    return maps
        .map(_offlineObjectFromJson)
        .where((obj) => includeDeleted || !obj.isDeleted)
        .toList();
  }

  Future<void> _updateObjectStatus(OfflineObject obj) async {
    await _db.localDB.update(
      nodeName,
      adapter.getId(obj.item as T),
      obj.toJson(),
    );
  }

  Future<void> _updateObjectsStatus(
    OfflineObjects objects, [
    OfflineObject Function(OfflineObject obj)? onChange,
  ]) async {
    for (OfflineObject object in objects) {
      if (onChange != null) {
        object = onChange(object);
      }
      await _updateObjectStatus(object);
    }
  }

  OfflineObject<T> _offlineObjectFromJson(Map<String, dynamic> json) {
    final status = SyncStatus.values[json['_sync_status'] as int];
    final operation = SyncOperation.values[json['_sync_operation'] as int];

    final itemJson = Map<String, dynamic>.from(json)
      ..remove('_sync_status')
      ..remove('_sync_operation')
      ..remove('_sync_created_at');

    return OfflineObject(
      item: adapter.fromJson(itemJson),
      status: status,
      operation: operation,
      node: this,
    );
  }

  Future<OfflineObject<T>?> _getById(String id) async {
    final json = await _db.localDB.getById(nodeName, id);
    if (json == null) {
      return null;
    }
    return _offlineObjectFromJson(json);
  }

  T fromJson(Map<String, dynamic> json) => adapter.fromJson(json);
}

final class _OfflineNode<T extends Object> extends OfflineNode<T> {
  _OfflineNode(super.nodeName, {required super.adapter});
}
