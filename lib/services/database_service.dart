import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/thought.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'thoughts';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> exposeDatabase() async => database;

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'synapse.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            url TEXT,
            imagePath TEXT,
            title TEXT,
            description TEXT,
            previewImageUrl TEXT,
            siteName TEXT,
            favicon TEXT,
            category TEXT DEFAULT 'other',
            llmSummary TEXT,
            extractedInfo TEXT,
            ocrText TEXT,
            cachedText TEXT,
            isLinkDead INTEGER DEFAULT 0,
            tags TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            isClassified INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE thought_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            color INTEGER NOT NULL DEFAULT 4288585374,
            autoDeleteDays INTEGER,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE thought_group_members (
            groupId TEXT NOT NULL,
            thoughtId TEXT NOT NULL,
            PRIMARY KEY (groupId, thoughtId),
            FOREIGN KEY (groupId) REFERENCES thought_groups(id) ON DELETE CASCADE,
            FOREIGN KEY (thoughtId) REFERENCES thoughts(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE saved_items ADD COLUMN favicon TEXT');
          await db.execute(
            'ALTER TABLE saved_items ADD COLUMN extractedInfo TEXT',
          );
        }
        if (oldVersion < 3) {
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='saved_items'",
          );
          if (tables.isNotEmpty) {
            await db.execute('ALTER TABLE saved_items RENAME TO thoughts');
          }
          for (final col in [
            'ocrText TEXT',
            'cachedText TEXT',
            'isLinkDead INTEGER DEFAULT 0',
          ]) {
            try {
              await db.execute('ALTER TABLE thoughts ADD COLUMN $col');
            } catch (_) {}
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS thought_groups (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              color INTEGER NOT NULL DEFAULT 4288585374,
              autoDeleteDays INTEGER,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS thought_group_members (
              groupId TEXT NOT NULL,
              thoughtId TEXT NOT NULL,
              PRIMARY KEY (groupId, thoughtId),
              FOREIGN KEY (groupId) REFERENCES thought_groups(id) ON DELETE CASCADE,
              FOREIGN KEY (thoughtId) REFERENCES thoughts(id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
  }

  Future<void> insertThought(Thought thought) async {
    final db = await database;
    await db.insert(
      _tableName,
      thought.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateThought(Thought thought) async {
    final db = await database;
    await db.update(
      _tableName,
      thought.toMap(),
      where: 'id = ?',
      whereArgs: [thought.id],
    );
  }

  Future<void> deleteThought(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Thought>> getAllThoughts() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Thought.fromMap(map)).toList();
  }

  Future<List<Thought>> getThoughtsByCategory(ThoughtCategory category) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Thought.fromMap(map)).toList();
  }

  Future<List<Thought>> searchThoughts(String query) async {
    final db = await database;
    final pattern = '%$query%';
    final maps = await db.query(
      _tableName,
      where:
          'title LIKE ? OR description LIKE ? OR tags LIKE ? OR url LIKE ? '
          'OR llmSummary LIKE ? OR extractedInfo LIKE ? OR ocrText LIKE ?',
      whereArgs: List.filled(7, pattern),
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Thought.fromMap(map)).toList();
  }

  Future<List<Thought>> getUnclassifiedThoughts() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'isClassified = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => Thought.fromMap(map)).toList();
  }

  Future<int> getThoughtCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
