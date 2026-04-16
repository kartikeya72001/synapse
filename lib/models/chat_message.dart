import 'dart:typed_data';
import '../services/compression_service.dart';

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
    final rawText = map['text'];
    final isCompressed = (map['isCompressed'] as int?) == 1;
    String text;
    if (isCompressed && rawText is Uint8List) {
      text = CompressionService.decompress(rawText);
    } else if (isCompressed && rawText is List<int>) {
      text = CompressionService.decompress(Uint8List.fromList(rawText));
    } else {
      text = rawText as String;
    }
    return ChatMessage(
      id: map['id'] as String,
      text: text,
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
