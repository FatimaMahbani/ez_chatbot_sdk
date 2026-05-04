/// Thrown when the chatbot API returns an error or the request fails.
class ChatbotException implements Exception {
  ChatbotException(this.message);

  final String message;

  @override
  String toString() => 'ChatbotException: $message';
}
