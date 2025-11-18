import 'package:example/models/user_model.dart';
import 'package:offline_db/offline_db.dart';

import '../adapters/user_adapter.dart';

class UserNode extends OfflineNode<UserModel> {
  UserNode() : super('user', adapter: UserAdapter());
}
