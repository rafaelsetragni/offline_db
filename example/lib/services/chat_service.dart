import 'package:example/models/chat_model.dart';
import 'package:example/models/message_model.dart';
import 'package:example/nodes/chat_node.dart';
import 'package:example/nodes/message_node.dart';
import 'package:example/services/router_service.dart';
import 'package:example/sync_strategies/periodic_sync_strategy.dart';
import 'package:offline_db/offline_db.dart';

import '../apis/chat_api.dart';
import '../models/user_model.dart';
import '../nodes/user_node.dart';

class ChatService {
  static ChatService? _instance;

  factory ChatService({
    ChatNode? chatNode,
    UserNode? userNode,
    MessageNode? messageNode,
  }) => _instance ??= ChatService._internal(
    chatNode: chatNode,
    userNode: userNode,
    messageNode: messageNode,
  );

  OfflineDB? offlineDB;

  UserModel? authenticatedUser;

  final ChatNode chatNode;
  final UserNode userNode;
  final MessageNode messageNode;

  ChatService._internal({
    ChatNode? chatNode,
    UserNode? userNode,
    MessageNode? messageNode,
  }) : chatNode = chatNode ?? ChatNode(),
       messageNode = messageNode ?? MessageNode(),
       userNode = userNode ?? UserNode();

  Future<void> initialize({
    required ChatApi chatApi,
    OfflineDB? mockedDb,
  }) async {
    final offlineDB = this.offlineDB ??=
        mockedDb ??
        OfflineDB(
          nodes: [chatNode, messageNode, userNode],
          localDB: HiveOfflineDelegate(),
          syncStrategies: [
            PeriodicSyncStrategy(
              period: Duration(seconds: 5),
              chatApi: chatApi,
            ),
          ],
        );

    await offlineDB.initialize();
  }

  Future<void> signIn({
    required String username,
    required String? avatarUrl,
  }) async {
    final user = authenticatedUser = UserModel(
      username: username,
      avatarUrl: avatarUrl,
    );
    await userNode.upsert(user);
    RouterService().goToChatList();
  }

  Future<void> signOut() async {
    authenticatedUser = null;
    RouterService().goToSignIn();
  }

  Future<void> saveChat(ChatModel chat) async {
    await chatNode.upsert(chat);
  }

  Future<OfflineObject<ChatModel>?> getChatById(String chatId) async {
    final results = await chatNode
        .query()
        .where('id', isEqualTo: chatId)
        .getAll();
    return results.isNotEmpty ? results.first : null;
  }

  void sendMessage({required String chatId, required String content}) {
    if (authenticatedUser == null) {
      throw Exception('User not authenticated');
    }

    final message = MessageModel(
      chatId: chatId,
      username: authenticatedUser!.username,
      content: content,
      state: MessageState.pending,
    );
    messageNode.upsert(message);
  }

  Future<OfflineObject<UserModel>?> getUserByUsername(String username) async {
    final results = await userNode
        .query()
        .where('username', isEqualTo: username)
        .getAll();
    return results.isNotEmpty ? results.first : null;
  }

  void createChat({required String title, required String? avatarUrl}) {
    final newChat = ChatModel(title: title, avatarUrl: avatarUrl);
    ChatService().chatNode.upsert(newChat);
  }
}
