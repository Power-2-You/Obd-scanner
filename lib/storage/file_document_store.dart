import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exception.dart';
import 'document_store.dart';

/// JSON files in the app's private Documents directory (included in the
/// user's encrypted iCloud/iTunes device backup, never shared with other apps).
class FileDocumentStore implements DocumentStore {
  FileDocumentStore(this._dir);

  final Directory _dir;

  static final RegExp _safeKey = RegExp(r'^[a-z0-9_\-]+$');

  File _file(String key) {
    if (!_safeKey.hasMatch(key)) {
      throw StorageException('Invalid storage key', detail: key);
    }
    return File('${_dir.path}/$key.json');
  }

  @override
  Future<Object?> read(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException catch (e) {
      // Keep the corrupt file for support, start fresh.
      await f.rename(
        '${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      throw StorageException(
        'Saved data was unreadable and has been reset.',
        detail: '$key: $e',
      );
    }
  }

  @override
  Future<void> write(String key, Object json) async {
    final f = _file(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path); // atomic replace
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }
}

Future<DocumentStore> createPlatformDocumentStore() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/mgh_iq');
  if (!await dir.exists()) await dir.create(recursive: true);
  return FileDocumentStore(dir);
}
