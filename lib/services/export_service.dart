import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/thought.dart';

class ExportService {
  static const _csvHeaders = [
    'Title',
    'URL',
    'Type',
    'Category',
    'Tags',
    'Site Name',
    'Description',
    'LLM Summary',
    'Is Link Dead',
    'Created At',
    'Updated At',
  ];

  static String _escapeCsv(String? value) {
    if (value == null || value.isEmpty) return '';
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static String _thoughtToCsvRow(Thought thought) {
    return [
      _escapeCsv(thought.displayTitle),
      _escapeCsv(thought.url),
      _escapeCsv(thought.type.name),
      _escapeCsv(thought.category.label),
      _escapeCsv(thought.tags.join('; ')),
      _escapeCsv(thought.siteName),
      _escapeCsv(thought.description),
      _escapeCsv(thought.llmSummary),
      thought.isLinkDead ? 'Yes' : 'No',
      _escapeCsv(thought.createdAt.toIso8601String()),
      _escapeCsv(thought.updatedAt.toIso8601String()),
    ].join(',');
  }

  /// Exports the given thoughts to a CSV file in the device's Downloads
  /// directory. Returns the file path on success, or null on failure.
  static Future<String?> exportToCsv(List<Thought> thoughts) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(_csvHeaders.join(','));
      for (final thought in thoughts) {
        buffer.writeln(_thoughtToCsvRow(thought));
      }

      final directory = await _getExportDirectory();
      if (directory == null) return null;

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'synapse_export_$timestamp.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      debugPrint('CSV export failed: $e');
      return null;
    }
  }

  static Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Try the public Downloads folder first
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
      // Fallback to external storage root
      final extDir = await getExternalStorageDirectory();
      return extDir;
    }
    // iOS / other: use documents directory
    return await getApplicationDocumentsDirectory();
  }
}
