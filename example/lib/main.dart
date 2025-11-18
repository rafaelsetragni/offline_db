import 'package:example/apis/chat_api_memory.dart';
import 'package:example/pages/sign_in_page.dart';
import 'package:example/services/chat_service.dart';
import 'package:example/services/router_service.dart';
import 'package:flutter/material.dart';

void main() {
  // Initialize the ChatService with the desired API implementation.
  //
  // [ChatApiMemory] is a mock implementation that stores data in memory.
  // It's ideal for local testing and development without a backend.
  // All data is lost when the app is restarted.
  //
  // [ChatApiRedis] is a real implementation that connects to a Redis server.
  // Use this to test synchronization with a persistent remote data source.
  // Make sure you have a Redis server running and configured.
  ChatService()
      .initialize(
        chatApi: ChatApiMemory(),
        // Uncomment the line below to use the Redis implementation:
        // chatApi: ChatApiRedis(host: '127.0.0.1', port: 6379),
      )
      .then((_) {
        runApp(const MyChatApp());
      });
}

class MyChatApp extends StatelessWidget {
  const MyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Demo',
      navigatorKey: RouterService().navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SignInPage(),
    );
  }
}
