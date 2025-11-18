import 'package:example/models/chat_model.dart';
import 'package:example/services/chat_service.dart';
import 'package:example/services/router_service.dart';
import 'package:example/widgets/chat_list_widget.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = _chatService.authenticatedUser;
    final avatarUrl = user?.avatarUrl;
    final hasAvatar = avatarUrl?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
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
          return ChatListWidget(chats: chats);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => RouterService().goToChatForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
