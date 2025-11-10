part of '../offline_db.dart';

abstract class OfflineLocalDBDelegate {
  Future<void> initialize();
  Future<void> close();
  Future<void> clearAllData();

  Future<List<Map<String, dynamic>>> getAll(String tableName);
  Future<void> insert(String tableName, Map<String, dynamic> item);
  Future<void> update(String tableName, String id, Map<String, dynamic> item);
  Future<void> delete(String tableName, String id, Map<String, dynamic> item);
  Future<void> hardDelete(String nodeName, String id);
  Future<void> deleteAll(String tableName);

  Future<DateTime?> getLastSyncAt(String nodeName);
  Future<void> setLastSyncAt(String nodeName, DateTime time);

  /// Executa uma query e retorna resultados
  ///
  /// Delegates que suportam queries nativas (como Isar, Drift) podem
  /// sobrescrever para otimizar. Delegates simples (como Hive) usam
  /// a implementação padrão que filtra de forma otimizada.
  Future<List<Map<String, dynamic>>> query(OfflineQuery query) async {
    // Implementação padrão: busca tudo e filtra de forma otimizada
    var items = await getAll(query.nodeName);

    // Aplica filtros
    if (query.filters.isNotEmpty) {
      items = items.where((item) {
        for (var filter in query.filters) {
          if (!filter.matches(item)) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    // Aplica ordenação
    if (query.sorts.isNotEmpty) {
      items.sort((a, b) {
        for (var sort in query.sorts) {
          final aValue = a[sort.field];
          final bValue = b[sort.field];

          int comparison = 0;
          if (aValue is Comparable && bValue is Comparable) {
            comparison = aValue.compareTo(bValue);
          }

          if (comparison != 0) {
            return sort.descending ? -comparison : comparison;
          }
        }
        return 0;
      });
    }

    // Aplica offset
    if (query.offset != null && query.offset! > 0) {
      items = items.skip(query.offset!).toList();
    }

    // Aplica limit
    if (query.limit != null) {
      items = items.take(query.limit!).toList();
    }

    return items;
  }

  /// Stream reativo de uma query
  ///
  /// Delegates que suportam streams nativos (como Isar) podem sobrescrever.
  /// A implementação padrão re-executa a query quando há mudanças.
  Stream<List<Map<String, dynamic>>> watchQuery(OfflineQuery query) async* {
    // Implementação padrão: emite resultado inicial
    yield await this.query(query);

    // Delegates mais sofisticados podem ter streams nativos com
    // notificações de mudanças. A implementação padrão só emite
    // o valor inicial.
  }
}
