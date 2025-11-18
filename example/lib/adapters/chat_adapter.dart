import 'package:example/models/chat_model.dart';
import 'package:offline_db/offline_db.dart';

class ChatAdapter extends OfflineAdapter<ChatModel> {
  @override
  String getId(ChatModel item) => item.id;

  @override
  Map<String, dynamic> toJson(ChatModel item) {
    return {
      'id': item.id,
      'title': item.title,
      'avatar_url': item.avatarUrl,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  ChatModel fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'],
      title: json['title'],
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  OfflineObject<ChatModel> resolveConflict(
    OfflineObject<ChatModel> local,
    OfflineObject<ChatModel> remote,
  ) {
    return local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote;
  }
}
