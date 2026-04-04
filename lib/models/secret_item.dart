class SecretItem {
  final String id;
  final String title;
  final String? description;
  final String encryptedValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  SecretItem({
    required this.id,
    required this.title,
    this.description,
    required this.encryptedValue,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'encryptedValue': encryptedValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SecretItem.fromMap(Map<String, dynamic> map) {
    return SecretItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      encryptedValue: map['encryptedValue'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  SecretItem copyWith({
    String? id,
    String? title,
    String? description,
    String? encryptedValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SecretItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      encryptedValue: encryptedValue ?? this.encryptedValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
