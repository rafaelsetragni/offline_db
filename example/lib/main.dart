import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import 'package:offline_db/offline_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final signedUser = await CounterService().initialize();
  final home = signedUser != null ? const MyHomePage() : const SignInPage();
  runApp(MyApp(home: home));
}

class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: home,
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
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
    _usernameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final username = _usernameController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();

    await CounterService().signIn(
      username: username,
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    );

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => MyHomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text('Offline Counter'),
            SizedBox(height: 4),
            Text(
              'Sign In',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AvatarPreview(avatarUrl: _avatarUrl),
              const SizedBox(height: 20),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(
                  labelText: 'Avatar URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Future<int>? _counterFuture;
  final _counterService = CounterService();
  late final String _username;
  late final String _avatarUrl;
  StreamSubscription<List<OfflineObject<CounterLogModel>>>? _logsSubscription;
  StreamSubscription<List<OfflineObject<UserModel>>>? _usersSubscription;
  List<OfflineObject<CounterLogModel>> _recentLogs = [];
  List<OfflineObject<UserModel>> _users = [];
  final Map<String, String?> _userAvatars = {};
  final GlobalKey<AnimatedListState> _logListKey =
      GlobalKey<AnimatedListState>();

  Future<void> _incrementCounter() async {
    await _counterService.addLog(1);
  }

  Future<void> _decrementCounter() async {
    await _counterService.addLog(-1);
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final user = _counterService.authenticatedUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      });
      _username = '';
      _avatarUrl = '';
    } else {
      _username = user.username;
      _avatarUrl = user.avatarUrl ?? '';
      _counterFuture = _loadCounter();
      _listenCounterLogs();
      _listenUsers();
    }
  }

  Future<int> _loadCounter() async {
    final logs = await _counterService.getLogs();
    final total = logs.fold<int>(0, (sum, log) => sum + log.item.increment);
    if (!mounted) return total;
    setState(() {
      _counter = total;
    });
    return total;
  }

  void _listenCounterLogs() {
    _logsSubscription?.cancel();
    _logsSubscription = _counterService.counterLogNode
        .query()
        .orderBy('created_at', descending: true)
        .watch()
        .listen((logs) async {
          final total = logs.fold<int>(
            0,
            (sum, log) => sum + log.item.increment,
          );
          final recent = logs.take(5).toList();
          final missingUsernames = recent
              .map((log) => log.item.username)
              .where((username) => !_userAvatars.containsKey(username))
              .toSet();

          Map<String, String?> avatars = {};
          if (missingUsernames.isNotEmpty) {
            avatars = await _counterService.getAvatarsForUsers(
              missingUsernames,
            );
          }

          if (!mounted) return;
          setState(() {
            _counter = total;
            _counterFuture = Future.value(total);
            if (avatars.isNotEmpty) _userAvatars.addAll(avatars);
          });

          _updateRecentLogs(recent);
        });
  }

  void _listenUsers() {
    _usersSubscription?.cancel();
    _usersSubscription = _counterService.userNode
        .query()
        .orderBy('username')
        .watch()
        .listen((users) {
      if (!mounted) return;
      final updatedAvatars = {
        for (final user in users) user.item.username: user.item.avatarUrl
      };
      setState(() {
        _users = users;
        _userAvatars.addAll(updatedAvatars);
      });
    });
  }

  void _updateRecentLogs(List<OfflineObject<CounterLogModel>> recent) {
    final listKey = _logListKey.currentState;
    if (listKey == null) {
      setState(() {
        _recentLogs = recent;
      });
      return;
    }

    if (_recentLogs.isEmpty && recent.isNotEmpty) {
      for (var i = recent.length - 1; i >= 0; i--) {
        _recentLogs.insert(0, recent[i]);
        listKey.insertItem(0);
      }
      return;
    }

    if (recent.isEmpty) {
      for (var i = _recentLogs.length - 1; i >= 0; i--) {
        final removed = _recentLogs.removeAt(i);
        listKey.removeItem(
          i,
          (context, animation) => _buildAnimatedLogTile(removed, animation),
        );
      }
      return;
    }

    final newHeadId = recent.first.item.id;
    final currentHeadId = _recentLogs.isNotEmpty
        ? _recentLogs.first.item.id
        : null;

    if (newHeadId != currentHeadId) {
      _recentLogs.insert(0, recent.first);
      listKey.insertItem(0);
      if (_recentLogs.length > 5) {
        final removed = _recentLogs.removeLast();
        listKey.removeItem(
          _recentLogs.length,
          (context, animation) => _buildAnimatedLogTile(removed, animation),
        );
      }
    }

    for (var i = 1; i < recent.length && i < _recentLogs.length; i++) {
      _recentLogs[i] = recent[i];
    }

    while (_recentLogs.length > recent.length) {
      final removed = _recentLogs.removeLast();
      listKey.removeItem(
        _recentLogs.length,
        (context, animation) => _buildAnimatedLogTile(removed, animation),
      );
    }

    for (var i = _recentLogs.length; i < recent.length; i++) {
      _recentLogs.insert(i, recent[i]);
      listKey.insertItem(i);
    }
  }

  Widget _buildAnimatedLogTile(
    OfflineObject<CounterLogModel> log,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(opacity: animation, child: _buildLogTile(log)),
    );
  }

  Widget _buildLogTile(OfflineObject<CounterLogModel> log) {
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
            backgroundImage: (_userAvatars[log.item.username] ?? '').isNotEmpty
                ? NetworkImage(_userAvatars[log.item.username]!)
                : null,
            child: (_userAvatars[log.item.username] ?? '').isEmpty
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

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _avatarUrl.isNotEmpty;
    if (_username.isEmpty) {
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
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                AvatarPreview(avatarUrl: _avatarUrl),
                const SizedBox(height: 16),
                Text(
                  'Hello, $_username!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Global counter updated by all users:'),
                FutureBuilder<int>(
                  future: _counterFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      );
                    }
                    return Text(
                      '$_counter',
                      style: Theme.of(context).textTheme.headlineMedium,
                    );
                  },
                ),
              ],
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.15,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Users:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage:
                                    (user.item.avatarUrl ?? '').isNotEmpty
                                        ? NetworkImage(user.item.avatarUrl!)
                                        : null,
                                child: (user.item.avatarUrl ?? '').isEmpty
                                    ? const Icon(Icons.person, size: 22)
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(user.item.username),
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
                  child: ShaderMask(
                    shaderCallback: (rect) =>
                        LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(
                          Rect.fromLTWH(0, 0, rect.width, rect.height),
                        ),
                    blendMode: BlendMode.dstIn,
                    child: AnimatedList(
                      key: _logListKey,
                      initialItemCount: _recentLogs.length,
                      itemBuilder: (context, index, animation) {
                        final log = _recentLogs[index];
                        return _buildAnimatedLogTile(log, animation);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            heroTag: 'increment_fab',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _decrementCounter,
            tooltip: 'Decrement',
            heroTag: 'decrement_fab',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class AvatarPreview extends StatelessWidget {
  final String avatarUrl;
  const AvatarPreview({super.key, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: 50,
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar ? null : const Icon(Icons.person, size: 50),
    );
  }
}

class CounterService {
  static const tag = 'CounterService';
  static const _prefsLastUsername = 'offline_counter_last_username';
  static CounterService? _instance;

  factory CounterService({
    UserNode? userNode,
    CounterLogNode? counterLogNode,
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

  final UserNode userNode;
  final CounterLogNode counterLogNode;
  final MongoPeriodicSyncStrategy syncStrategy;

  CounterService._internal({
    UserNode? userNode,
    CounterLogNode? counterLogNode,
    MongoApi? mongoApi,
    MongoPeriodicSyncStrategy? syncStrategy,
  }) : userNode = userNode ?? UserNode(),
       counterLogNode = counterLogNode ?? CounterLogNode(),
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

  Future<void> signIn({
    required String username,
    required String? avatarUrl,
  }) async {
    syncStrategy.stop();
    await _switchUserDatabase(username);
    final existing = await userNode
        .query()
        .where('username', isEqualTo: username)
        .getAll();
    final preservedAvatar = existing.isNotEmpty
        ? existing.first.item.avatarUrl
        : null;
    final user = authenticatedUser = UserModel(
      username: username,
      avatarUrl: avatarUrl ?? preservedAvatar,
    );
    await userNode.upsert(user);
    await _persistLastUsername(username);
    syncStrategy.start();
  }

  Future<void> signOut() async {
    syncStrategy.stop();
    authenticatedUser = null;
    await _switchUserDatabase('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLastUsername);
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

  Future<void> addLog(int increment) async {
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

class UserModel {
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.username,
    required this.avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

class UserAdapter extends OfflineAdapter<UserModel> {
  UserAdapter() : super(idFieldName: 'username');

  @override
  String getId(UserModel item) => item.username;

  @override
  Map<String, dynamic> toJson(UserModel item) {
    return {
      'username': item.username,
      'avatar_url': item.avatarUrl,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  UserModel fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'],
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  OfflineObject<UserModel> resolveConflict(
    OfflineObject<UserModel> local,
    OfflineObject<UserModel> remote,
  ) {
    if (local.item.updatedAt == remote.item.updatedAt) return remote;

    final preferred = local.item.updatedAt.isAfter(remote.item.updatedAt)
        ? local
        : remote;

    final fallback = identical(preferred, local) ? remote : local;
    final avatarUrl = preferred.item.avatarUrl ?? fallback.item.avatarUrl;
    return preferred.copyWith(
      item: UserModel(
        username: preferred.item.username,
        avatarUrl: avatarUrl,
        createdAt: preferred.item.createdAt,
        updatedAt: preferred.item.updatedAt,
      ),
    );
  }
}

class UserNode extends OfflineNode<UserModel> {
  UserNode() : super('user', adapter: UserAdapter());
}

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
}

class CounterLogAdapter extends OfflineAdapter<CounterLogModel> {
  CounterLogAdapter() : super(idFieldName: 'id');

  @override
  String getId(CounterLogModel item) => item.id;

  @override
  Map<String, dynamic> toJson(CounterLogModel item) {
    return {
      'id': item.id,
      'username': item.username,
      'increment': item.increment,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  @override
  CounterLogModel fromJson(Map<String, dynamic> json) {
    return CounterLogModel(
      id: json['id'],
      username: json['username'],
      increment: json['increment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  OfflineObject<CounterLogModel> resolveConflict(
    OfflineObject<CounterLogModel> local,
    OfflineObject<CounterLogModel> remote,
  ) {
    return local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote;
  }
}

class CounterLogNode extends OfflineNode<CounterLogModel> {
  CounterLogNode() : super('counter_log', adapter: CounterLogAdapter());
}

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
}

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
}
