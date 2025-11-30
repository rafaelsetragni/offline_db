import 'package:example/models/chat_model.dart';
import 'package:example/models/message_model.dart';
import 'package:example/services/chat_service.dart';
import 'package:example/widgets/message_bubble.dart';
import 'package:example/widgets/message_input_field.dart';
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
    final messageContent = _messageController.text.trim();
    if (messageContent.isEmpty) return;

    _chatService
        .sendMessage(chatId: widget.chatId, content: messageContent)
        .then((result) {
          result.fold(
            onSuccess: (_) {
              _messageController.clear();
              FocusScope.of(context).unfocus();
            },
            onFailure: (error) {
              if (!mounted) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(error.toString()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final avatarUrl = chat?.avatarUrl;
    final chatTitle = _chat?.title;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_chat != null)
              CircleAvatar(
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child:
                    avatarUrl == null &&
                        chatTitle != null &&
                        chatTitle.isNotEmpty
                    ? Text(chatTitle[0].toUpperCase())
                    : null,
              ),
            const SizedBox(width: 12),
            Text(chatTitle ?? 'Chat'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<OfflineObject<MessageModel>>>(
              stream: _chatService.getChatMessageStream(chatId: widget.chatId),
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
                    return MessageBubble(message: message);
                  },
                );
              },
            ),
          ),
          MessageInputField(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
