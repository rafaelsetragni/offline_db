part of '../offline_db.dart';

/// Representa uma query com filtros e ordenação
class OfflineQuery<T extends Object> {
  final String nodeName;
  final List<QueryFilter> filters;
  final List<QuerySort> sorts;
  final int? limit;
  final int? offset;
  final OfflineLocalDBDelegate _delegate;
  final T Function(Map<String, dynamic>) _fromJson;
  final OfflineNode<T> _node;

  OfflineQuery({
    required this.nodeName,
    required OfflineLocalDBDelegate delegate,
    required T Function(Map<String, dynamic>) fromJson,
    required OfflineNode<T> node,
    this.filters = const [],
    this.sorts = const [],
    this.limit,
    this.offset,
  }) : _delegate = delegate,
       _fromJson = fromJson,
       _node = node;

  OfflineQuery<T> copyWith({
    List<QueryFilter>? filters,
    List<QuerySort>? sorts,
    int? limit,
    int? offset,
  }) {
    return OfflineQuery<T>(
      nodeName: nodeName,
      delegate: _delegate,
      fromJson: _fromJson,
      node: _node,
      filters: filters ?? this.filters,
      sorts: sorts ?? this.sorts,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  /// Adiciona um filtro
  OfflineQuery<T> where(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    List<dynamic>? whereIn,
    List<dynamic>? whereNotIn,
    bool? isNull,
  }) {
    final filter = QueryFilter(
      field: field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );

    return copyWith(filters: [...filters, filter]);
  }

  /// Adiciona ordenação
  OfflineQuery<T> orderBy(String field, {bool descending = false}) {
    final sort = QuerySort(field: field, descending: descending);
    return copyWith(sorts: [...sorts, sort]);
  }

  /// Limita quantidade de resultados
  OfflineQuery<T> limitTo(int count) {
    return copyWith(limit: count);
  }

  /// Pula N resultados
  OfflineQuery<T> startAfter(int count) {
    return copyWith(offset: count);
  }

  /// Executa a query e retorna os resultados
  Future<List<OfflineObject<T>>> getAll() async {
    final results = await _delegate.query(this);
    return _mapResults(results);
  }

  /// Retorna stream reativa com os resultados
  Stream<List<OfflineObject<T>>> watch() {
    return _delegate.watchQuery(this).map(_mapResults);
  }

  List<OfflineObject<T>> _mapResults(List<Map<String, dynamic>> results) {
    return results
        .map((json) {
          final item = _fromJson(json);

          // Extrai metadata de sincronização
          final syncStatus = json['_sync_status'] != null
              ? SyncStatus.values[json['_sync_status'] as int]
              : SyncStatus.ok;

          final syncOperation = json['_sync_operation'] != null
              ? SyncOperation.values[json['_sync_operation'] as int]
              : SyncOperation.insert;

          return OfflineObject<T>(
            item: item,
            status: syncStatus,
            operation: syncOperation,
            node: _node,
          );
        })
        .where((obj) => !obj.isDeleted)
        .toList();
  }
}

/// Filtro individual
class QueryFilter {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;
  final bool? isNull;

  const QueryFilter({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  });

  /// Aplica filtro em um item (fallback para DBs que não suportam queries)
  bool matches(Map<String, dynamic> item) {
    final value = item[field];

    if (isNull != null) {
      return (value == null) == isNull;
    }

    if (isEqualTo != null && value != isEqualTo) return false;
    if (isNotEqualTo != null && value == isNotEqualTo) return false;

    if (isLessThan != null) {
      if (value is! Comparable || !(value.compareTo(isLessThan) < 0)) {
        return false;
      }
    }

    if (isLessThanOrEqualTo != null) {
      if (value is! Comparable ||
          !(value.compareTo(isLessThanOrEqualTo) <= 0)) {
        return false;
      }
    }

    if (isGreaterThan != null) {
      if (value is! Comparable || !(value.compareTo(isGreaterThan) > 0)) {
        return false;
      }
    }

    if (isGreaterThanOrEqualTo != null) {
      if (value is! Comparable ||
          !(value.compareTo(isGreaterThanOrEqualTo) >= 0)) {
        return false;
      }
    }

    if (whereIn != null && !whereIn!.contains(value)) return false;
    if (whereNotIn != null && whereNotIn!.contains(value)) return false;

    return true;
  }
}

/// Ordenação
class QuerySort {
  final String field;
  final bool descending;

  const QuerySort({required this.field, this.descending = false});
}
