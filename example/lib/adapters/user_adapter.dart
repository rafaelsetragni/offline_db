import 'package:offline_db/offline_db.dart';

import '../models/user_model.dart';

class UserAdapter extends OfflineAdapter<UserModel> {
  UserAdapter() : super(idFieldName: 'username');

  @override
  String getId(UserModel item) => item.username;

  @override
  Map<String, dynamic> toJson(UserModel item) {
    return {
      'username': item.username,
      'avatar_url': item.avatarUrl,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  UserModel fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'],
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  OfflineObject<UserModel> resolveConflict(
    OfflineObject<UserModel> local,
    OfflineObject<UserModel> remote,
  ) {
    return local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote;
  }
}
