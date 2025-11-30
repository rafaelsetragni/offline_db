import 'package:example/models/chat_model.dart';
import 'package:example/services/chat_service.dart';
import 'package:example/services/router_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:offline_db/offline_db.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();

  void _signOut() {
    _chatService.signOut();
    RouterService().goToSignIn();
  }

  Future<bool?> _showDeleteConfirmationDialog(String chatId) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: const Text(
            'Are you sure you want to delete this chat? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _chatService.chatNode.delete(chatId);
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _chatService.authenticatedUser;
    final avatarUrl = user?.avatarUrl;
    final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage: avatarUrl != null && hasAvatar
                    ? NetworkImage(avatarUrl)
                    : null,
                child: !hasAvatar && user.username.isNotEmpty
                    ? Text(user.username[0].toUpperCase())
                    : null,
              ),
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: StreamBuilder<List<OfflineObject<ChatModel>>>(
        stream: _chatService.chatNode.query().watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final chats = snapshot.data?.map((e) => e.item).toList() ?? [];
          return ListView.separated(
            itemCount: chats.length,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (context, index) =>
                Divider(color: Colors.black12),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final avatarUrl = chat.avatarUrl;
              final hasAvatar = avatarUrl?.isNotEmpty ?? false;

              return Dismissible(
                key: ValueKey(chat.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _showDeleteConfirmationDialog(chat.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 28,
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
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => RouterService().goToChatForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
