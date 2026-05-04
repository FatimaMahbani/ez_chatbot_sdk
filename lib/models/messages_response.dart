import 'chat_message.dart';

/// Response body from `GET /api/chat/messages/{requestId}`.
///
/// Backend returns `found`, `requestId`, optional `status`, and `messages`.
class MessagesResponse {
  const MessagesResponse({
    required this.found,
    required this.requestId,
    required this.status,
    required this.messages,
  });

  final bool found;
  final String requestId;
  final String status;
  final List<ChatMessage> messages;

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    final foundRaw = json['found'] ?? json['Found'];
    final found =
        foundRaw == true || foundRaw == 'true' || foundRaw == 1;

    final rid = json['requestId'] ?? json['RequestId'];
    final requestId = rid?.toString() ?? '';

    final status = (json['status'] ?? json['Status'] ?? '').toString();

    final rawList = json['messages'] ?? json['Messages'];
    final messages = <ChatMessage>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessage.fromJson(item));
        } else if (item is Map) {
          messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return MessagesResponse(
      found: found,
      requestId: requestId,
      status: status,
      messages: messages,
    );
  }
}
