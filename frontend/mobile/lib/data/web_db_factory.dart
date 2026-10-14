// Picks the SQLite factory for the current platform: sqflite on mobile, a WASM worker on web.
export 'web_db_factory_stub.dart' if (dart.library.js_interop) 'web_db_factory_web.dart';
