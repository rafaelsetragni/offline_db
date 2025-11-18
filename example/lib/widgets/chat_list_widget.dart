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
      itemBuilder: (context, index) {
        final chat = chats[index];
        final hasAvatar = chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: hasAvatar ? NetworkImage(chat.avatarUrl!) : null,
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
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: Colors.black12),
      ),
    );
  }
}
