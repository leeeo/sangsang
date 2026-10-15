import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: SQLite compiled to WASM, persisted in the browser (IndexedDB) via a shared worker.
DatabaseFactory? webDatabaseFactory() => databaseFactoryFfiWeb;
