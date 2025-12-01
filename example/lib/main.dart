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

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                ],
              ),
              Column(
                children: [
                  const Text('Users have pushed the button this many times:'),
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
              SizedBox(height: 150),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
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
             period: const Duration(seconds: 5),
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
    return await restoreLastUser();
  }

  Future<void> signIn({
    required String username,
    required String? avatarUrl,
  }) async {
    await _switchUserDatabase(username);
    final user = authenticatedUser = UserModel(
      username: username,
      avatarUrl: avatarUrl,
    );
    await userNode.upsert(user);
    await _persistLastUsername(username);
  }

  Future<void> signOut() async {
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
    return local.item.updatedAt.isAfter(remote.item.updatedAt) ? local : remote;
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

  Future<void> push(Map<String, dynamic> changes) async {
    final now = DateTime.now();
    for (final nodeName in changes.keys) {
      final operations = changes[nodeName] as Map<String, dynamic>;
      final inserts = <Map<String, dynamic>>[];

      for (final item in (operations['insert'] as List? ?? [])) {
        inserts.add({'operation': 'insert', 'data': item, 'createdAt': now});
      }

      for (final item in (operations['update'] as List? ?? [])) {
        inserts.add({'operation': 'update', 'data': item, 'createdAt': now});
      }

      for (final id in (operations['delete'] as List? ?? [])) {
        inserts.add({'operation': 'delete', 'id': id, 'createdAt': now});
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

  MongoPeriodicSyncStrategy({required this.period, required this.mongoApi}) {
    start();
  }

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
