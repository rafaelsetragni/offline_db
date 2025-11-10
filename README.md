# Offline DB

Um sistema completo de gerenciamento de dados offline com sincronização bidirecional para aplicações Flutter. Este pacote permite que sua aplicação funcione completamente offline, armazenando dados localmente e sincronizando com o servidor quando a conexão estiver disponível.

## Características

- 🔄 **Sincronização Bidirecional**: Push de mudanças locais e pull de atualizações remotas
- 📦 **Armazenamento Local**: Suporte a múltiplos backends (Hive, Isar, Drift)
- 🔍 **Sistema de Queries**: API fluente para consultas com filtros, ordenação e paginação
- 📊 **Controle de Estado**: Gerenciamento automático de status de sincronização
- 🎯 **Type-Safe**: Totalmente tipado com suporte a generics
- 🔌 **Plugável**: Arquitetura baseada em delegates para fácil extensão
- 📱 **Otimizado para Mobile**: Performance otimizada para dispositivos móveis

## Instalação

```yaml
dependencies:
  hive_ce_flutter: ^2.0.0
```

## Conceitos Principais

### OfflineDB

A classe central que gerencia todos os nodes e coordena a sincronização.

```dart
final offlineDB = OfflineDB(
  nodes: [userNode, postNode],
  localDB: HiveOfflineDelegate(),
);

await offlineDB.initialize();
```

### OfflineNode

Representa uma coleção de dados (similar a uma tabela). Cada node gerencia um tipo específico de objeto.

```dart
final userNode = OfflineNode.standalone(
  'users',
  adapter: SimpleAdapter<User>(
    getId: (user) => user.id,
    setId: (user, id) => user.copyWith(id: id),
    toJson: (user) => user.toJson(),
    fromJson: (json) => User.fromJson(json),
  ),
);
```

### OfflineAdapter

Define como seus objetos são serializados e identificados. Use `SimpleAdapter` para casos simples ou crie um adapter customizado para casos complexos.

### OfflineLocalDBDelegate

Interface para o sistema de armazenamento local. Incluso: `HiveOfflineDelegate` para Hive CE.

## Uso Básico

### 1. Configuração Inicial

```dart
// Crie os adapters para seus modelos
final userAdapter = SimpleAdapter<User>(
  getId: (user) => user.id,
  setId: (user, id) => user.copyWith(id: id),
  toJson: (user) => user.toJson(),
  fromJson: (json) => User.fromJson(json),
);

final postAdapter = SimpleAdapter<Post>(
  getId: (post) => post.id,
  setId: (post, id) => post.copyWith(id: id),
  toJson: (post) => post.toJson(),
  fromJson: (json) => Post.fromJson(json),
);

// Crie os nodes
final userNode = OfflineNode.standalone('users', adapter: userAdapter);
final postNode = OfflineNode.standalone('posts', adapter: postAdapter);

// Inicialize o OfflineDB
final offlineDB = OfflineDB(
  nodes: [userNode, postNode],
  localDB: HiveOfflineDelegate(),
);

await offlineDB.initialize();
```

### 2. Operações CRUD

#### Inserir

```dart
final user = User(id: '1', name: 'João', email: 'joao@example.com');
await userNode.insert(user);
```

#### Atualizar

```dart
final updatedUser = user.copyWith(name: 'João Silva');
await userNode.update(updatedUser);
```

#### Upsert (Insert ou Update)

```dart
await userNode.upsert(user);
```

#### Deletar (Soft Delete)

```dart
await userNode.delete(user);
```

### 3. Queries

O sistema de queries oferece uma API fluente e poderosa:

```dart
// Buscar todos os usuários
final allUsers = await userNode.query().getAll();

// Filtrar por campo
final activeUsers = await userNode
  .query()
  .where('status', isEqualTo: 'active')
  .getAll();

// Múltiplos filtros
final results = await userNode
  .query()
  .where('age', isGreaterThan: 18)
  .where('city', isEqualTo: 'São Paulo')
  .getAll();

// Ordenação
final sortedUsers = await userNode
  .query()
  .orderBy('name')
  .getAll();

// Paginação
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

// Queries reativas (Stream)
userNode
  .query()
  .where('status', isEqualTo: 'active')
  .watch()
  .listen((users) {
    print('Usuários ativos: ${users.length}');
  });
```

#### Operadores de Filtro Disponíveis

- `isEqualTo`: Igual a
- `isNotEqualTo`: Diferente de
- `isLessThan`: Menor que
- `isLessThanOrEqualTo`: Menor ou igual a
- `isGreaterThan`: Maior que
- `isGreaterThanOrEqualTo`: Maior ou igual a
- `whereIn`: Valor está na lista
- `whereNotIn`: Valor não está na lista
- `isNull`: Campo é nulo (true) ou não é nulo (false)

### 4. Sincronização

A sincronização é bidirecional e automática:

```dart
await offlineDB.sync(
  onPush: (changes) async {
    // Envie as mudanças locais para o servidor
    await api.push(changes);
  },
  onPull: (lastSyncAt) async {
    // Busque mudanças do servidor desde a última sincronização
    final response = await api.pull(lastSyncAt);
    return response;
  },
);
```

## Formato de Sincronização

### Push (Local → Servidor)

O sistema envia mudanças locais agrupadas por operação:

```json
{
  "users": {
    "insert": [
      {"id": "1", "name": "João", "email": "joao@example.com"}
    ],
    "update": [
      {"id": "2", "name": "Maria Silva", "email": "maria@example.com"}
    ],
    "delete": ["3", "4"]
  },
  "posts": {
    "insert": [],
    "update": [
      {"id": "10", "title": "Novo título", "content": "..."}
    ],
    "delete": []
  }
}
```

### Pull (Servidor → Local)

O servidor deve retornar mudanças desde o último sync:

```json
{
  "timestamp": "2025-11-10T15:30:00.000Z",
  "changes": {
    "users": {
      "insert": [
        {"id": "5", "name": "Pedro", "email": "pedro@example.com"}
      ],
      "update": [
        {"id": "2", "name": "Maria Santos", "email": "maria@example.com"}
      ],
      "delete": [
        {"id": "3"}
      ]
    },
    "posts": {
      "insert": [],
      "update": [],
      "delete": []
    }
  }
}
```

**Importante**: O campo `timestamp` é obrigatório e deve ser o timestamp do servidor no momento da resposta.

## Gerenciamento de Estado de Sincronização

Cada objeto possui metadata de sincronização:

```dart
final users = await userNode.query().getAll();

for (var userObj in users) {
  print('User: ${userObj.item.name}');
  print('Precisa sincronizar: ${userObj.needSync}');
  print('Status: ${userObj.status}'); // pending, ok, failed
  print('Operação: ${userObj.operation}'); // insert, update, delete
  print('Está deletado: ${userObj.isDeleted}');
}
```

### Estados de Sincronização

- `SyncStatus.pending`: Mudança local ainda não sincronizada
- `SyncStatus.ok`: Sincronizado com sucesso
- `SyncStatus.failed`: Falha na sincronização (será retentado)

### Operações

- `SyncOperation.insert`: Novo objeto criado localmente
- `SyncOperation.update`: Objeto modificado localmente
- `SyncOperation.delete`: Objeto deletado localmente (soft delete)

## Delegates de Armazenamento

### HiveOfflineDelegate (Incluso)

Implementação baseada em Hive CE, ideal para a maioria dos casos:

```dart
final delegate = HiveOfflineDelegate();
```

Para testes, você pode especificar um path customizado:

```dart
final delegate = HiveOfflineDelegate(customPath: './test_hive');
```

### Criando um Delegate Customizado

Implemente `OfflineLocalDBDelegate` para usar outros sistemas:

```dart
class IsarOfflineDelegate implements OfflineLocalDBDelegate {
  @override
  Future<void> initialize() async {
    // Inicializa Isar
  }
  
  @override
  Future<List<Map<String, dynamic>>> getAll(String tableName) async {
    // Implementação com Isar
  }
  
  // ... outros métodos
}
```

## Tratamento de Conflitos

O sistema usa uma estratégia "last write wins" (última escrita vence):

1. Mudanças locais pendentes sempre têm prioridade
2. Se não há mudanças locais, aceita a versão do servidor
3. Deletes remotos são aplicados apenas se não há mudanças locais pendentes

## Utilitários

### Limpar Todos os Dados

```dart
await offlineDB.clearAllData();
```

### Acessar Node por Nome

```dart
final userNode = offlineDB.getNodeByName('users');
```

### Acesso Direto ao Delegate

```dart
final lastSync = await offlineDB.localDB.getLastSyncAt('users');
```

### Dispose

```dart
await offlineDB.dispose();
```

## Exemplos Práticos

### Integração com GetX/Riverpod

```dart
class UserRepository {
  final OfflineNode<User> _node;
  
  UserRepository(this._node);
  
  Stream<List<User>> watchActiveUsers() {
    return _node
      .query()
      .where('status', isEqualTo: 'active')
      .orderBy('name')
      .watch()
      .map((objects) => objects.map((obj) => obj.item).toList());
  }
  
  Future<void> createUser(User user) async {
    await _node.insert(user);
  }
  
  Future<void> updateUser(User user) async {
    await _node.update(user);
  }
  
  Future<void> deleteUser(User user) async {
    await _node.delete(user);
  }
}
```

### Sincronização Periódica

```dart
Timer.periodic(Duration(minutes: 5), (_) async {
  try {
    await offlineDB.sync(
      onPush: (changes) => api.push(changes),
      onPull: (since) => api.pull(since),
    );
  } catch (e) {
    print('Erro na sincronização: $e');
  }
});
```

### Sincronização ao Voltar Online

```dart
Connectivity().onConnectivityChanged.listen((result) async {
  if (result != ConnectivityResult.none) {
    await offlineDB.sync(
      onPush: (changes) => api.push(changes),
      onPull: (since) => api.pull(since),
    );
  }
});
```

## Testes

O sistema foi projetado para ser facilmente testável:

```dart
void main() {
  late OfflineDB db;
  late OfflineNode<User> userNode;
  
  setUp(() async {
    final adapter = SimpleAdapter<User>(/* ... */);
    userNode = OfflineNode.standalone('users', adapter: adapter);
    
    db = OfflineDB(
      nodes: [userNode],
      localDB: HiveOfflineDelegate(customPath: './test_data'),
    );
    
    await db.initialize();
  });
  
  tearDown(() async {
    await db.clearAllData();
    await db.dispose();
  });
  
  test('insert user', () async {
    final user = User(id: '1', name: 'Test');
    await userNode.insert(user);
    
    final results = await userNode.query().getAll();
    expect(results.length, 1);
    expect(results.first.item.name, 'Test');
  });
}
```

## Performance

### Otimizações do Hive

- Queries são executadas com iteração lazy
- Filtros são aplicados durante a iteração (sem carregar tudo na memória)
- Paginação é aplicada após ordenação para economizar processamento
- Streams reativos usando `box.watch()`

### Dicas de Performance

1. Use `limitTo()` para paginar resultados grandes
2. Crie índices específicos se usar Isar ou Drift
3. Evite queries muito complexas em grandes datasets
4. Use `watch()` para updates reativos em vez de polling

## Troubleshooting

### "OfflineDB not initialized"

```dart
// Sempre chame initialize() antes de usar
await offlineDB.initialize();
```

### "Duplicate node names"

```dart
// Cada node deve ter um nome único
final node1 = OfflineNode.standalone('users', ...);
final node2 = OfflineNode.standalone('users', ...); // ❌ Erro!
```

### Sincronização não funciona

1. Verifique se os callbacks `onPush` e `onPull` estão corretos
2. Confirme que o servidor retorna o formato esperado no pull
3. Verifique se o campo `timestamp` está presente na resposta do pull

### Dados não aparecem nas queries

```dart
// Lembre-se que queries excluem itens deletados por padrão
final all = await node.query().getAll(); // Não mostra deletados

// Para incluir deletados, use o método interno (apenas para debug)
```

