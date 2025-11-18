part of '../../offline_db.dart';

/// Represents the synchronization status of an object.
enum SyncStatus {
  /// The object has pending changes that need to be synced.
  pending,

  /// The object is synchronized with the server.
  ok,

  /// The last sync attempt failed (will be retried).
  failed,
}

/// Represents the type of operation performed on an object.
enum SyncOperation {
  /// The object was inserted locally.
  insert,

  /// The object was updated locally.
  update,

  /// The object was deleted locally (soft delete).
  delete,
}

/// Type alias for a list of [OfflineObject]s.
typedef OfflineObjects<T extends Object> = List<OfflineObject<T>>;

/// Wraps an item with its synchronization metadata.
///
/// This class combines your data model with sync information like status,
/// operation type, and whether it needs synchronization.
///
/// All queries return [OfflineObject]s so you can inspect the sync state
/// of each item individually.
class OfflineObject<T extends Object> {
  /// The actual data item.
  final T item;

  /// The current synchronization status.
  final SyncStatus status;

  /// The type of operation (insert, update, delete).
  final SyncOperation operation;

  final OfflineNode<T> _node;

  /// Returns true if this object has pending changes that need sync.
  bool get needSync => status != SyncStatus.ok;

  /// Returns true if this object is marked as deleted.
  bool get isDeleted => operation == SyncOperation.delete;

  String get nodeName => _node.nodeName;

  OfflineObject({
    required this.item,
    required this.status,
    required this.operation,
    required OfflineNode<T> node,
  }) : _node = node;

  /// Converts the object and its metadata to JSON format.
  Map<String, dynamic> toJson() {
    return {
      ..._node.adapter.toJson(item),
      '_sync_status': status.index,
      '_sync_operation': operation.index,
      '_sync_created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this object with optional field updates.
  OfflineObject<T> copyWith({
    T? item,
    SyncStatus? status,
    SyncOperation? operation,
  }) {
    return OfflineObject<T>(
      item: item ?? this.item,
      status: status ?? this.status,
      operation: operation ?? this.operation,
      node: _node,
    );
  }

  OfflineObject<T> fromJson(
    String nodeName,
    Map<String, dynamic> json, {
    SyncStatus syncStatus = SyncStatus.ok,
    SyncOperation operation = SyncOperation.insert,
  }) {
    return OfflineObject<T>(
      item: _node.adapter.fromJson(json),
      status: syncStatus,
      operation: operation,
      node: OfflineDB.instance.getNodeByName(nodeName) as OfflineNode<T>,
    );
  }
}

/// Extension methods for lists of [OfflineObject]s.
extension OffllineObjectsX<T extends Object> on List<OfflineObject<T>> {
  /// Converts a list of objects to the sync JSON format.
  ///
  /// Groups objects by operation type (insert, update, delete) as expected
  /// by the push endpoint.
  Map<String, dynamic> toJson() {
    final inserts = <Map<String, dynamic>>[];
    final updates = <Map<String, dynamic>>[];
    final deletes = <String>[];

    for (var obj in this) {
      final itemJson = obj._node.adapter.toJson(obj.item);

      switch (obj.operation) {
        case SyncOperation.insert:
          inserts.add(itemJson);
          break;
        case SyncOperation.update:
          updates.add(itemJson);
          break;
        case SyncOperation.delete:
          deletes.add(obj._node.adapter.getId(obj.item));
          break;
      }
    }

    return {'insert': inserts, 'update': updates, 'delete': deletes};
  }
}

/// Represents a response from the server during a pull operation.
///
/// Contains all changes from the server grouped by node, along with
/// the server's timestamp for tracking sync progress.
class OfflineResponse {
  /// Map of nodes to their changed objects.
  final Map<OfflineNode, List<OfflineObject>> changes;

  /// Server timestamp when this response was generated.
  final DateTime timestamp;

  OfflineResponse({required this.changes, required this.timestamp});
}
