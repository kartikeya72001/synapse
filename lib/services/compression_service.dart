import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class CompressionService {
  static Uint8List compress(String text) {
    final bytes = utf8.encode(text);
    return Uint8List.fromList(gzip.encode(bytes));
  }

  static String decompress(Uint8List compressed) {
    final decompressed = gzip.decode(compressed);
    return utf8.decode(decompressed);
  }

  /// Safely reads a DB field that may be stored as compressed BLOB or plain TEXT.
  /// Handles gzip, Brotli-corrupted, or raw UTF-8 gracefully.
  static String? readField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;

    final bytes = value is Uint8List ? value : Uint8List.fromList(value as List<int>);
    if (bytes.isEmpty) return null;

    // Try gzip first (magic bytes 0x1f 0x8b)
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        return decompress(bytes);
      } catch (_) {}
    }

    // Fallback: try raw UTF-8 decode (covers Brotli-corrupted or plain text stored as BLOB)
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Compresses a nullable string for DB storage.
  /// Returns null if input is null or empty.
  static Uint8List? compressField(String? value) {
    if (value == null || value.isEmpty) return null;
    return compress(value);
  }
}
