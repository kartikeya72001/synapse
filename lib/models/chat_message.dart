enum ChatMessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String text;
  final ChatMessageRole role;
  final DateTime timestamp;
  final String? conversationId;
  final String? imagePath;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.conversationId,
    this.imagePath,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == ChatMessageRole.user;
  bool get isAssistant => role == ChatMessageRole.assistant;
  bool get isSystem => role == ChatMessageRole.system;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      'conversationId': conversationId,
      'imagePath': imagePath,
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
      timestamp: DateTime.parse(map['timestamp'] as String),
      conversationId: map['conversationId'] as String?,
      imagePath: map['imagePath'] as String?,
    );
  }
}
