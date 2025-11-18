import 'chat_api.dart';

class ChatApiMemory implements ChatApi {
  // Simula o banco de dados do servidor
  final Map<String, Map<String, dynamic>> _serverData = {};
  // Simula o histórico de alterações
  final List<Map<String, dynamic>> _history = [];

  @override
  Future<void> push(Map<String, dynamic> updates) async {
    final now = DateTime.now();

    final Map<String, dynamic> changes = updates['changes'];
    changes.forEach((nodeName, operations) {
      _serverData.putIfAbsent(nodeName, () => {});
      final nodeData = _serverData[nodeName]!;

      // Processar inserções
      (operations['insert'] as List? ?? []).forEach((item) {
        final record = Map<String, dynamic>.from(item);
        final idFieldName = record.keys.first;
        final id = record[idFieldName];
        record['updated_at'] = now.toIso8601String();
        nodeData[id] = record;
        _history.add({
          'timestamp': now,
          'node': nodeName,
          'operation': 'insert',
          'data': record,
        });
      });

      // Processar atualizações
      (operations['update'] as List? ?? []).forEach((item) {
        final record = Map<String, dynamic>.from(item);
        final idFieldName = record.keys.first;
        final id = record[idFieldName];
        record['updated_at'] = now.toIso8601String();
        if (nodeData.containsKey(id)) {
          nodeData[id]!.addAll(record);
        } else {
          nodeData[id] = record;
        }
        _history.add({
          'timestamp': now,
          'node': nodeName,
          'operation': 'update',
          'data': nodeData[id],
        });
      });

      // Processar exclusões
      (operations['delete'] as List? ?? []).forEach((id) {
        nodeData.remove(id);
        _history.add({
          'timestamp': now,
          'node': nodeName,
          'operation': 'delete',
          'id': id,
        });
      });
    });
  }

  @override
  Future<Map<String, dynamic>> pull(DateTime? lastSyncAt) async {
    final newTimestamp = DateTime.now();
    final changes = <String, dynamic>{};

    final relevantHistory = _history.where((record) {
      return lastSyncAt == null || record['timestamp'].isAfter(lastSyncAt);
    });

    for (final record in relevantHistory) {
      final nodeName = record['node'];
      final operation = record['operation'];
      changes.putIfAbsent(
        nodeName,
        () => {'insert': [], 'update': [], 'delete': []},
      );

      if (operation == 'delete') {
        changes[nodeName]['delete'].add(record['id']);
      } else {
        changes[nodeName][operation].add(record['data']);
      }
    }

    return {'timestamp': newTimestamp.toIso8601String(), 'changes': changes};
  }
}
