import 'package:sqflite/sqflite.dart';

import '../models/thought_group.dart';

class GroupService {
  final Future<Database> Function() _getDatabase;

  GroupService(this._getDatabase);

  Future<ThoughtGroup> createGroup(ThoughtGroup group) async {
    final db = await _getDatabase();
    await db.insert(
      'thought_groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return group;
  }

  Future<int> updateGroup(ThoughtGroup group) async {
    final db = await _getDatabase();
    return db.update(
      'thought_groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<int> deleteGroup(String groupId) async {
    final db = await _getDatabase();
    await db.delete(
      'thought_group_members',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    return db.delete(
      'thought_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  Future<List<ThoughtGroup>> getAllGroups() async {
    final db = await _getDatabase();
    final maps = await db.query(
      'thought_groups',
      orderBy: 'updatedAt DESC',
    );
    return maps.map((m) => ThoughtGroup.fromMap(m)).toList();
  }

  Future<void> addThoughtToGroup(String groupId, String thoughtId) async {
    final db = await _getDatabase();
    await db.insert(
      'thought_group_members',
      {'groupId': groupId, 'thoughtId': thoughtId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeThoughtFromGroup(String groupId, String thoughtId) async {
    final db = await _getDatabase();
    await db.delete(
      'thought_group_members',
      where: 'groupId = ? AND thoughtId = ?',
      whereArgs: [groupId, thoughtId],
    );
  }

  Future<List<ThoughtGroup>> getGroupsForThought(String thoughtId) async {
    final db = await _getDatabase();
    final maps = await db.rawQuery('''
      SELECT g.* FROM thought_groups g
      INNER JOIN thought_group_members m ON g.id = m.groupId
      WHERE m.thoughtId = ?
    ''', [thoughtId]);
    return maps.map((m) => ThoughtGroup.fromMap(m)).toList();
  }

  Future<List<String>> getThoughtIdsForGroup(String groupId) async {
    final db = await _getDatabase();
    final maps = await db.query(
      'thought_group_members',
      columns: ['thoughtId'],
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    return maps.map((m) => m['thoughtId'] as String).toList();
  }
}
