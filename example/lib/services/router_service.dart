import 'package:example/pages/chat_form_page.dart';
import 'package:example/pages/chat_list_page.dart';
import 'package:example/pages/chat_page.dart';
import 'package:example/pages/sign_in_page.dart';
import 'package:flutter/material.dart';

class RouterService {
  static final RouterService _instance = RouterService._internal();

  factory RouterService() {
    return _instance;
  }

  RouterService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> goToChatList() {
    return navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ChatListPage()),
      (route) => false,
    );
  }

  Future<void> goToSignIn() {
    return navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (route) => false,
    );
  }

  Future<void> goToChatPage({required String chatId}) {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId)),
    );
  }

  Future<void> goToChatForm() {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const ChatFormPage()),
    );
  }

  void goBack() {
    navigatorKey.currentState!.pop();
  }
}
