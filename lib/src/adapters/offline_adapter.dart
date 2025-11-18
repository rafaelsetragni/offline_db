part of '../../offline_db.dart';

/// Abstract adapter for serializing and deserializing objects.
///
/// Defines how objects are converted to/from JSON and how their IDs are managed.
/// Extend this class to create custom adapters for your models.
///
/// Example:
/// ```dart
/// class ChatAdapter extends OfflineAdapter<Chat> {
///   @override
///   String getId(Chat item) => item.id;
///
///   @override
///   Map<String, dynamic> toJson(Chat item) => item.toJson();
///
///   @override
///   Chat fromJson(Map<String, dynamic> json) => Chat.fromJson(json);
/// }
/// ```
abstract class OfflineAdapter<T extends Object> {
  final String idFieldName;

  OfflineAdapter({this.idFieldName = 'id'});

  /// Gets the unique identifier from an item.
  String getId(T item);

  /// Sets a new ID on an item (optional, returns item unchanged by default).
  ///
  /// Override this if your model supports setting IDs (e.g., with copyWith).
  T setId(T item, String id) {
    return item;
  }

  /// Converts an item to JSON format.
  Map<String, dynamic> toJson(T item);

  /// Creates an item from JSON format.
  T fromJson(Map<String, dynamic> json);

  OfflineObject<T>? resolveConflict(
    OfflineObject<T> local,
    OfflineObject<T> remote,
  );
}

/// A simple adapter implementation using function callbacks.
///
/// Use this when you prefer a functional approach over class inheritance.
///
/// Example:
/// ```dart
/// final userAdapter = SimpleAdapter<User>(
///   getId: (user) => user.id,
///   toJson: (user) => user.toJson(),
///   fromJson: (json) => User.fromJson(json),
/// );
/// ```
class SimpleAdapter<T extends Object> extends OfflineAdapter<T> {
  final String Function(T item) _getId;
  final T Function(T item, String id)? _setId;
  final Map<String, dynamic> Function(T item) _toJson;
  final T Function(Map<String, dynamic> json) _fromJson;

  SimpleAdapter({
    required String Function(T item) getId,
    T Function(T item, String id)? setId,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
  }) : _getId = getId,
       _setId = setId,
       _toJson = toJson,
       _fromJson = fromJson;

  @override
  String getId(T item) => _getId(item);

  @override
  T setId(T item, String id) => _setId?.call(item, id) ?? item;

  @override
  Map<String, dynamic> toJson(T item) => _toJson(item);

  @override
  T fromJson(Map<String, dynamic> json) => _fromJson(json);

  @override
  OfflineObject<T>? resolveConflict(
    OfflineObject<T> local,
    OfflineObject<T> remote,
  ) {
    return remote;
  }
}
