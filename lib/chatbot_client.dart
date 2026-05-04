import 'dart:async';

import 'chatbot_exception.dart';
import 'models/chat_message.dart';
import 'models/messages_response.dart';
import 'services/api_service.dart';

/// High-level client for the chatbot HTTP API.
class ChatbotClient {
  ChatbotClient({required String baseUrl}) : _api = ApiService(baseUrl: baseUrl);

  final ApiService _api;

  /// Starts a new agent chat session (`POST /api/chat/start-agent`).
  ///
  /// Returns the new [requestId] (GUID string).
  Future<String> startAgent({
    String? language,
    String? service,
    String? phone,
  }) async {
    final res = await _api.startAgent(
      language: language,
      service: service,
      phone: phone,
    );
    if (!res.success || res.requestId.isEmpty) {
      throw ChatbotException('Bad request');
    }
    return res.requestId;
  }

  /// Loads messages once (`GET /api/chat/messages/{requestId}`).
  Future<List<ChatMessage>> getMessages(String requestId) async {
    final res = await _api.getMessages(requestId);
    if (!res.found) {
      return const [];
    }
    return List<ChatMessage>.unmodifiable(res.messages);
  }

  /// Sends a customer message (`POST /api/chat/messages/{requestId}`).
  Future<void> sendMessage(String requestId, String message) =>
      _api.sendMessage(requestId, message);

  /// Closes the conversation (`POST /api/chat/requests/{requestId}/close`).
  Future<void> closeChat(String requestId) => _api.closeChat(requestId);

  /// Submits a rating (`POST /api/chat/requests/{requestId}/rating`).
  Future<void> rateChat(String requestId, String rating) =>
      _api.rateChat(requestId, rating);

  /// Polls [getMessages] every 3 seconds until `status == "Closed"`.
  ///
  /// Emits a growing, de-duplicated list (by message [ChatMessage.dedupeKey]).
  Stream<List<ChatMessage>> pollMessages(String requestId) async* {
    final seen = <String>{};
    var accumulated = <ChatMessage>[];

    while (true) {
      MessagesResponse res;
      try {
        res = await _api.getMessages(requestId);
      } catch (e, st) {
        yield List<ChatMessage>.unmodifiable(accumulated);
        Error.throwWithStackTrace(e, st);
      }

      if (res.found) {
        for (final m in res.messages) {
          final key = m.dedupeKey;
          if (!seen.contains(key)) {
            seen.add(key);
            accumulated = [...accumulated, m];
          }
        }
        accumulated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        yield List<ChatMessage>.unmodifiable(accumulated);

        if (res.status == 'Closed') {
          return;
        }
      } else {
        yield List<ChatMessage>.unmodifiable(accumulated);
      }

      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}
