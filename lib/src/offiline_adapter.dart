part of '../offline_db.dart';

abstract class OfflineAdapter<T extends Object> {
  String getId(T item);
  T setId(T item, String id) {
    return item;
  }

  Map<String, dynamic> toJson(T item);
  T fromJson(Map<String, dynamic> json);
}

class SimpleAdapter<T extends Object> extends OfflineAdapter<T> {
  final String Function(T item) _getId;
  final T Function(T item, String id) _setId;
  final Map<String, dynamic> Function(T item) _toJson;
  final T Function(Map<String, dynamic> json) _fromJson;

  SimpleAdapter({
    required String Function(T item) getId,
    required T Function(T item, String id) setId,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
  }) : _getId = getId,
       _setId = setId,
       _toJson = toJson,
       _fromJson = fromJson;

  @override
  String getId(T item) => _getId(item);

  @override
  T setId(T item, String id) => _setId(item, id);

  @override
  Map<String, dynamic> toJson(T item) => _toJson(item);

  @override
  T fromJson(Map<String, dynamic> json) => _fromJson(json);
}
