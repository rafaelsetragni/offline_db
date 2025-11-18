import 'package:offline_db/offline_db.dart';

import '../adapters/message_adapter.dart';
import '../models/message_model.dart';

class MessageNode extends OfflineNode<MessageModel> {
  MessageNode() : super('message', adapter: MessageAdapter());
}
