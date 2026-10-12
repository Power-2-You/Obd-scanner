import 'dart:convert';

/// Key/value store of JSON documents.
///
/// Repositories depend only on this interface, so the local file store can
/// later be complemented by a cloud-synchronised implementation (every record
/// already carries an id and updatedAt timestamp for conflict resolution).
abstract interface class DocumentStore {
  Future<Object?> read(String key);
  Future<void> write(String key, Object json);
  Future<void> delete(String key);
}

/// Volatile store used by tests and the web preview build.
class MemoryDocumentStore implements DocumentStore {
  final Map<String, String> _data = {};

  @override
  Future<Object?> read(String key) async {
    final v = _data[key];
    return v == null ? null : jsonDecode(v);
  }

  @override
  Future<void> write(String key, Object json) async {
    _data[key] = jsonEncode(json);
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
