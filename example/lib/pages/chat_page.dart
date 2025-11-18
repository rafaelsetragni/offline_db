import 'package:example/models/chat_model.dart';
import 'package:example/models/message_model.dart';
import 'package:example/models/user_model.dart';
import 'package:example/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:offline_db/offline_db.dart';

class ChatPage extends StatefulWidget {
  final String chatId;

  const ChatPage({super.key, required this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  ChatModel? _chat;

  @override
  void initState() {
    super.initState();
    _loadChatDetails();
  }

  Future<void> _loadChatDetails() async {
    final chatObject = await _chatService.getChatById(widget.chatId);
    if (chatObject != null) {
      setState(() {
        _chat = chatObject.item;
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    _chatService.sendMessage(
      chatId: widget.chatId,
      content: _messageController.text.trim(),
    );
    _messageController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _chat?.avatarUrl != null && _chat!.avatarUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_chat != null)
              CircleAvatar(
                backgroundImage: hasAvatar
                    ? NetworkImage(_chat!.avatarUrl!)
                    : null,
                child: !hasAvatar && _chat!.title.isNotEmpty
                    ? Text(_chat!.title[0].toUpperCase())
                    : null,
              ),
            const SizedBox(width: 12),
            Text(_chat?.title ?? 'Chat'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<OfflineObject<MessageModel>>>(
              stream: _chatService.messageNode
                  .query()
                  .where('chatId', isEqualTo: widget.chatId)
                  .orderBy('createdAt')
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                final messages = snapshot.data!.map((e) => e.item).toList();
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return _MessageBubble(message: message);
                  },
                );
              },
            ),
          ),
          _MessageInputField(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final ChatService _chatService = ChatService();

  _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final currentUser = _chatService.authenticatedUser;
    final isMe = currentUser?.username == message.username;

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
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                        ),
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

class _MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInputField({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.send), onPressed: onSend),
          ],
        ),
      ),
    );
  }
}
