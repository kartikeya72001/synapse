import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/secret_item.dart';

class SecretService {
  static Database? _database;
  static const String _tableName = 'secrets';
  static const String _encKeyAlias = 'synapse_enc_key';
  static const String _encIvAlias = 'synapse_enc_iv';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'synapse_secrets.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            encryptedValue TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<enc.Key> _getOrCreateKey() async {
    var keyStr = await _secureStorage.read(key: _encKeyAlias);
    if (keyStr == null) {
      final key = enc.Key.fromSecureRandom(32);
      keyStr = base64Encode(key.bytes);
      await _secureStorage.write(key: _encKeyAlias, value: keyStr);
    }
    return enc.Key.fromBase64(keyStr);
  }

  Future<enc.IV> _getOrCreateIV() async {
    var ivStr = await _secureStorage.read(key: _encIvAlias);
    if (ivStr == null) {
      final iv = enc.IV.fromSecureRandom(16);
      ivStr = base64Encode(iv.bytes);
      await _secureStorage.write(key: _encIvAlias, value: ivStr);
    }
    return enc.IV.fromBase64(ivStr);
  }

  String _encrypt(String plainText) {
    final key = _getOrCreateKeySync();
    if (key == null) return plainText;

    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Prepend IV (base64) with a separator so each secret has its own IV
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  String _decrypt(String encrypted) {
    final key = _getOrCreateKeySync();
    if (key == null) return encrypted;

    final encrypter = enc.Encrypter(enc.AES(key));

    // New format: "base64IV:base64Ciphertext"
    if (encrypted.contains(':')) {
      final parts = encrypted.split(':');
      if (parts.length == 2) {
        try {
          final iv = enc.IV.fromBase64(parts[0]);
          return encrypter.decrypt64(parts[1], iv: iv);
        } catch (_) {
          // Fall through to legacy decryption
        }
      }
    }

    // Legacy fallback: global IV for secrets encrypted before this change
    final iv = _getOrCreateIVSync();
    if (iv == null) return encrypted;
    return encrypter.decrypt64(encrypted, iv: iv);
  }

  enc.Key? _cachedKey;
  enc.IV? _cachedIV;

  enc.Key? _getOrCreateKeySync() => _cachedKey;
  enc.IV? _getOrCreateIVSync() => _cachedIV;

  Future<void> initKeys() async {
    _cachedKey = await _getOrCreateKey();
    _cachedIV = await _getOrCreateIV();
  }

  Future<bool> authenticate() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) return true;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to view your secrets',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> addSecret({
    required String title,
    String? description,
    required String value,
  }) async {
    await initKeys();
    final db = await database;
    final now = DateTime.now();
    final item = SecretItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      encryptedValue: _encrypt(value),
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(_tableName, item.toMap());
  }

  Future<void> updateSecret(SecretItem item, {String? newValue}) async {
    await initKeys();
    final db = await database;
    final updated = item.copyWith(
      encryptedValue: newValue != null ? _encrypt(newValue) : null,
      updatedAt: DateTime.now(),
    );
    await db.update(_tableName, updated.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteSecret(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SecretItem>> getAllSecrets() async {
    final db = await database;
    final maps = await db.query(_tableName, orderBy: 'createdAt DESC');
    return maps.map((m) => SecretItem.fromMap(m)).toList();
  }

  Future<String> decryptValue(String encryptedValue) async {
    await initKeys();
    return _decrypt(encryptedValue);
  }
}
