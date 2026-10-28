import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base SQLite locale. Aucune base distante n'est nécessaire.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int version = 4;

  static Future<AppDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              name TEXT,
              description TEXT,
              created_at TEXT,
              updated_at TEXT,
              payload TEXT,
              format_id TEXT,
              pack_id TEXT
            )''');
          await _createV2(db);
          await _createV3(db);
          await _createV4(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createV2(db);
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE projects ADD COLUMN format_id TEXT');
            await db.execute('ALTER TABLE projects ADD COLUMN pack_id TEXT');
            await _createV3(db);
          }
          if (oldVersion < 4) await _createV4(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createV2(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      payload TEXT
    )''');

  static Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS templates (
        id TEXT PRIMARY KEY,
        name TEXT,
        category TEXT,
        created_at TEXT,
        payload TEXT
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_updated ON projects(updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_pack ON projects(pack_id)',
    );
  }

  /// Version 4 : historique persistant des créations.
  static Future<void> _createV4(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS versions (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        number INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        label TEXT,
        kind TEXT,
        payload TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_versions_project ON versions(project_id, number)',
    );
  }

  Future<void> close() => db.close();
}
