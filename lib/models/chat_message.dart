/// Single chat line as returned by `GET /api/chat/messages/{requestId}`.
///
/// Matches ChatBotAPI `ChatMessage` JSON (camelCase): `id`, `sender`, `message`, `createdAt`.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String message;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['Id'];
    final id = idRaw is int
        ? idRaw
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    final sender = (json['sender'] ?? json['Sender'] ?? '').toString();
    final message = (json['message'] ?? json['Message'] ?? '').toString();

    final createdRaw = json['createdAt'] ?? json['CreatedAt'];
    final createdAt = createdRaw is DateTime
        ? createdRaw
        : DateTime.tryParse(createdRaw?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return ChatMessage(
      id: id,
      sender: sender,
      message: message,
      createdAt: createdAt.isUtc ? createdAt : createdAt.toUtc(),
    );
  }

  /// Stable key for deduplication when [id] is zero or reused.
  String get dedupeKey => id > 0 ? 'id:$id' : 'f:${createdAt.toIso8601String()}\x00$sender\x00$message';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };
}
