abstract class ChatApi {
  Future<void> push(Map<String, dynamic> changes);

  Future<Map<String, dynamic>> pull(DateTime? lastSyncAt);
}
