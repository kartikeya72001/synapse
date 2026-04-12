import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Collects structured debug logs during background processing and
/// writes them to a timestamped file in the Downloads folder.
class DebugLogger {
  static DebugLogger? _instance;
  static DebugLogger get instance => _instance ??= DebugLogger._();
  DebugLogger._();

  bool _enabled = false;
  bool get enabled => _enabled;

  final _buffer = <String>[];
  String? _currentSession;

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(AppConstants.debugLogPref) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.debugLogPref, value);
  }

  void startSession(String label) {
    if (!_enabled) return;
    _buffer.clear();
    _currentSession = label;
    _log('════════════════════════════════════════');
    _log('SESSION: $label');
    _log('TIME: ${DateTime.now().toIso8601String()}');
    _log('════════════════════════════════════════');
  }

  void log(String step, String message) {
    if (!_enabled) return;
    _log('[$step] $message');
    debugPrint('DBG [$step] $message');
  }

  void logError(String step, Object error) {
    if (!_enabled) return;
    _log('[$step] ❌ ERROR: $error');
    debugPrint('DBG [$step] ERROR: $error');
  }

  void _log(String line) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    _buffer.add('$ts  $line');
  }

  /// Flushes the current session to a file in Downloads.
  /// Returns the file path or null on failure.
  Future<String?> flush() async {
    if (!_enabled || _buffer.isEmpty) return null;

    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) return null;

      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final label = (_currentSession ?? 'session')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .substring(0, (_currentSession ?? '').length.clamp(0, 30));
      final file = File('${dir.path}/synapse_debug_${label}_$ts.txt');

      await file.writeAsString(_buffer.join('\n'));
      debugPrint('Debug log written to ${file.path}');
      _buffer.clear();
      return file.path;
    } catch (e) {
      debugPrint('Failed to write debug log: $e');
      return null;
    }
  }
}
