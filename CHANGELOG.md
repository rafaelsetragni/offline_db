## 0.0.1

- Initial release of Offline DB
- Complete offline data management system with bidirectional synchronization
- Support for local CRUD operations (insert, update, delete)
- Query system with fluent API (filters, ordering, pagination)
- Reactive queries with Streams
- Bidirectional synchronization (Push/Pull)
- Automatic synchronization state control
- HiveOfflineDelegate as default storage delegate
- MemoryOfflineDelegate for testing
- Support for custom adapters for serialization
- Support for custom delegates for other local databases
- Automatic soft delete
- Conflict management with "last write wins" strategy

