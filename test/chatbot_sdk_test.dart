import 'package:flutter_test/flutter_test.dart';

import 'package:ez_chatbot_sdk/chatbot_sdk.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson parses camelCase from API', () {
      final m = ChatMessage.fromJson({
        'id': 42,
        'sender': 'Agent',
        'message': 'Hello',
        'createdAt': '2026-05-01T12:00:00Z',
      });
      expect(m.id, 42);
      expect(m.sender, 'Agent');
      expect(m.message, 'Hello');
      expect(m.createdAt.toUtc().toIso8601String(), '2026-05-01T12:00:00.000Z');
    });

    test('dedupeKey uses id when positive', () {
      final a = ChatMessage(
        id: 1,
        sender: 'Agent',
        message: 'x',
        createdAt: DateTime.utc(2026),
      );
      expect(a.dedupeKey, 'id:1');
    });
  });

  group('StartAgentResponse', () {
    test('fromJson matches start-agent payload', () {
      final r = StartAgentResponse.fromJson({
        'success': true,
        'requestId': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      });
      expect(r.success, isTrue);
      expect(r.requestId, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
    });
  });

  group('MessagesResponse', () {
    test('fromJson matches get-messages payload', () {
      final r = MessagesResponse.fromJson({
        'found': true,
        'requestId': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        'status': 'WaitingAgent',
        'messages': [
          {
            'id': 1,
            'sender': 'Customer',
            'message': 'Hi',
            'createdAt': '2026-05-01T12:00:00Z',
          },
        ],
      });
      expect(r.found, isTrue);
      expect(r.status, 'WaitingAgent');
      expect(r.messages, hasLength(1));
      expect(r.messages.first.message, 'Hi');
    });
  });
}
