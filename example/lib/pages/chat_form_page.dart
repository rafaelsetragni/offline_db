import 'package:example/services/chat_service.dart';
import 'package:example/services/router_service.dart';
import 'package:flutter/material.dart';

class ChatFormPage extends StatefulWidget {
  const ChatFormPage({super.key});

  @override
  State<ChatFormPage> createState() => _ChatFormPageState();
}

class _ChatFormPageState extends State<ChatFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _avatarUrlController.addListener(() {
      setState(() {
        _avatarUrl = _avatarUrlController.text;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _createChat() {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) return;

    ChatService().createChat(
      title: _titleController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
    );
    RouterService().goBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(_avatarUrl)
                    : null,
                child: _avatarUrl.isEmpty
                    ? const Icon(Icons.chat, size: 50)
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Chat Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a chat title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(
                  labelText: 'Avatar URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createChat,
                child: const Text('Create Chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
