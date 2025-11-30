import 'package:example/models/message_model.dart';
import 'package:example/models/user_model.dart';
import 'package:example/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:offline_db/offline_db.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final ChatService _chatService = ChatService();

  MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final currentUser = _chatService.authenticatedUser;
    final isMe = currentUser?.username == message.username;
    final timeLabel = DateFormat.Hm().format(message.createdAt);

    return FutureBuilder<OfflineObject<UserModel>?>(
      future: _chatService.getUserByUsername(message.username),
      builder: (context, snapshot) {
        final user = snapshot.data?.item;
        final hasAvatar =
            user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;

        final avatar = CircleAvatar(
          backgroundImage: hasAvatar ? NetworkImage(user!.avatarUrl!) : null,
          child: !hasAvatar
              ? (user?.username.isNotEmpty == true
                    ? Text(user!.username[0].toUpperCase())
                    : const Icon(Icons.person))
              : null,
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) avatar,
              if (!isMe) const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        user?.username ?? '...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? ColorScheme.of(context).primaryContainer
                            : ColorScheme.of(context).tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.content,
                            style: TextStyle(
                              color: isMe
                                  ? ColorScheme.of(context).onPrimaryContainer
                                  : ColorScheme.of(context).onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? ColorScheme.of(context).onPrimaryContainer
                                  : ColorScheme.of(context).onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
