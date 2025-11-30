import 'package:awesome_task_manager/awesome_task_manager.dart';
import 'package:example/models/chat_model.dart';
import 'package:example/models/message_model.dart';
import 'package:example/nodes/chat_node.dart';
import 'package:example/nodes/message_node.dart';
import 'package:example/services/router_service.dart';
import 'package:example/services/task_service.dart';
import 'package:example/sync_strategies/periodic_sync_strategy.dart';
import 'package:offline_db/offline_db.dart';

import '../apis/chat_api.dart';
import '../models/user_model.dart';
import '../nodes/user_node.dart';

class ChatService {
  static const tag = 'ChatService';
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
  TaskService taskService;

  UserModel? authenticatedUser;

  final ChatNode chatNode;
  final UserNode userNode;
  final MessageNode messageNode;

  ChatService._internal({
    ChatNode? chatNode,
    UserNode? userNode,
    MessageNode? messageNode,
    TaskService? taskService,
  }) : taskService = taskService ?? TaskService(),
       chatNode = chatNode ?? ChatNode(),
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

  Future<OfflineObject<UserModel>?> getUserByUsername(String username) async {
    final results = await userNode
        .query()
        .where('username', isEqualTo: username)
        .getAll();
    return results.isNotEmpty ? results.first : null;
  }

  Stream<List<OfflineObject<MessageModel>>> getChatMessageStream({
    required String chatId,
  }) {
    return messageNode
        .query()
        .where('chat_id', isEqualTo: chatId)
        .orderBy('createdAt')
        .watch();
  }

  Future<TaskResult> sendMessage({
    required String chatId,
    required String content,
  }) {
    return taskService.createTask(tag, 'sendMessage', (
      TaskStatus taskStatus,
    ) async {
      final username = authenticatedUser?.username;
      if (username == null) {
        throw Exception('User not authenticated');
      }

      final message = MessageModel(
        chatId: chatId,
        username: username,
        content: content,
        state: MessageState.pending,
      );

      messageNode.upsert(message);
      return message;
    });
  }

  void createChat({required String title, required String? avatarUrl}) {
    final newChat = ChatModel(title: title, avatarUrl: avatarUrl);
    chatNode.upsert(newChat);
  }
}
