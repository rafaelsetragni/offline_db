part of '../offline_db.dart';

abstract class OfflineNode<T extends Object> {
  final String nodeName;
  final OfflineAdapter<T> adapter;
  late OfflineDB _db;

  @visibleForTesting
  void injectDB(OfflineDB db) => _db = db;

  OfflineNode(this.nodeName, {required this.adapter});

  factory OfflineNode.standalone(
    String nodeName, {
    required OfflineAdapter<T> adapter,
  }) = _OfflineNode;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void reset() {
    _isInitialized = false;
  }

  Future<void> upsert(T item) async {
    final existingObjects = await _getAll();
    final existingIds = existingObjects
        .map((obj) => adapter.getId(obj.item))
        .toSet();

    if (existingIds.contains(adapter.getId(item))) {
      await update(item);
    } else {
      await insert(item);
    }
  }

  /// Insert a new item
  Future<void> insert(T item) async {
    final offlineObj = OfflineObject(
      item: item,
      status: SyncStatus.pending,
      operation: SyncOperation.insert,
      node: this,
    );

    await _db.localDB.insert(nodeName, offlineObj.toJson());
  }

  /// Update an existing item
  Future<void> update(T item) async {
    final offlineObj = OfflineObject(
      item: item,
      status: SyncStatus.pending,
      operation: SyncOperation.update,
      node: this,
    );

    await _db.localDB.update(
      nodeName,
      adapter.getId(item),
      offlineObj.toJson(),
    );
  }

  /// Delete an item (soft delete)
  Future<void> delete(T item) async {
    final offlineObj = OfflineObject(
      item: item,
      status: SyncStatus.pending,
      operation: SyncOperation.delete,
      node: this,
    );

    await _db.localDB.delete(
      nodeName,
      adapter.getId(item),
      offlineObj.toJson(),
    );
  }

  OfflineQuery<T> query() {
    return OfflineQuery<T>(
      nodeName: nodeName,
      delegate: _db.localDB,
      fromJson: adapter.fromJson,
      node: this,
    );
  }

  Future<void> _mergeRemoteItems(OfflineObjects<T> remoteObjects) async {
    final allLocal = await _getAll(includeDeleted: true);
    final localMap = {for (var obj in allLocal) adapter.getId(obj.item): obj};

    for (var remoteObj in remoteObjects) {
      final remoteId = adapter.getId(remoteObj.item);
      final localObj = localMap[remoteId];

      if (remoteObj.isDeleted) {
        if (localObj != null && !localObj.needSync) {
          await _db.localDB.hardDelete(nodeName, remoteId);
        }
        continue;
      }

      if (localObj == null) {
        await _db.localDB.insert(nodeName, remoteObj.toJson());
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

  Future<List<OfflineObject<T>>> _getPendingObjects() async {
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

  Future<void> _updateObjectStatus(OfflineObject<T> obj) async {
    await _db.localDB.update(nodeName, adapter.getId(obj.item), obj.toJson());
  }

  Future<void> _updateObjectsStatus(
    OfflineObjects<T> objs, [
    OfflineObject<T> Function(OfflineObject<T> obj)? onChange,
  ]) async {
    for (var obj in objs) {
      if (onChange != null) {
        obj = onChange(obj);
      }
      await _updateObjectStatus(obj);
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
}

final class _OfflineNode<T extends Object> extends OfflineNode<T> {
  _OfflineNode(super.nodeName, {required super.adapter});
}
