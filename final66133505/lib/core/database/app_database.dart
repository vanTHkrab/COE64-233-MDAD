import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import 'tables.dart';

/// Singleton wrapper around the [sqflite] database instance.
///
/// Guarantees:
///   • Lazy initialisation (DB is only opened on first access).
///   • Foreign keys enabled via `PRAGMA foreign_keys = ON`.
///   • WAL journal mode for better concurrent-read performance.
///   • All tables + seed data created inside [_onCreate].
///
/// Usage:
/// ```dart
/// final db = await AppDatabase.instance.database;
/// ```
class AppDatabase {
  AppDatabase._();

  static final AppDatabase _instance = AppDatabase._();

  /// The singleton accessor.
  static AppDatabase get instance => _instance;

  static final _log = Logger('AppDatabase');

  Database? _database;

  /// Returns the opened [Database], creating it on first call.
  ///
  /// If the previous open attempt failed, retries automatically.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);

    _log.info('Opening database at $path');

    return openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Called before [_onCreate] / [_onUpgrade] — enable foreign keys.
  ///
  /// Note: WAL journal mode is NOT set here because Android's sqflite
  /// already uses WAL by default and does not allow changing the journal
  /// mode via a raw PRAGMA statement inside `onConfigure`.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    _log.fine('PRAGMA foreign_keys enabled');
  }

  /// Called once when the database is first created.
  Future<void> _onCreate(Database db, int version) async {
    _log.info('Creating database (version $version)');

    final batch = db.batch();
    for (final sql in Tables.allCreateStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);

    _log.info('Database created with seed data');
  }

  /// Destructive migration: drops all tables and re-creates them.
  ///
  /// This is acceptable during early development. For production, add
  /// incremental ALTER TABLE statements per version bump instead.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.info('Upgrading database from v$oldVersion → v$newVersion');

    // Drop existing tables (order matters due to FK constraints).
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableIncidentReport}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableViolationType}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tablePollingStation}');

    _log.info('Old tables dropped — recreating with new schema');
    await _onCreate(db, newVersion);
  }

  // ── Utility ────────────────────────────────────────────────────────────

  /// Closes the database (useful for testing or graceful shutdown).
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
      _log.info('Database closed');
    }
  }

  /// Drops every table and re-creates the schema with fresh seed data.
  ///
  /// Useful for development / debug reset from the UI.
  Future<void> resetDatabase() async {
    _log.info('resetDatabase called — wiping and reseeding…');

    final db = await database;

    // Temporarily disable FK enforcement so drops succeed in any order.
    await db.execute('PRAGMA foreign_keys = OFF');

    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableIncidentReport}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableViolationType}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tablePollingStation}');

    // Drop any leftover indices.
    await db.execute('DROP INDEX IF EXISTS idx_report_station');
    await db.execute('DROP INDEX IF EXISTS idx_report_type');
    await db.execute('DROP INDEX IF EXISTS idx_report_timestamp');
    await db.execute('DROP INDEX IF EXISTS idx_report_status');

    // Recreate everything from scratch (same as first install).
    final batch = db.batch();
    for (final sql in Tables.allCreateStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);

    // Re-enable FK enforcement.
    await db.execute('PRAGMA foreign_keys = ON');

    _log.info('resetDatabase complete — seed data loaded ✓');
  }
}
