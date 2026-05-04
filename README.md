# ez_chatbot_sdk

EZ Insurance Flutter chatbot SDK with a ready-to-use support widget.

- **`EZChatbotWidget`**: Freshchat-like in-app support widget (FAQ + live chat)
- **`ChatbotClient`**: Direct access to the chatbot HTTP API

The backend (and any WhatChimp automation) is **external** to this package. This SDK only talks to the chatbot HTTP API.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ez_chatbot_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Usage (EZChatbotWidget)

```dart
import 'package:ez_chatbot_sdk/chatbot_sdk.dart';
import 'package:flutter/material.dart';

class MyHome extends StatelessWidget {
  const MyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: const [
          Center(child: Text('Your app')),
          EZChatbotWidget(
            baseUrl: 'https://ezinsurance-chatbot-api.onrender.com',
            language: 'ar',
            title: 'EZ Insurance Support',
            rtl: true,
          ),
        ],
      ),
    );
  }
}
```

Notes:

- The widget uses the public API via `ChatbotClient` (no backend code is bundled here).
- FAQ content is static (mirrors the hosted web widget). Chat uses the API.

## Usage (ChatbotClient directly)

```dart
import 'package:ez_chatbot_sdk/chatbot_sdk.dart';

final client = ChatbotClient(
  baseUrl: 'https://ezinsurance-chatbot-api.onrender.com', // no trailing slash required
);
```

### Start chat

```dart
try {
  final requestId = await client.startAgent(
    language: 'en',
    service: 'inquiry',
    phone: '0512345678',
  );
  print('Chat started: $requestId');
} on ChatbotException catch (e) {
  print(e.message);
}
```

### Send message

```dart
await client.sendMessage(requestId, 'I need help with my policy');
```

### Polling (live messages)

Polls every **3 seconds**, merges new lines without duplicates, and **stops** when the API returns `status == "Closed"`.

```dart
final sub = client.pollMessages(requestId).listen(
  (messages) {
    for (final m in messages) {
      print('[${m.sender}] ${m.message}');
    }
  },
  onError: (e, st) {
    if (e is ChatbotException) {
      print(e.message);
    }
  },
);

// When leaving the screen:
await sub.cancel();
```

### Close chat

```dart
await client.closeChat(requestId);
```

### Rate chat

```dart
await client.rateChat(requestId, 'up'); // or 'down'
```

## Troubleshooting

- **401 Unauthorized**: the backend may require auth, or your base URL is not pointing at the intended environment.
- **Connection error**: check connectivity and that `baseUrl` is reachable (try opening it in a browser).
- **Assets not showing inside `EZChatbotWidget`**: make sure you depend on `ez_chatbot_sdk` (not a renamed local folder without running `flutter pub get` again).

## License

MIT. See `LICENSE`.
