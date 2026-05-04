import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatbot_sdk_example/main.dart';

void main() {
  testWidgets('smoke: FAB opens panel with welcome', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatbotExampleApp());
    expect(find.byIcon(Icons.headset_mic_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.headset_mic_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('أهلاً بك'), findsOneWidget);
    expect(find.textContaining('التواصل مع الدعم'), findsOneWidget);
  });
}
