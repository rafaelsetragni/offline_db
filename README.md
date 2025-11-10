# Offline DB

A complete offline data management system with bidirectional synchronization for Flutter applications. This package allows your application to work completely offline, storing data locally and synchronizing with the server when connection is available.

## Features

- **Mobile Optimized**: Performance optimized for mobile devices.
- **Bidirectional Synchronization**: Push local changes and pull remote updates.
- **Local Storage**: Support for multiple backends (Hive, Isar, Drift).
- **Query System**: Fluent API for queries with filters, ordering and pagination.
- **State Control**: Automatic sync status management

## Installation

```sh
flutter pub add offline_db
```

## Core Concepts

`OfflineDB` revolves around creating `NODES` to perform local CRUD operations and `SYNCHRONIZATION` which can be performed whenever the developer decides, for example using WorkManager for background calls or just a `Timer` to run from time to time.

### **NODE**

A `NODE` represents a data collection in your application, similar to a database table. Each NODE manages a specific type of object (like users, posts, messages, etc.) and controls its CRUD operations independently. For example, you can have a NODE for "chat" and another for "message" separately. Data representation will use the `OfflineNode<T>` type where `<T>` represents a model or entity.<br></br>
We'll have two ways to initialize a `NODE`, which we'll discuss ahead.

### **SYNCHRONIZATION**

`OfflineDB` will orchestrate what needs to be sent and what needs to be received using JSON. As a rule, 2 endpoints will be needed on the server: one for pull and another for push. <br></br>
When requesting synchronization, `OfflineDB` will create a Map/JSON with the data that will need to be synchronized with the server, informing the respective operations (insert, update, delete). This will be called `PUSH`. <br></br>
Similarly, `OfflineDB` will request information from the server where it expects a specific Map/JSON to synchronize locally. This will be called `PULL`.

The Map/JSON schema that will be sent in the `PUSH` is:
```js
  NODE_NAME: {
    insert: []
    update: []
    delete: []
  }
```

Basic example where we would have two `NODE`s (chat and message): 
```json
{
  "chat": {
    "insert": [
      {"id": "1", "name": "Development Team"}
    ],
    "update": [
      {"id": "2", "name": "Technical Support"}
    ],
    "delete": ["3"]
  },
  "message": {
    "insert": [
      {"id": "10", "chatId": "1", "text": "Hello everyone!", "senderId": "user1"},
      {"id": "11", "chatId": "1", "text": "How are you?", "senderId": "user1"}
    ],
    "update": [
      {"id": "9", "chatId": "2", "text": "Edited message"}
    ],
    "delete": ["8"]
  }
}
```
The `chat` node has a new conversation being created, an activity update, and a deletion. <br></br>
The `message` node contains two new messages being inserted into chat "1", an edited message in chat "2", and a deleted message. <br></br>
This format groups all operations by type, making batch processing on the server easier. It's important to note that `delete` operations will only have the ID.

The Map/JSON schema expected to be received in the `PULL` is:
```js
  TIMESTAMP: DateTime()
  CHANGES: {
    NODE_NAME: {
      insert: []
      update: []
      delete: []
    }
  }

```

Basic example of the returned JSON still considering the `chat` and `message` NODES:

```json
{
  "timestamp": "2025-11-10T15:30:00.000Z",
  "changes": {
    "chat": {
      "insert": [
        {"id": "5", "name": "Daily Meeting"}
      ],
      "update": [
        {"id": "1", "name": "Development Team - Updated"}
      ],
      "delete": ["4"]
    },
    "message": {
      "insert": [
        {"id": "20", "chatId": "5", "text": "New meeting created", "senderId": "user2"}
      ],
      "update": [
        {"id": "10", "chatId": "1", "text": "Hello everyone! (edited)"}
      ],
      "delete": ["12"
      ]
    }
  }
}
```

This time we have a `timestamp` that will be used in the next pull. Also note that the `changes` object will be very similar to what is sent in the `PUSH`. Including the `delete` part still needs to send only the ID.


### **SUMMARY**

- We'll create Models/Entities
- We'll create a `NODE` and associate a Model/Entity to it
- We'll use CRUD methods that will save data locally
- We'll synchronize by configuring the `PUSH` and `PULL` methods

The `OfflineDB` API will make this entire complex process easier for us.

## OfflineDB

The central class that manages all nodes and coordinates synchronization.

```dart
final offlineDB = OfflineDB(
  nodes: [chatNode, messageNode],
  localDB: HiveOfflineDelegate(),
);

await offlineDB.initialize();
```

Note that we're using a delegate called `HiveOfflineDelegate`, which is the abstraction of a Local Database using `Hive`. This means we can use other engines to save data locally. We'll discuss ahead how to create another `Delegate` using other databases.

> Also available is `MemoryOfflineDelegate` which persists data in memory. This can be useful in unit tests.

The `OfflineDB` instance also calls the synchronization method.<br></br>
We'll need to implement two methods: one representing `PUSH` and another `PULL`.<br></br>
Synchronization is bidirectional:

```dart
await offlineDB.sync(
  onPush: (changes) async {
    // Send local changes to the server
    await api.push(changes);
  },
  onPull: (lastSyncAt) async {
    // Fetch server changes since last synchronization
    final response = await api.pull(lastSyncAt);
    return response;
  },
);
```

> We must respect the JSON patterns that will be sent and received in synchronization. 

**Important**: You are responsible for calling the `sync()` method when you want to synchronize data. Synchronization does not occur automatically. You can implement it in various ways:
- **Periodic Timer**: Synchronize every X minutes
- **WorkManager**: Run in background even with the app closed
- **Connectivity Detection**: Synchronize when connection returns
- **Manual**: Button for user to trigger when desired

### **OfflineNode**

Represents a data collection (similar to a table). Each node manages a specific type of object.<br></br>
There are two ways to create a `NODE`: inheriting in a Service or Repository class, or creating a `standalone` instance of it.

Before creating a `NODE` we need to create a model class:

```dart
class Chat {
  final String id;
  final String title;

  Chat(this.id, this.title);
}
```
> It's a good practice to use `String` as ID, because a `UUID` is better than `int` in Offline-First.

Since `Dart` doesn't have automatic serialization, we chose to use the `Adapter` pattern to convert objects to Map/JSON. Use `OfflineAdapter<T>` to help with this conversion, as well as help the `NODE` know what the object's `ID` is.

```dart
class ChatAdapter extends OfflineAdapter<Chat> {
  @override
  String getId(Chat item) => item.id;

  @override
  Map<String, dynamic> toJson(Chat item) {
    return {
      "id": item.id,
      "title": item.title
    };
  }

  @override
  Chat fromJson(Map<String, dynamic> json) {
    return Chat(json['id'], json['title']);
  }
}
```

With the `Model` and its `Adapter` ready we can create the `NODE`.

The `OfflineNode` is an abstract class, so you can use it by inheriting in a repository:

```dart
class ChatService extends OfflineNode<Chat> {
  ChatService() : super('chat', adapter: ChatAdapter());
}
```

That's enough!

The `ChatService` class will gain some methods to help persist local data, as well as read it. In fact, data reading can be reactive, which makes the `NODE` inform when there are changes, making it a reactive database.

> Don't forget to add the node instance to `OfflineDB`.


### **Operations**

The `Node` can perform `upsert` (Insert or Update), `delete` operations and queries using `Queries`.

#### Upsert (Insert or Update)

```dart
final chat = Chat('1', 'Chat 1');
await chatService.upsert(chat);
```

#### Delete

```dart
final id = '1';
await userNode.delete(id);
```

#### Query

**WE'LL TALK ABOUT QUERIES BELOW**

### **Standalone**

If for some reason you don't want to use inheritance, you can instantiate using the `standalone` factory. Additionally, the `SimpleAdapter` class is also available to help with adaptation without inheritance.

```dart
final userNode = OfflineNode.standalone(
  'user',
  adapter: SimpleAdapter<User>(
    getId: (user) => user.id,
    toJson: (user) => user.toJson(),
    fromJson: (json) => User.fromJson(json),
  ),
);
```

This can be used when a more functional paradigm is desired, but using the first form presented in this documentation is recommended.

### **Queries**


The query system offers a fluent and powerful API, similar to an ORM, to assist in data queries.

Here are some basic examples.

```dart
// Fetch all users
final allUsers = await userNode.query().getAll();

// Filter by field
final activeUsers = await userNode
  .query()
  .where('status', isEqualTo: 'active')
  .getAll();

// Multiple filters
final results = await userNode
  .query()
  .where('age', isGreaterThan: 18)
  .where('city', isEqualTo: 'São Paulo')
  .getAll();

// Ordering
final sortedUsers = await userNode
  .query()
  .orderBy('name')
  .getAll();

// Pagination
final page1 = await userNode
  .query()
  .orderBy('createdAt', descending: true)
  .limitTo(10)
  .getAll();

final page2 = await userNode
  .query()
  .orderBy('createdAt', descending: true)
  .startAfter(10)
  .limitTo(10)
  .getAll();
```

#### Available Filter Operators

- `isEqualTo`: Equal to
- `isNotEqualTo`: Not equal to
- `isLessThan`: Less than
- `isLessThanOrEqualTo`: Less than or equal to
- `isGreaterThan`: Greater than
- `isGreaterThanOrEqualTo`: Greater than or equal to
- `whereIn`: Value is in the list
- `whereNotIn`: Value is not in the list
- `isNull`: Field is null (true) or not null (false)

#### Watch Query

We can replace the `getAll` method of `queries` with `watch`. This will return a `Stream` that will inform about every data modification based on the filters.

```dart

// Reactive queries (Stream)
final userStream = userNode
  .query()
  .where('status', isEqualTo: 'active')
  .watch();


  userStream.listen((users) {
    print('Active users: ${users.length}');
  });

```

A good tip is to add the search method directly in the class that inherits the `Node`:

```dart
class ChatService extends OfflineNode<Chat> {
  ChatService() : super('chat', adapter: ChatAdapter());

  Stream<List<Chat>> watchChats() {
    return query()
            .where('status', isEqualTo: 'active')
            .watch()
            .map((list) => list.map((obj) => obj.item).toList());
  }
}
```

> It's obvious but it doesn't hurt to remind: Close the Streams after `Dispose`.


#### OfflineObject

Queries always return an `OfflineObject`. This is done so the developer can see the synchronization metadata along with the original model:

```dart
final users = await userNode.query().getAll();

for (var userObj in users) {
  print('User: ${userObj.item}');
  print('Status: ${userObj.status}'); // pending, ok, failed
  print('Operation: ${userObj.operation}'); // insert, update, delete
  print('Needs sync: ${userObj.needSync}');
  print('Is deleted: ${userObj.isDeleted}');
}
```

#### Synchronization States

- `SyncStatus.pending`: Local change not yet synchronized
- `SyncStatus.ok`: Successfully synchronized
- `SyncStatus.failed`: Synchronization failed (will be retried)

#### Operations

- `SyncOperation.insert`: New object created locally
- `SyncOperation.update`: Object modified locally
- `SyncOperation.delete`: Object deleted locally (soft delete)

This information is enough for the user to know the state of each item separately.

## Storage Delegates

`OfflineDB` maintains a default Delegate called `HiveOfflineDelegate`, but it's possible to create other delegates and use other local databases. Here's a short tutorial on how to do this:

Implement `OfflineLocalDBDelegate` to use other systems:

```dart
class IsarOfflineDelegate implements OfflineLocalDBDelegate {
  @override
  Future<void> initialize() async {
    // Initialize Isar
  }
  
  @override
  Future<List<Map<String, dynamic>>> getAll(String tableName) async {
    // Implementation with Isar
  }
  
  // ... other methods
}
```


## Utilities

### Clear All Data

```dart
await offlineDB.clearAllData();
```

### Access Node by Name

```dart
final userNode = offlineDB.getNodeByName('users');
```

### Direct Access to Delegate

```dart
final lastSync = await offlineDB.localDB.getLastSyncAt('users');
```

### Dispose

```dart
await offlineDB.dispose();
```

## Contributing

Contributions are welcome! If you found a bug, have a suggestion for improvement, or want to add a new feature:

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/MyFeature`)
3. Commit your changes (`git commit -m 'Add MyFeature'`)
4. Push to the branch (`git push origin feature/MyFeature`)
5. Open a Pull Request

Please make sure to:
- Add tests for new features
- Keep code formatted (`dart format .`)
- Follow the project's code conventions

## License

This project is licensed under the MIT license - see the [LICENSE](LICENSE) file for details.

## About

This package was created and is maintained by [Flutterando](https://flutterando.com.br), a Brazilian community dedicated to Flutter development.

