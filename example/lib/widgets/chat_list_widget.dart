import 'package:example/models/chat_model.dart';
import 'package:example/services/router_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatListWidget extends StatelessWidget {
  final List<ChatModel> chats;

  const ChatListWidget({super.key, required this.chats});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: chats.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final avatarUrl = chat.avatarUrl;
        final hasAvatar = avatarUrl?.isNotEmpty ?? false;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatarUrl != null && hasAvatar
                ? NetworkImage(avatarUrl)
                : null,
            child: !hasAvatar && chat.title.isNotEmpty
                ? Text(chat.title[0].toUpperCase())
                : null,
          ),
          title: Text(chat.title),
          subtitle: Text(
            'Created at: ${DateFormat.yMd().add_jm().format(chat.createdAt)}',
          ),
          onTap: () {
            RouterService().goToChatPage(chatId: chat.id);
          },
        );
      },
      separatorBuilder: (context, index) => Divider(color: Colors.black12),
    );
  }
}
