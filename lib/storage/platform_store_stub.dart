import 'document_store.dart';

/// Web preview: data lives only for the browser session.
Future<DocumentStore> createPlatformDocumentStore() async =>
    MemoryDocumentStore();
