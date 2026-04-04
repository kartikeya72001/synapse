class ThoughtGroup {
  final String id;
  final String name;
  final String? description;
  final int color; // Material color int value
  final int? autoDeleteDays; // null = use global policy
  final DateTime createdAt;
  final DateTime updatedAt;

  const ThoughtGroup({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.autoDeleteDays,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'autoDeleteDays': autoDeleteDays,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ThoughtGroup.fromMap(Map<String, dynamic> map) {
    return ThoughtGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      color: map['color'] as int,
      autoDeleteDays: map['autoDeleteDays'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  ThoughtGroup copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
    int? autoDeleteDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ThoughtGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      autoDeleteDays: autoDeleteDays ?? this.autoDeleteDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
