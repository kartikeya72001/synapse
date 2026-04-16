import '../services/compression_service.dart';

enum ThoughtType { link, screenshot }

enum ThoughtCategory {
  article,
  socialMedia,
  video,
  image,
  recipe,
  product,
  news,
  reference,
  inspiration,
  todo,
  game,
  family,
  entertainment,
  music,
  tool,
  vacation,
  sports,
  stocks,
  education,
  health,
  finance,
  travel,
  other,
}

extension ThoughtCategoryExtension on ThoughtCategory {
  String get label {
    switch (this) {
      case ThoughtCategory.article:
        return 'Article';
      case ThoughtCategory.socialMedia:
        return 'Social Media';
      case ThoughtCategory.video:
        return 'Video';
      case ThoughtCategory.image:
        return 'Image';
      case ThoughtCategory.recipe:
        return 'Recipe';
      case ThoughtCategory.product:
        return 'Product';
      case ThoughtCategory.news:
        return 'News';
      case ThoughtCategory.reference:
        return 'Reference';
      case ThoughtCategory.inspiration:
        return 'Inspiration';
      case ThoughtCategory.todo:
        return 'To-Do';
      case ThoughtCategory.game:
        return 'Game';
      case ThoughtCategory.family:
        return 'Family';
      case ThoughtCategory.entertainment:
        return 'Movies/Series';
      case ThoughtCategory.music:
        return 'Music';
      case ThoughtCategory.tool:
        return 'Tool';
      case ThoughtCategory.vacation:
        return 'Vacation';
      case ThoughtCategory.sports:
        return 'Sports';
      case ThoughtCategory.stocks:
        return 'Stocks';
      case ThoughtCategory.education:
        return 'Education';
      case ThoughtCategory.health:
        return 'Health';
      case ThoughtCategory.finance:
        return 'Finance';
      case ThoughtCategory.travel:
        return 'Travel';
      case ThoughtCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ThoughtCategory.article:
        return '📄';
      case ThoughtCategory.socialMedia:
        return '💬';
      case ThoughtCategory.video:
        return '🎬';
      case ThoughtCategory.image:
        return '🖼️';
      case ThoughtCategory.recipe:
        return '🍳';
      case ThoughtCategory.product:
        return '🛒';
      case ThoughtCategory.news:
        return '📰';
      case ThoughtCategory.reference:
        return '📚';
      case ThoughtCategory.inspiration:
        return '✨';
      case ThoughtCategory.todo:
        return '✅';
      case ThoughtCategory.game:
        return '🎮';
      case ThoughtCategory.family:
        return '👨‍👩‍👧‍👦';
      case ThoughtCategory.entertainment:
        return '🎥';
      case ThoughtCategory.music:
        return '🎵';
      case ThoughtCategory.tool:
        return '🔧';
      case ThoughtCategory.vacation:
        return '🏖️';
      case ThoughtCategory.sports:
        return '⚽';
      case ThoughtCategory.stocks:
        return '📈';
      case ThoughtCategory.education:
        return '🎓';
      case ThoughtCategory.health:
        return '💊';
      case ThoughtCategory.finance:
        return '💰';
      case ThoughtCategory.travel:
        return '✈️';
      case ThoughtCategory.other:
        return '📌';
    }
  }
}

ThoughtCategory categoryFromString(String value) {
  return ThoughtCategory.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ThoughtCategory.other,
  );
}

class Thought {
  final String id;
  final ThoughtType type;
  final String? url;
  final String? imagePath;
  final String? title;
  final String? description;
  final String? previewImageUrl;
  final String? siteName;
  final String? favicon;
  final ThoughtCategory category;
  final String? llmSummary;
  final String? extractedInfo;
  final String? ocrText;
  final String? cachedText;
  final bool isLinkDead;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isClassified;
  final String? userNotes;

  Thought({
    required this.id,
    required this.type,
    this.url,
    this.imagePath,
    this.title,
    this.description,
    this.previewImageUrl,
    this.siteName,
    this.favicon,
    this.category = ThoughtCategory.other,
    this.llmSummary,
    this.extractedInfo,
    this.ocrText,
    this.cachedText,
    this.isLinkDead = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isClassified = false,
    this.userNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'url': url,
      'imagePath': imagePath,
      'title': title,
      'description': CompressionService.compressField(description),
      'previewImageUrl': previewImageUrl,
      'siteName': siteName,
      'favicon': favicon,
      'category': category.name,
      'llmSummary': CompressionService.compressField(llmSummary),
      'extractedInfo': CompressionService.compressField(extractedInfo),
      'ocrText': CompressionService.compressField(ocrText),
      'cachedText': CompressionService.compressField(cachedText),
      'isLinkDead': isLinkDead ? 1 : 0,
      'tags': tags.join(','),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isClassified': isClassified ? 1 : 0,
      'userNotes': CompressionService.compressField(userNotes),
      'isCompressed': 1,
    };
  }

  factory Thought.fromMap(Map<String, dynamic> map) {
    // Always try readField — it handles both BLOB and plain TEXT gracefully
    return Thought(
      id: map['id'] as String,
      type: ThoughtType.values.firstWhere((e) => e.name == map['type']),
      url: map['url'] as String?,
      imagePath: map['imagePath'] as String?,
      title: map['title'] as String?,
      description: CompressionService.readField(map['description']),
      previewImageUrl: map['previewImageUrl'] as String?,
      siteName: map['siteName'] as String?,
      favicon: map['favicon'] as String?,
      category: categoryFromString(map['category'] as String? ?? 'other'),
      llmSummary: CompressionService.readField(map['llmSummary']),
      extractedInfo: CompressionService.readField(map['extractedInfo']),
      ocrText: CompressionService.readField(map['ocrText']),
      cachedText: CompressionService.readField(map['cachedText']),
      isLinkDead: (map['isLinkDead'] as int?) == 1,
      tags: (map['tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isClassified: (map['isClassified'] as int?) == 1,
      userNotes: CompressionService.readField(map['userNotes']),
    );
  }

  Thought copyWith({
    String? id,
    ThoughtType? type,
    String? url,
    String? imagePath,
    String? title,
    String? description,
    String? previewImageUrl,
    String? siteName,
    String? favicon,
    ThoughtCategory? category,
    String? llmSummary,
    String? extractedInfo,
    String? ocrText,
    String? cachedText,
    bool? isLinkDead,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isClassified,
    String? userNotes,
  }) {
    return Thought(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      imagePath: imagePath ?? this.imagePath,
      title: title ?? this.title,
      description: description ?? this.description,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      siteName: siteName ?? this.siteName,
      favicon: favicon ?? this.favicon,
      category: category ?? this.category,
      llmSummary: llmSummary ?? this.llmSummary,
      extractedInfo: extractedInfo ?? this.extractedInfo,
      ocrText: ocrText ?? this.ocrText,
      cachedText: cachedText ?? this.cachedText,
      isLinkDead: isLinkDead ?? this.isLinkDead,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isClassified: isClassified ?? this.isClassified,
      userNotes: userNotes ?? this.userNotes,
    );
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (url != null) return Uri.tryParse(url!)?.host ?? url!;
    return 'Screenshot';
  }
}
