import 'dart:convert';

import 'package:redis/redis.dart';

import 'chat_api.dart';

class ChatApiRedis implements ChatApi {
  Command? _command;
  final String host;
  final String? password;
  final int port;

  ChatApiRedis({this.host = '127.0.0.1', this.port = 6379, this.password});

  static const String _redisHistoryKey = 'changes_history';

  Future<Command> _getCommand() async {
    Command? command = _command;
    if (command == null) {
      final conn = RedisConnection();
      command = _command = await conn.connect(host, port);
      if (password != null) {
        // Authenticate if a password is provided.
        final response = await command.send_object(['AUTH', password]);
        // The AUTH command should return 'OK' on success.
        if (response != 'OK') {
          throw Exception('Redis authentication failed: $response');
        }
      }
    }
    return command;
  }

  @override
  Future<void> push(Map<String, dynamic> changes) async {
    final command = await _getCommand();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final nodeName in changes.keys) {
      final operations = changes[nodeName];
      for (final item in (operations['insert'] as List? ?? [])) {
        final event = {'node': nodeName, 'operation': 'insert', 'data': item};
        await command.send_object([
          'ZADD',
          _redisHistoryKey,
          now,
          json.encode(event),
        ]);
      }

      for (final item in (operations['update'] as List? ?? [])) {
        final event = {'node': nodeName, 'operation': 'update', 'data': item};
        await command.send_object([
          'ZADD',
          _redisHistoryKey,
          now,
          json.encode(event),
        ]);
      }

      for (final id in (operations['delete'] as List? ?? [])) {
        final event = {'node': nodeName, 'operation': 'delete', 'id': id};
        await command.send_object([
          'ZADD',
          _redisHistoryKey,
          now,
          json.encode(event),
        ]);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> pull(DateTime? lastSyncAt) async {
    final command = await _getCommand();
    final newTimestamp = DateTime.now();
    final changes = <String, dynamic>{};

    final minScore = lastSyncAt?.millisecondsSinceEpoch ?? 0;

    final historyEvents =
        await command.send_object([
              'ZRANGEBYSCORE',
              _redisHistoryKey,
              minScore.toString(),
              '+inf',
            ])
            as List;

    for (var eventString in historyEvents) {
      final event = json.decode(eventString);
      final nodeName = event['node'];
      final operation = event['operation'];

      changes.putIfAbsent(
        nodeName,
        () => {'insert': [], 'update': [], 'delete': []},
      );

      if (operation == 'delete') {
        if (event['id'] != null) {
          changes[nodeName]['delete'].add(event['id']);
        }
      } else {
        if (event['data'] != null) {
          changes[nodeName][operation].add(event['data']);
        }
      }
    }

    return {'timestamp': newTimestamp.toIso8601String(), 'changes': changes};
  }
}
