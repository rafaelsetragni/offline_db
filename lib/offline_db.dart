/// A complete offline data management system with bidirectional synchronization
/// for Flutter applications.
///
/// This package provides:
/// - Local CRUD operations with automatic sync tracking
/// - Bidirectional synchronization (push/pull) with servers
/// - Fluent query API with filtering, ordering, and pagination
/// - Reactive queries with Streams
/// - Multiple storage backend support (Hive, Isar, Drift)
/// - Conflict resolution with "last write wins" strategy
///
/// ## Quick Start
///
/// ```dart
/// // Create nodes
/// final userNode = OfflineNode.standalone(
///   'users',
///   adapter: SimpleAdapter<User>(...),
/// );
///
/// // Initialize OfflineDB
/// final offlineDB = OfflineDB(
///   nodes: [userNode],
///   localDB: HiveOfflineDelegate(),
/// );
/// await offlineDB.initialize();
///
/// // Perform CRUD operations
/// await userNode.upsert(user);
/// final users = await userNode.query().getAll();
///
/// // Synchronize
/// await offlineDB.sync(
///   onPush: (changes) => api.push(changes),
///   onPull: (since) => api.pull(since),
/// );
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

part 'src/adapters/offline_adapter.dart';
part 'src/data_sources/hive_offline_delegate.dart';
part 'src/data_sources/offline_delegate.dart';
part 'src/data_sources/offline_query.dart';
part 'src/models/offline_object.dart';
part 'src/nodes/offline_node.dart';
part 'src/offline_db.dart';
part 'src/sync_strategies/data_sync_strategy.dart';
