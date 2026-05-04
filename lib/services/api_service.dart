import 'package:dio/dio.dart';

import '../chatbot_exception.dart';
import '../models/messages_response.dart';
import '../models/start_agent_response.dart';

/// Low-level HTTP calls to the chatbot API (Dio only).
class ApiService {
  ApiService({required String baseUrl})
        : _dio = Dio(
          BaseOptions(
            baseUrl: _normalizeBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            contentType: Headers.jsonContentType,
          ),
        );

  final Dio _dio;

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<StartAgentResponse> startAgent({
    String? language,
    String? service,
    String? phone,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/chat/start-agent',
        data: <String, dynamic>{
          if (language != null) 'language': language,
          if (service != null) 'service': service,
          if (phone != null) 'phone': phone,
        },
      );
      final data = res.data;
      if (data == null) {
        throw ChatbotException('Bad request');
      }
      return StartAgentResponse.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<MessagesResponse> getMessages(String requestId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/chat/messages/$requestId',
      );
      final data = res.data;
      if (data == null) {
        throw ChatbotException('Bad request');
      }
      return MessagesResponse.fromJson(data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> sendMessage(String requestId, String message) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/chat/messages/$requestId',
        data: <String, dynamic>{'message': message},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> closeChat(String requestId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/chat/requests/$requestId/close',
        data: <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> rateChat(String requestId, String rating) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/chat/requests/$requestId/rating',
        data: <String, dynamic>{'rating': rating},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  ChatbotException _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ChatbotException('Connection error');
    }

    final status = e.response?.statusCode;
    switch (status) {
      case 400:
        return ChatbotException('Bad request');
      case 401:
        return ChatbotException('Unauthorized');
      case 404:
        return ChatbotException('Not found');
      case 500:
      case 502:
      case 503:
        return ChatbotException('Server error');
      default:
        if (status != null && status >= 500) {
          return ChatbotException('Server error');
        }
        if (status != null) {
          return ChatbotException('Bad request');
        }
        if (e.type == DioExceptionType.badResponse) {
          return ChatbotException('Server error');
        }
        return ChatbotException('Connection error');
    }
  }
}
