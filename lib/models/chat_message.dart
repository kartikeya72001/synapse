enum ChatMessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String text;
  final ChatMessageRole role;
  final DateTime timestamp;

  /// Optional reference to a thought (e.g. when a memory is absorbed).
  final String? thoughtId;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.thoughtId,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == ChatMessageRole.user;
  bool get isAssistant => role == ChatMessageRole.assistant;
  bool get isSystem => role == ChatMessageRole.system;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'thoughtId': thoughtId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      role: ChatMessageRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => ChatMessageRole.assistant,
      ),
      thoughtId: map['thoughtId'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
