part of '../offline_db.dart';

/// Implementação do OfflineLocalDBDelegate usando Hive CE
///
/// Características:
/// - Armazena dados como JSON em boxes do Hive
/// - Cada tabela é um box separado
/// - Metadata (lastSyncAt) é armazenada em box dedicado
/// - Operações são rápidas e totalmente offline
class HiveOfflineDelegate implements OfflineLocalDBDelegate {
  /// Boxes para cada tabela (lazy-loaded)
  final Map<String, Box<Map<dynamic, dynamic>>> _boxes = {};

  /// Box para metadata de sincronização
  late Box<int> _metadataBox;

  /// Flag para controlar inicialização
  bool _initialized = false;

  /// Path customizado (útil para testes)
  final String? customPath;

  /// Construtor
  HiveOfflineDelegate({this.customPath});

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializa Hive
    if (customPath != null) {
      Hive.init(customPath);
    } else {
      await Hive.initFlutter();
    }

    // Abre box de metadata
    _metadataBox = await Hive.openBox<int>('_offline_metadata');

    _initialized = true;
  }

  @override
  Future<void> close() async {
    if (!_initialized) return;

    // Fecha todos os boxes abertos
    for (var box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();

    // Fecha box de metadata
    await _metadataBox.close();

    _initialized = false;
  }

  /// Obtém ou cria box para a tabela
  Future<Box<Map<dynamic, dynamic>>> _getBox(String tableName) async {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    if (_boxes.containsKey(tableName)) {
      return _boxes[tableName]!;
    }

    // Abre box e armazena no cache
    final box = await Hive.openBox<Map>(tableName);
    _boxes[tableName] = box;
    return box;
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(String tableName) async {
    final box = await _getBox(tableName);

    // Converte valores do Hive para List<Map<String, dynamic>>
    return box.values.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  @override
  Future<void> insert(String tableName, Map<String, dynamic> item) async {
    final box = await _getBox(tableName);

    // Usa o ID como chave
    final id = item['id'] as String;
    await box.put(id, item);
  }

  @override
  Future<void> update(
    String tableName,
    String id,
    Map<String, dynamic> item,
  ) async {
    final box = await _getBox(tableName);

    // Put sobrescreve se já existir
    await box.put(id, item);
  }

  @override
  Future<void> delete(
    String tableName,
    String id,
    Map<String, dynamic> item,
  ) async {
    // Soft delete: atualiza com metadata de delete
    await update(tableName, id, item);
  }

  @override
  Future<void> hardDelete(String tableName, String id) async {
    final box = await _getBox(tableName);
    await box.delete(id);
  }

  @override
  Future<void> deleteAll(String tableName) async {
    final box = await _getBox(tableName);
    await box.clear();
  }

  @override
  Future<DateTime?> getLastSyncAt(String nodeName) async {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    final key = '${nodeName}_lastSyncAt';
    final ms = _metadataBox.get(key);

    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> setLastSyncAt(String nodeName, DateTime time) async {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    final key = '${nodeName}_lastSyncAt';
    await _metadataBox.put(key, time.millisecondsSinceEpoch);
  }

  @override
  Future<void> clearAllData() async {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    // Lista de todos os boxes para deletar
    final boxesToDelete = <String>[..._boxes.keys];

    // Limpa conteúdo de todos os boxes abertos
    for (var box in _boxes.values) {
      await box.clear();
    }

    // Limpa metadata
    await _metadataBox.clear();

    // Fecha todos os boxes abertos
    for (var box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();

    // Fecha metadata
    await _metadataBox.close();

    // Deleta cada box do disco individualmente (se houver)
    for (var boxName in boxesToDelete) {
      try {
        await Hive.deleteBoxFromDisk(boxName, path: customPath);
      } catch (e) {
        // Ignora erros se box não existir
      }
    }

    // Deleta metadata box do disco
    try {
      await Hive.deleteBoxFromDisk('_offline_metadata', path: customPath);
    } catch (e) {
      // Ignora erros se box não existir
    }

    // Re-inicializa
    _initialized = false;
    await initialize();
  }

  // ============================================
  // Query Support (Otimizado para Hive)
  // ============================================

  @override
  Future<List<Map<String, dynamic>>> query(OfflineQuery query) async {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    final box = await _getBox(query.nodeName);

    // Otimização: não carrega tudo de uma vez, itera lazy
    final results = <Map<String, dynamic>>[];

    // Coleta todos os itens que passam pelos filtros
    for (var key in box.keys) {
      final rawItem = box.get(key);
      if (rawItem == null) continue;

      // Converte Map<dynamic, dynamic> para Map<String, dynamic>
      final item = Map<String, dynamic>.from(rawItem);

      // Aplica filtros
      bool matches = true;
      for (var filter in query.filters) {
        if (!filter.matches(item)) {
          matches = false;
          break;
        }
      }

      if (matches) {
        results.add(item);
      }
    }

    // Aplica ordenação
    if (query.sorts.isNotEmpty) {
      results.sort((a, b) {
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

    // Aplica offset e limit (paginação)
    int start = query.offset ?? 0;
    int? end = query.limit != null ? start + query.limit! : null;

    if (start > 0 || end != null) {
      return results.sublist(
        start,
        end != null && end < results.length ? end : results.length,
      );
    }

    return results;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchQuery(OfflineQuery query) async* {
    if (!_initialized) {
      throw StateError(
        'HiveOfflineDelegate not initialized. Call initialize() first.',
      );
    }

    final box = await _getBox(query.nodeName);

    // Emite resultado inicial
    yield await this.query(query);

    // Escuta mudanças no box e reexecuta a query
    await for (final _ in box.watch()) {
      yield await this.query(query);
    }
  }
}
