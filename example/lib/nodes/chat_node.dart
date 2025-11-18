import 'package:example/models/chat_model.dart';
import 'package:offline_db/offline_db.dart';

import '../adapters/chat_adapter.dart';

class ChatNode extends OfflineNode<ChatModel> {
  ChatNode() : super('chat', adapter: ChatAdapter());
}
