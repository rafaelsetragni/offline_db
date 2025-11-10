part of '../offline_db.dart';

enum SyncStatus { pending, ok, failed }

enum SyncOperation { insert, update, delete }

typedef OfflineObjects<T extends Object> = List<OfflineObject<T>>;

class OfflineObject<T extends Object> {
  final T item;
  final SyncStatus status;
  final SyncOperation operation;
  final OfflineNode<T> _node;

  bool get needSync => status != SyncStatus.ok;
  bool get isDeleted => operation == SyncOperation.delete;

  OfflineObject({
    required this.item,
    required this.status,
    required this.operation,
    required OfflineNode<T> node,
  }) : _node = node;

  Map<String, dynamic> toJson() {
    return {
      ..._node.adapter.toJson(item),
      '_sync_status': status.index,
      '_sync_operation': operation.index,
      '_sync_created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

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
}

extension OffllineObjectsX<T extends Object> on List<OfflineObject<T>> {
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

class OfflineResponse {
  final Map<OfflineNode, List<OfflineObject>> changes;
  final DateTime timestamp;

  OfflineResponse({required this.changes, required this.timestamp});
}
