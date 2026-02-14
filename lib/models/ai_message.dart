class AiMessage {
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final DateTime createdAt;

  AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
