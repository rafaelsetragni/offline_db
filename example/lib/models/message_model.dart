import '../utils/uuid_util.dart';

enum MessageState { pending, success, failed }

class MessageModel {
  final String id;
  final String chatId;
  final String username;
  final String content;
  final MessageState state;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageModel({
    String? id,
    required this.chatId,
    required this.username,
    required this.content,
    required this.state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? UuidUtil.generateLuid(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
