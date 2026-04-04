import 'dart:io';

import 'package:exif/exif.dart';

class ExifService {
  static final _urlRegex = RegExp(r'https?://\S+');

  String? _extractUrlFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  Future<String?> extractUrlFromImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) return null;

      // Check standard tags
      const tagsToCheck = [
        'Image ImageDescription',
        'Image UserComment',
        'Image XPComment',
      ];

      for (final tag in tagsToCheck) {
        final value = data[tag]?.printable;
        final url = _extractUrlFromText(value);
        if (url != null) return url;
      }

      // Iterate all tags for URL pattern (includes 0x9286 Samsung CapturedFrom)
      for (final entry in data.entries) {
        final value = entry.value.printable;
        final url = _extractUrlFromText(value);
        if (url != null) return url;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
