import 'package:ez_chatbot_sdk/chatbot_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

ThemeData _ezTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4E86D9),
      primary: const Color(0xFF4E86D9),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF3F4658),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
  );
}

void main() {
  runApp(const ChatbotExampleApp());
}

class ChatbotExampleApp extends StatelessWidget {
  const ChatbotExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EZ Insurance',
      debugShowCheckedModeBanner: false,
      theme: _ezTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: _ExampleHome(),
      ),
    );
  }
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 520;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.all(narrow ? 16 : 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                'مثال تطبيق يستخدم EZChatbotWidget',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF8F96A8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const EZChatbotWidget(
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
