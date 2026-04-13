import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
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
    'Image Path',
    'Preview Image URL',
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
      _escapeCsv(thought.imagePath),
      _escapeCsv(thought.previewImageUrl),
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
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
      final extDir = await getExternalStorageDirectory();
      return extDir;
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Lists `.csv` files from Downloads, Documents, and app storage (Android)
  /// or app documents (iOS), newest first.
  static Future<List<File>> listAllCsvFiles() async {
    final results = <File>[];
    final dirs = <Directory>[];

    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) dirs.add(downloads);
      final documents = Directory('/storage/emulated/0/Documents');
      if (await documents.exists()) dirs.add(documents);
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) dirs.add(extDir);
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dirs.add(docDir);
    }

    for (final dir in dirs) {
      try {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.csv'));
        results.addAll(files);
      } catch (_) {}
    }

    results.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return results;
  }

  /// Lists CSV files suitable for import (all `.csv` in known dirs).
  static Future<List<File>> listExportedCsvFiles() async {
    return listAllCsvFiles();
  }

  /// Parses a Synapse-exported CSV file back into Thought objects.
  static Future<List<Thought>> importFromCsv(File file) async {
    try {
      final content = await file.readAsString();
      final rows = _parseFullCsv(content);
      if (rows.length < 2) return [];

      final thoughts = <Thought>[];
      final uuid = Uuid();

      for (var i = 1; i < rows.length; i++) {
        final fields = rows[i];
        if (fields.length < 11) continue;

        final title = fields[0];
        final url = fields[1];
        final typeName = fields[2];
        final categoryLabel = fields[3];
        final tagsStr = fields[4];
        final siteName = fields[5];
        final description = fields[6];
        final llmSummary = fields[7];
        final isDeadStr = fields[8];
        final createdStr = fields[9];
        final updatedStr = fields[10];
        final imagePath = fields.length > 11 ? fields[11] : '';
        final previewImageUrl = fields.length > 12 ? fields[12] : '';

        final type = typeName == 'screenshot'
            ? ThoughtType.screenshot
            : ThoughtType.link;

        final category = ThoughtCategory.values.firstWhere(
          (c) => c.label.toLowerCase() == categoryLabel.toLowerCase(),
          orElse: () => ThoughtCategory.other,
        );

        final tags = tagsStr.isNotEmpty
            ? tagsStr.split(';').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
            : <String>[];

        DateTime createdAt;
        try {
          createdAt = DateTime.parse(createdStr);
        } catch (_) {
          createdAt = DateTime.now();
        }

        DateTime updatedAt;
        try {
          updatedAt = DateTime.parse(updatedStr);
        } catch (_) {
          updatedAt = DateTime.now();
        }

        thoughts.add(Thought(
          id: uuid.v4(),
          type: type,
          url: url.isNotEmpty ? url : null,
          title: title.isNotEmpty ? title : null,
          description: description.isNotEmpty ? description : null,
          siteName: siteName.isNotEmpty ? siteName : null,
          category: category,
          llmSummary: llmSummary.isNotEmpty ? llmSummary : null,
          isLinkDead: isDeadStr.toLowerCase() == 'yes',
          tags: tags,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isClassified: category != ThoughtCategory.other,
          imagePath: imagePath.isNotEmpty ? imagePath : null,
          previewImageUrl: previewImageUrl.isNotEmpty ? previewImageUrl : null,
        ));
      }

      return thoughts;
    } catch (e) {
      debugPrint('CSV import failed: $e');
      return [];
    }
  }

  static List<List<String>> _parseFullCsv(String content) {
    final rows = <List<String>>[];
    final fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < content.length) {
      final c = content[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            current.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          current.write(c);
          i++;
          continue;
        }
      } else {
        if (c == '"') {
          inQuotes = true;
          i++;
          continue;
        } else if (c == ',') {
          fields.add(current.toString());
          current = StringBuffer();
          i++;
          continue;
        } else if (c == '\n' || c == '\r') {
          fields.add(current.toString());
          rows.add(List<String>.from(fields));
          fields.clear();
          current = StringBuffer();
          if (c == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
            i += 2;
          } else {
            i++;
          }
          continue;
        } else {
          current.write(c);
          i++;
          continue;
        }
      }
    }

    if (current.isNotEmpty || fields.isNotEmpty) {
      fields.add(current.toString());
      rows.add(List<String>.from(fields));
    }

    return rows;
  }

}
