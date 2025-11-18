import 'package:example/models/message_model.dart';
import 'package:offline_db/offline_db.dart';

class MessageAdapter extends OfflineAdapter<MessageModel> {
  @override
  String getId(MessageModel item) => item.id;

  @override
  Map<String, dynamic> toJson(MessageModel item) {
    return {
      'id': item.id,
      'chat_id': item.chatId,
      'username': item.username,
      'content': item.content,
      'state': item.state.name,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  MessageModel fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      chatId: json['chat_id'],
      username: json['username'],
      content: json['content'],
      state: MessageState.values.firstWhere((s) => s.name == json['state']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  OfflineObject<MessageModel> resolveConflict(
    OfflineObject<MessageModel> local,
    OfflineObject<MessageModel> remote,
  ) {
    return local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote;
  }
}
