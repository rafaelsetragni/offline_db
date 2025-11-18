import 'package:example/utils/uuid_util.dart';

class ChatModel {
  final String id;
  final String title;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    String? id,
    required this.title,
    this.avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })
      : id = id ?? UuidUtil.generateLuid(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}
