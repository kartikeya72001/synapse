import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'compression_service.dart';
import 'database_service.dart';
import 'debug_logger.dart';

class GoogleDriveService {
  static const _backupFileName = 'synapse_backup.br';
  static const _backupMime = 'application/octet-stream';
  static const int backupVersion = 2;

  final _dbg = DebugLogger.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? _account;
  drive.DriveApi? _driveApi;

  bool get isSignedIn => _account != null;
  String? get userEmail => _account?.email;
  String? get userDisplayName => _account?.displayName;

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;
      _driveApi = drive.DriveApi(httpClient);
      _dbg.log('DRIVE', 'Signed in as ${_account!.email}');
      return true;
    } catch (e) {
      _dbg.log('DRIVE', 'Sign-in error: $e');
      return false;
    }
  }

  Future<bool> signInSilently() async {
    try {
      _account = await _googleSignIn.signInSilently();
      if (_account == null) return false;
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return false;
      _driveApi = drive.DriveApi(httpClient);
      _dbg.log('DRIVE', 'Silent sign-in as ${_account!.email}');
      return true;
    } catch (e) {
      _dbg.log('DRIVE', 'Silent sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _driveApi = null;
    _dbg.log('DRIVE', 'Signed out');
  }

  Future<void> backup(DatabaseService db) async {
    if (_driveApi == null) throw StateError('Not signed in');

    _dbg.log('DRIVE', 'Starting backup...');

    // Collect all data from DB
    final thoughts = await db.getAllThoughtMaps();
    final embeddings = await db.getAllEmbeddingMaps();
    final conversations = await db.getAllConversationMaps();
    final chatMessages = await db.getAllChatMessageMaps();
    final groups = await db.getAllGroupMaps();
    final groupMembers = await db.getAllGroupMemberMaps();

    // Decompress blobs back to strings for portable JSON backup
    final portableThoughts = thoughts.map((row) {
      final m = Map<String, dynamic>.from(row);
      for (final field in [
        'description', 'llmSummary', 'extractedInfo',
        'ocrText', 'cachedText', 'userNotes',
      ]) {
        m[field] = CompressionService.readField(m[field]);
      }
      m.remove('isCompressed');
      return m;
    }).toList();

    final portableMessages = chatMessages.map((row) {
      final m = Map<String, dynamic>.from(row);
      final isCompressed = (m['isCompressed'] as int?) == 1;
      if (isCompressed) {
        m['text'] = CompressionService.readField(m['text']);
      }
      m.remove('isCompressed');
      return m;
    }).toList();

    final payload = {
      'version': backupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'thoughts': portableThoughts,
      'embeddings': embeddings,
      'conversations': conversations,
      'chatMessages': portableMessages,
      'groups': groups,
      'groupMembers': groupMembers,
    };

    final jsonString = jsonEncode(payload);
    _dbg.log('DRIVE', 'Payload: ${jsonString.length} chars');

    final compressed = await compute(_compressInIsolate, jsonString);
    _dbg.log('DRIVE', 'Compressed: ${compressed.length} bytes '
        '(${(compressed.length * 100 / jsonString.length).toStringAsFixed(1)}%)');

    // Delete old backup if it exists
    final existing = await _findBackupFile();
    if (existing != null) {
      await _driveApi!.files.delete(existing.id!);
      _dbg.log('DRIVE', 'Deleted old backup');
    }

    // Upload new backup
    final driveFile = drive.File()
      ..name = _backupFileName
      ..parents = ['appDataFolder'];

    final media = drive.Media(
      Stream.value(compressed),
      compressed.length,
      contentType: _backupMime,
    );

    await _driveApi!.files.create(driveFile, uploadMedia: media);
    _dbg.log('DRIVE', 'Backup uploaded');
  }

  Future<void> restore(DatabaseService db) async {
    if (_driveApi == null) throw StateError('Not signed in');

    _dbg.log('DRIVE', 'Starting restore...');

    final backupFile = await _findBackupFile();
    if (backupFile == null) throw StateError('No backup found on Drive');

    final media = await _driveApi!.files.get(
      backupFile.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <List<int>>[];
    await for (final chunk in media.stream) {
      chunks.add(chunk);
    }
    final compressed = Uint8List.fromList(chunks.expand((c) => c).toList());
    _dbg.log('DRIVE', 'Downloaded ${compressed.length} bytes');

    final jsonString = await compute(_decompressInIsolate, compressed);
    _dbg.log('DRIVE', 'Decompressed: ${jsonString.length} chars');

    final payload = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = payload['version'] as int? ?? 1;
    _dbg.log('DRIVE', 'Backup version: $version');

    // Clear all existing data
    await db.clearAllData();

    // Re-import thoughts (compress text fields for local storage)
    final rawThoughts =
        (payload['thoughts'] as List).cast<Map<String, dynamic>>();
    final compressedThoughts = rawThoughts.map((row) {
      final m = Map<String, dynamic>.from(row);
      for (final field in [
        'description', 'llmSummary', 'extractedInfo',
        'ocrText', 'cachedText', 'userNotes',
      ]) {
        final value = m[field];
        if (value != null && value is String && value.isNotEmpty) {
          m[field] = CompressionService.compress(value);
        }
      }
      m['isCompressed'] = 1;
      return m;
    }).toList();
    await db.importRawRows('thoughts', compressedThoughts);

    // Re-import embeddings as-is
    final rawEmbeddings =
        (payload['embeddings'] as List).cast<Map<String, dynamic>>();
    await db.importRawRows('embeddings', rawEmbeddings);

    // Re-import conversations
    final rawConversations =
        (payload['conversations'] as List).cast<Map<String, dynamic>>();
    await db.importRawRows('chat_conversations', rawConversations);

    // Re-import chat messages (stored uncompressed — active conversation)
    final rawMessages =
        (payload['chatMessages'] as List).cast<Map<String, dynamic>>();
    final messagesForImport = rawMessages.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['isCompressed'] = 0;
      return m;
    }).toList();
    await db.importRawRows('chat_messages', messagesForImport);

    // Re-import groups
    final rawGroups =
        (payload['groups'] as List).cast<Map<String, dynamic>>();
    await db.importRawRows('thought_groups', rawGroups);

    // Re-import group members
    final rawMembers =
        (payload['groupMembers'] as List).cast<Map<String, dynamic>>();
    await db.importRawRows('thought_group_members', rawMembers);

    _dbg.log('DRIVE', 'Restore complete: '
        '${rawThoughts.length} thoughts, '
        '${rawEmbeddings.length} embeddings, '
        '${rawConversations.length} conversations, '
        '${rawMessages.length} messages');
  }

  Future<DateTime?> lastBackupTime() async {
    if (_driveApi == null) return null;
    final file = await _findBackupFile();
    return file?.modifiedTime;
  }

  /// Runs a backup if the configured auto-backup interval has elapsed.
  /// Returns true if a backup was performed.
  Future<bool> autoBackupIfNeeded(DatabaseService db) async {
    if (!isSignedIn) return false;

    final prefs = await SharedPreferences.getInstance();
    final frequencyHours = prefs.getInt(AppConstants.backupFrequencyPref);
    if (frequencyHours == null || frequencyHours <= 0) return false;

    final lastBackupStr = prefs.getString(AppConstants.lastAutoBackupPref);
    if (lastBackupStr != null) {
      final lastBackup = DateTime.tryParse(lastBackupStr);
      if (lastBackup != null) {
        final elapsed = DateTime.now().difference(lastBackup);
        if (elapsed.inHours < frequencyHours) return false;
      }
    }

    _dbg.log('DRIVE', 'Auto-backup triggered (frequency: ${frequencyHours}h)');
    try {
      await backup(db);
      await prefs.setString(
        AppConstants.lastAutoBackupPref,
        DateTime.now().toIso8601String(),
      );
      _dbg.log('DRIVE', 'Auto-backup complete');
      return true;
    } catch (e) {
      _dbg.log('DRIVE', 'Auto-backup failed: $e');
      return false;
    }
  }

  Future<drive.File?> _findBackupFile() async {
    if (_driveApi == null) return null;
    final fileList = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, name, modifiedTime)',
    );
    if (fileList.files == null || fileList.files!.isEmpty) return null;
    return fileList.files!.first;
  }
}

Uint8List _compressInIsolate(String jsonString) {
  return CompressionService.compress(jsonString);
}

String _decompressInIsolate(Uint8List compressed) {
  return CompressionService.decompress(compressed);
}
