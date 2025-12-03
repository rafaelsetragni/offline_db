import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import 'package:offline_db/offline_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CounterService().initialize().then((signedUser) {
    runApp(
      MyApp(home: signedUser != null ? const MyHomePage() : const SignInPage()),
    );
  });
}

/// Root widget configuring theme and navigation key.
class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Counter',
      navigatorKey: CounterService().navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: home,
    );
  }
}

/// Simple sign-in form to capture the username.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final username = _usernameController.text;
    await CounterService().signIn(username: username);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Offline Counter',
                      style: TextTheme.of(context).headlineMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sign In',
                      style: TextTheme.of(context).labelLarge?.copyWith(
                        color: ColorScheme.of(context).primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _signIn,
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main screen showing counter, users, logs, and avatar editing.
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  Future<void> _onAvatarTap(BuildContext context, String currentAvatar) async {
    final url = await _promptAvatarDialog(context, currentAvatar);
    if (url == null) return;
    await CounterService().updateAvatarUrl(url);
  }

  Future<String?> _promptAvatarDialog(
    BuildContext context,
    String currentAvatar,
  ) async {
    final controller = TextEditingController(text: currentAvatar);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update avatar URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Avatar URL',
              hintText: 'https://example.com/avatar.png',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = CounterService().authenticatedUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await CounterService().signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: StreamBuilder(
          stream: CounterService().watchUsers(),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? const [];
            final avatarMap = {
              for (final u in users) u.item.username: u.item.avatarUrl,
            };
            final currentUserAvatar =
                avatarMap[user.username] ?? user.avatarUrl ?? '';

            return StreamBuilder(
              stream: CounterService().watchLogs(),
              builder: (context, logsSnapshot) {
                final logs = logsSnapshot.data ?? const [];
                final total = logs.fold<int>(
                  0,
                  (sum, log) => sum + log.item.increment,
                );
                final recentLogs = logs.take(5).toList();

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _onAvatarTap(context, currentUserAvatar),
                          child: AvatarPreview(
                            avatarUrl: currentUserAvatar,
                            showEditIndicator: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hello, ${user.username}!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Text('Global counter updated by all users:'),
                        if (logsSnapshot.connectionState ==
                            ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Text(
                            '$total',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.15,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Users:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child:
                                  usersSnapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: users.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final item = users[index];
                                        final avatar =
                                            item.item.avatarUrl ?? '';
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundImage: avatar.isNotEmpty
                                                  ? NetworkImage(avatar)
                                                  : null,
                                              child: avatar.isEmpty
                                                  ? const Icon(
                                                      Icons.person,
                                                      size: 22,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(item.item.username),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Recent activities:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          color: ColorScheme.of(context).surfaceContainerLow,
                          padding: const EdgeInsets.all(24.0),
                          height: MediaQuery.of(context).size.height * 0.35,
                          child:
                              logsSnapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: recentLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = recentLogs[index];
                                    final avatar =
                                        avatarMap[log.item.username] ?? '';
                                    return _buildLogTile(context, log, avatar);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: CounterService().incrementCounter,
            tooltip: 'Increment',
            heroTag: 'increment_fab',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: CounterService().decrementCounter,
            tooltip: 'Decrement',
            heroTag: 'decrement_fab',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(
    BuildContext context,
    OfflineObject<CounterLogModel> log,
    String avatarUrl,
  ) {
    final createdAt = log.item.createdAt;
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${log.item.increment >= 0 ? 'Increased' : 'Decreased'} by ${log.item.increment.abs()} by ${log.item.username}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  formattedDate,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a user avatar with an optional edit badge overlay.
class AvatarPreview extends StatelessWidget {
  final String avatarUrl;
  final bool showEditIndicator;
  const AvatarPreview({
    super.key,
    required this.avatarUrl,
    this.showEditIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
          child: hasAvatar ? null : const Icon(Icons.person, size: 50),
        ),
        if (showEditIndicator)
          Positioned(
            bottom: 4,
            right: 4,
            child: PhysicalModel(
              color: Colors.transparent,
              elevation: 4,
              shadowColor: ColorScheme.of(context).shadow,
              shape: BoxShape.circle,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: ColorScheme.of(context).primaryFixed,
                child: Icon(
                  Icons.edit,
                  size: 16,
                  color: ColorScheme.of(context).onPrimaryFixed,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Central orchestrator for auth, persistence, sync, and navigation.
class CounterService {
  static const tag = 'CounterService';
  static const _prefsLastUsername = 'offline_counter_last_username';
  static CounterService? _instance;
  final navigatorKey = GlobalKey<NavigatorState>();

  factory CounterService({
    OfflineNode<UserModel>? userNode,
    OfflineNode<CounterLogModel>? counterLogNode,
    MongoApi? mongoApi,
    MongoPeriodicSyncStrategy? syncStrategy,
  }) => _instance ??= CounterService._internal(
    userNode: userNode,
    counterLogNode: counterLogNode,
    mongoApi: mongoApi,
    syncStrategy: syncStrategy,
  );

  OfflineDB? offlineDB;

  UserModel? authenticatedUser;
  String _currentNamespace = 'default';

  final OfflineNode<UserModel> userNode;
  final OfflineNode<CounterLogModel> counterLogNode;
  final MongoPeriodicSyncStrategy syncStrategy;

  CounterService._internal({
    OfflineNode<UserModel>? userNode,
    OfflineNode<CounterLogModel>? counterLogNode,
    MongoApi? mongoApi,
    MongoPeriodicSyncStrategy? syncStrategy,
  }) : userNode = userNode ?? _buildUserNode(),
       counterLogNode = counterLogNode ?? _buildCounterLogNode(),
       syncStrategy =
           syncStrategy ??
           MongoPeriodicSyncStrategy(
             period: const Duration(milliseconds: 500),
             mongoApi:
                 mongoApi ??
                 MongoApi(
                   uri:
                       'mongodb://'
                       'admin:admin@127.0.0.1:27017'
                       '/offline_counter?authSource=admin',
                   nodeNames: const ['counter_log', 'user'],
                 ),
           );

  Future<UserModel?> initialize({OfflineDB? mockedDb}) async {
    final offlineDB = this.offlineDB ??=
        mockedDb ??
        OfflineDB(
          nodes: [userNode, counterLogNode],
          localDB: HiveOfflineDelegate(),
          syncStrategies: [syncStrategy],
        );

    await offlineDB.initialize();
    final restored = await restoreLastUser();
    return restored;
  }

  Future<void> signIn({required String username}) async {
    syncStrategy.stop();
    await _switchUserDatabase('');
    await _syncRemoteUsersToLocal();
    final existing = await userNode
        .query()
        .where('username', isEqualTo: username)
        .getAll();
    final preservedAvatar = existing.isNotEmpty
        ? existing.first.item.avatarUrl
        : null;
    final user = authenticatedUser = UserModel(
      username: username,
      avatarUrl: preservedAvatar,
    );
    await userNode.upsert(user);
    await _persistLastUsername(username);
    syncStrategy.start();
    navigateToHome();
  }

  Future<void> _syncRemoteUsersToLocal() async {
    final remote = await syncStrategy.fetchUsers();
    for (final data in remote) {
      try {
        final user = userNode.adapter.fromJson(data);
        await userNode.upsert(user);
      } catch (_) {
        // ignore malformed user entries
      }
    }
  }

  Future<void> signOut() async {
    syncStrategy.stop();
    authenticatedUser = null;
    await _switchUserDatabase('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLastUsername);
    navigateToSignIn();
  }

  Future<UserModel?> restoreUser(String username) async {
    await _switchUserDatabase(username);
    final results = await userNode
        .query()
        .where('username', isEqualTo: username)
        .getAll();
    if (results.isEmpty) return null;
    authenticatedUser = results.first.item;
    syncStrategy.start();
    return authenticatedUser;
  }

  void navigateToHome() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MyHomePage()));
  }

  void navigateToSignIn() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const SignInPage()));
  }

  Future<UserModel?> restoreLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_prefsLastUsername);
    if (username == null) return null;
    return restoreUser(username);
  }

  Future<void> _persistLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastUsername, username);
  }

  Future<List<OfflineObject<UserModel>>> getUsers() {
    return userNode.query().getAll();
  }

  Future<List<OfflineObject<CounterLogModel>>> getLogs() {
    return counterLogNode
        .query()
        .orderBy('created_at', descending: true)
        .getAll();
  }

  Stream<List<OfflineObject<CounterLogModel>>> watchLogs() {
    return counterLogNode
        .query()
        .orderBy('created_at', descending: true)
        .watch();
  }

  Stream<List<OfflineObject<UserModel>>> watchUsers() {
    return userNode.query().orderBy('username').watch();
  }

  Future<Map<String, String?>> getAvatarsForUsers(Set<String> usernames) async {
    if (usernames.isEmpty) return {};
    final results = await userNode
        .query()
        .where('username', whereIn: usernames.toList())
        .getAll();

    final map = <String, String?>{
      for (final user in results) user.item.username: user.item.avatarUrl,
    };

    for (final username in usernames) {
      map.putIfAbsent(username, () => null);
    }

    return map;
  }

  Future<UserModel> updateAvatarUrl(String avatarUrl) async {
    final user = authenticatedUser;
    if (user == null) throw Exception('User not authenticated');

    final updated = UserModel(
      username: user.username,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      createdAt: user.createdAt,
      updatedAt: DateTime.now(),
    );

    await userNode.upsert(updated);
    authenticatedUser = updated;
    return updated;
  }

  void incrementCounter() => _createLog(1);
  void decrementCounter() => _createLog(-1);

  Future<void> _createLog(int increment) async {
    final username = authenticatedUser?.username;
    if (username == null) {
      throw Exception('User not authenticated');
    }

    final log = CounterLogModel(username: username, increment: increment);
    await counterLogNode.upsert(log);
  }

  Future<void> _switchUserDatabase(String username) async {
    final db = offlineDB;
    if (db == null) return;

    final namespace = _sanitizeNamespace(username);
    if (_currentNamespace == namespace) return;
    _currentNamespace = namespace;

    final delegate = db.localDB;
    if (delegate is HiveOfflineDelegate) {
      await delegate.useNamespace(namespace);
    }
  }

  String _sanitizeNamespace(String username) {
    if (username.isEmpty) return 'default';
    final sanitized = username.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    return 'user__$sanitized';
  }
}

/// Domain model for a user with avatar metadata.
class UserModel {
  final String id;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    String? id,
    required this.username,
    required this.avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? username,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final username = json['username'] ?? json['id'];
    return UserModel(
      id: json['id'] ?? username,
      username: username,
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Domain model for counter increment/decrement events.
class CounterLogModel {
  final String id;
  final String username;
  final int increment;
  final DateTime createdAt;
  final DateTime updatedAt;

  CounterLogModel({
    String? id,
    required this.username,
    required this.increment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? '${username}_${DateTime.now().millisecondsSinceEpoch}',
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'increment': increment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CounterLogModel.fromJson(Map<String, dynamic> json) {
    return CounterLogModel(
      id: json['id'],
      username: json['username'],
      increment: json['increment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

OfflineNode<UserModel> _buildUserNode() {
  return OfflineNode.standalone(
    'user',
    adapter: SimpleAdapter<UserModel>(
      getId: (user) => user.id,
      toJson: (user) => user.toJson(),
      fromJson: (json) => UserModel.fromJson(json),
      onConflict: (local, remote) {
        if (local.item.updatedAt == remote.item.updatedAt) return remote;

        final preferred = local.item.updatedAt.isAfter(remote.item.updatedAt)
            ? local
            : remote;

        final fallback = identical(preferred, local) ? remote : local;
        final avatarUrl = preferred.item.avatarUrl ?? fallback.item.avatarUrl;
        return preferred.copyWith(
          item: UserModel(
            id: preferred.item.id,
            username: preferred.item.username,
            avatarUrl: avatarUrl,
            createdAt: preferred.item.createdAt,
            updatedAt: preferred.item.updatedAt,
          ),
        );
      },
    ),
  );
}

OfflineNode<CounterLogModel> _buildCounterLogNode() {
  return OfflineNode.standalone(
    'counter_log',
    adapter: SimpleAdapter<CounterLogModel>(
      getId: (log) => log.id,
      toJson: (log) => log.toJson(),
      fromJson: (json) => CounterLogModel.fromJson(json),
      onConflict: (local, remote) =>
          local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote,
    ),
  );
}

/// Periodically syncs pending changes with MongoDB and pulls updates.
class MongoPeriodicSyncStrategy extends DataSyncStrategy {
  final Duration period;
  final MongoApi mongoApi;

  Timer? _timer;
  DateTime? lastSyncedAt;
  final Map<String, List<OfflineObject>> pendingChanges = {};

  MongoPeriodicSyncStrategy({required this.period, required this.mongoApi});

  void start() {
    stop();
    OfflineDB.awaitInitialization.then((_) async {
      final pendingObjects = await getPendingObjects();
      for (final object in pendingObjects) {
        _addPending(object);
      }
      _timer = Timer.periodic(period, _onTimerTick);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    pendingChanges.clear();
    lastSyncedAt = null;
  }

  void dispose() {
    stop();
  }

  void _addPending(OfflineObject object) {
    pendingChanges.putIfAbsent(object.nodeName, () => []).add(object);
  }

  @override
  Future<SyncStatus> onPushToRemote(OfflineObject object) async {
    _addPending(object);
    return SyncStatus.pending;
  }

  Future<void> _onTimerTick(_) async {
    final changes = Map<String, List<OfflineObject>>.from(pendingChanges);
    pendingChanges.clear();

    await _pushToRemote(changes);
    final remoteChanges = await mongoApi.pull(lastSyncedAt);
    if (remoteChanges.isEmpty) return;

    await pullChangesToLocal(remoteChanges);

    final ts = remoteChanges['timestamp'];
    if (ts is String) {
      lastSyncedAt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      lastSyncedAt = DateTime.now();
    }
  }

  Future<void> _pushToRemote(Map<String, List<OfflineObject>> changes) async {
    if (changes.isEmpty) return;
    await mongoApi.push(_buildUploadPayload(changes));
  }

  Map<String, dynamic> _buildUploadPayload(
    Map<String, List<OfflineObject<Object>>> changes,
  ) {
    return {
      'lastSyncedAt': DateTime.now().toIso8601String(),
      'changes': {
        for (final entry in changes.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  Future<List<Map<String, dynamic>>> fetchUsers() {
    return mongoApi.fetchUsers();
  }
}

/// Low-level helper to push/pull changes against MongoDB.
class MongoApi {
  final String uri;
  final List<String> nodeNames;
  final String collectionPrefix;

  Db? _db;

  MongoApi({
    required this.uri,
    required this.nodeNames,
    this.collectionPrefix = 'offline_',
  });

  Future<Db> _getDb() async {
    final current = _db;
    if (current != null && current.isConnected) return current;

    final db = await Db.create(uri);
    await db.open();
    _db = db;
    return db;
  }

  Future<DbCollection> _collection(String nodeName) async {
    final db = await _getDb();
    final collection = db.collection('$collectionPrefix$nodeName');

    try {
      await collection.createIndex(keys: {'createdAt': 1});
    } catch (_) {
      // Ignora erros de índice existente
    }

    return collection;
  }

  Future<void> push(Map<String, dynamic> payload) async {
    final operationsByNode = payload['changes'];
    if (operationsByNode is! Map<String, dynamic>) return;

    final now = DateTime.now();
    for (final entry in operationsByNode.entries) {
      final nodeName = entry.key;
      final operations = entry.value;
      if (operations is! Map<String, dynamic>) continue;
      final inserts = <Map<String, dynamic>>[];

      final insertItems = operations['insert'];
      if (insertItems is List) {
        for (final item in insertItems) {
          if (item is Map<String, dynamic>) {
            inserts.add({
              'operation': 'insert',
              'data': item,
              'createdAt': now,
            });
          }
        }
      }

      final updateItems = operations['update'];
      if (updateItems is List) {
        for (final item in updateItems) {
          if (item is Map<String, dynamic>) {
            inserts.add({
              'operation': 'update',
              'data': item,
              'createdAt': now,
            });
          }
        }
      }

      final deleteItems = operations['delete'];
      if (deleteItems is List) {
        for (final id in deleteItems) {
          if (id != null) {
            inserts.add({'operation': 'delete', 'id': id, 'createdAt': now});
          }
        }
      }

      if (inserts.isNotEmpty) {
        final collection = await _collection(nodeName);
        await collection.insertMany(inserts);
      }
    }
  }

  Future<Map<String, dynamic>> pull(DateTime? lastSyncAt) async {
    final timestamp = DateTime.now();
    final cutoff =
        lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final changes = <String, Map<String, List<dynamic>>>{};

    for (final nodeName in nodeNames) {
      final collection = await _collection(nodeName);
      final cursor = collection.find(
        where.gt('createdAt', cutoff).sortBy('createdAt'),
      );

      final inserts = <dynamic>[];
      final updates = <dynamic>[];
      final deletes = <dynamic>[];

      await cursor.forEach((doc) {
        final op = doc['operation'];
        if (op == 'delete') {
          if (doc['id'] != null) deletes.add(doc['id']);
        } else if (op == 'insert') {
          if (doc['data'] != null) inserts.add(doc['data']);
        } else if (op == 'update') {
          if (doc['data'] != null) updates.add(doc['data']);
        }
      });

      changes[nodeName] = {
        'insert': inserts,
        'update': updates,
        'delete': deletes,
      };
    }

    return {'timestamp': timestamp.toIso8601String(), 'changes': changes};
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final collection = await _collection('user');
    final cursor = collection.find(where.sortBy('createdAt'));

    final users = <String, Map<String, dynamic>>{};

    await cursor.forEach((doc) {
      final op = doc['operation'];
      if (op == 'delete') {
        final id = doc['id'];
        if (id is String) users.remove(id);
        return;
      }

      final data = doc['data'];
      if (data is! Map<String, dynamic>) return;
      final username = data['username'];
      if (username is! String) return;
      users[username] = data;
    });

    return users.values.toList();
  }
}
