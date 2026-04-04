import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';
import '../models/thought.dart';
import '../services/database_service.dart';
import '../services/exif_service.dart';
import '../services/link_preview_service.dart';
import '../services/ocr_service.dart';

class ShareHandlerService {
  static final _urlRegex = RegExp(r'https?://\S+');

  final DatabaseService _db = DatabaseService();
  final LinkPreviewService _linkPreview = LinkPreviewService();
  final OcrService _ocr = OcrService();
  final ExifService _exif = ExifService();
  final Uuid _uuid = const Uuid();

  StreamSubscription? _intentSub;
  void Function(Thought)? onThoughtSaved;

  final Set<String> _processedPaths = {};
  bool _initialMediaHandled = false;

  void init() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (_) {},
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (!_initialMediaHandled && files.isNotEmpty) {
        _initialMediaHandled = true;
        _handleSharedFiles(files);
      }
    });
  }

  void dispose() {
    _intentSub?.cancel();
    _ocr.dispose();
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    final uniqueFiles = <SharedMediaFile>[];
    for (final file in files) {
      final key = file.path;
      if (!_processedPaths.contains(key)) {
        _processedPaths.add(key);
        uniqueFiles.add(file);
      }
    }

    for (final file in uniqueFiles) {
      if (file.type == SharedMediaType.url ||
          (file.type == SharedMediaType.text && _isUrl(file.path))) {
        await _handleSharedLink(file.path);
      } else if (file.type == SharedMediaType.image) {
        await _handleSharedImage(file.path);
      } else if (file.type == SharedMediaType.text) {
        final text = file.path;
        if (_containsUrl(text)) {
          final url = _extractUrl(text);
          if (url != null) {
            await _handleSharedLink(url);
          } else {
            await _handleSharedText(text);
          }
        } else {
          await _handleSharedText(text);
        }
      }
    }
  }

  Future<Thought> _handleSharedLink(String url) async {
    final preview = await _linkPreview.fetchPreview(url);
    final now = DateTime.now();
    final thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.link,
      url: url,
      title: preview?.title,
      description: preview?.description,
      previewImageUrl: preview?.imageUrl,
      siteName: preview?.siteName,
      favicon: preview?.favicon,
      tags: const ['link'],
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);
    return thought;
  }

  Future<Thought> _handleSharedImage(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'screenshots'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.png';
    final newPath = p.join(imagesDir.path, fileName);
    await File(filePath).copy(newPath);

    // Use the source file's modified date for proper chronological ordering
    final sourceFile = File(filePath);
    DateTime fileDate;
    try {
      fileDate = await sourceFile.lastModified();
    } catch (_) {
      fileDate = DateTime.now();
    }
    final now = DateTime.now();

    var thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.screenshot,
      imagePath: newPath,
      title: 'Screenshot',
      tags: const ['screenshot'],
      createdAt: fileDate,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);

    // Background OCR + EXIF extraction — only notify once at the end
    String? ocrText;
    String? exifUrl;

    try {
      ocrText = await _ocr.extractText(newPath);
    } catch (_) {}

    try {
      exifUrl = await _exif.extractUrlFromImage(filePath);
    } catch (_) {}

    String? url = exifUrl;
    if (url == null && ocrText != null && ocrText.isNotEmpty) {
      final match = _urlRegex.firstMatch(ocrText);
      url = match?.group(0);
    }

    if (ocrText != null || url != null) {
      thought = thought.copyWith(
        ocrText: ocrText ?? thought.ocrText,
        url: url ?? thought.url,
        updatedAt: DateTime.now(),
      );
      await _db.updateThought(thought);
    }

    return thought;
  }

  Future<Thought> _handleSharedText(String text) async {
    final now = DateTime.now();
    final thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.link,
      title: text.length > 100 ? '${text.substring(0, 100)}...' : text,
      description: text,
      tags: const ['link'],
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);
    return thought;
  }

  Future<Thought> saveLink(String url) async {
    return _handleSharedLink(url);
  }

  Future<Thought> saveImage(String filePath) async {
    return _handleSharedImage(filePath);
  }

  /// Import an image by path, skip if a screenshot with the same file size already exists.
  Future<Thought?> importImageIfNew(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) return null;
    final sourceSize = await sourceFile.length();

    final existing = await _db.getAllThoughts();
    for (final t in existing) {
      if (t.type != ThoughtType.screenshot || t.imagePath == null) continue;
      try {
        final existingFile = File(t.imagePath!);
        if (await existingFile.exists()) {
          final existingSize = await existingFile.length();
          if (existingSize == sourceSize) return null;
        }
      } catch (_) {}
    }
    return _handleSharedImage(filePath);
  }

  bool _isUrl(String text) {
    final trimmed = text.trim();
    return Uri.tryParse(trimmed)?.hasScheme ?? false;
  }

  bool _containsUrl(String text) {
    return _urlRegex.hasMatch(text);
  }

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }
}
