import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/thought.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'thoughts';
  static const String _chatTable = 'chat_messages';
  static const String _embeddingsTable = 'embeddings';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> exposeDatabase() async => database;

  static const String _createEmbeddingsTableSql = '''
    CREATE TABLE IF NOT EXISTS $_embeddingsTable (
      thoughtId TEXT PRIMARY KEY,
      vector TEXT NOT NULL,
      textHash TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (thoughtId) REFERENCES thoughts(id) ON DELETE CASCADE
    )
  ''';

  static const String _createChatTableSql = '''
    CREATE TABLE IF NOT EXISTS $_chatTable (
      id TEXT PRIMARY KEY,
      text TEXT NOT NULL,
      role TEXT NOT NULL,
      thoughtId TEXT,
      timestamp TEXT NOT NULL
    )
  ''';

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'synapse.db');

    return await openDatabase(
      path,
      version: 6,
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
        await db.execute(_createChatTableSql);
        await db.execute(_createEmbeddingsTableSql);
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
        if (oldVersion < 4) {
          await db.execute(_createChatTableSql);
        }
        if (oldVersion < 5) {
          await db.execute(_createEmbeddingsTableSql);
        }
        if (oldVersion < 6) {
          await db.delete(_embeddingsTable);
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

  // ── Chat Messages ──

  Future<void> insertChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      _chatTable,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getAllChatMessages() async {
    final db = await database;
    final maps = await db.query(
      _chatTable,
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  Future<void> clearChatMessages() async {
    final db = await database;
    await db.delete(_chatTable);
  }

  // ── Embeddings ──

  Future<void> upsertEmbedding(
    String thoughtId,
    List<double> vector,
    String textHash,
  ) async {
    final db = await database;
    await db.insert(
      _embeddingsTable,
      {
        'thoughtId': thoughtId,
        'vector': jsonEncode(vector),
        'textHash': textHash,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, List<double>>> getAllEmbeddings() async {
    final db = await database;
    final maps = await db.query(_embeddingsTable);
    final result = <String, List<double>>{};
    for (final row in maps) {
      final id = row['thoughtId'] as String;
      final vectorJson = row['vector'] as String;
      final vector = (jsonDecode(vectorJson) as List)
          .map((v) => (v as num).toDouble())
          .toList();
      result[id] = vector;
    }
    return result;
  }

  Future<String?> getEmbeddingHash(String thoughtId) async {
    final db = await database;
    final maps = await db.query(
      _embeddingsTable,
      columns: ['textHash'],
      where: 'thoughtId = ?',
      whereArgs: [thoughtId],
    );
    if (maps.isEmpty) return null;
    return maps.first['textHash'] as String?;
  }

  Future<Set<String>> getEmbeddedThoughtIds() async {
    final db = await database;
    final maps = await db.query(
      _embeddingsTable,
      columns: ['thoughtId'],
    );
    return maps.map((m) => m['thoughtId'] as String).toSet();
  }

  Future<void> deleteEmbedding(String thoughtId) async {
    final db = await database;
    await db.delete(
      _embeddingsTable,
      where: 'thoughtId = ?',
      whereArgs: [thoughtId],
    );
  }
}
