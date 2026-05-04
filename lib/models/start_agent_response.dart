/// Response body from `POST /api/chat/start-agent`.
///
/// Backend: `Ok(new { success = true, requestId = request.Id })`.
class StartAgentResponse {
  const StartAgentResponse({
    required this.success,
    required this.requestId,
  });

  final bool success;
  final String requestId;

  factory StartAgentResponse.fromJson(Map<String, dynamic> json) {
    final successRaw = json['success'] ?? json['Success'];
    final success = successRaw == true ||
        successRaw == 'true' ||
        successRaw == 1;

    final rid = json['requestId'] ?? json['RequestId'];
    final requestId = rid?.toString() ?? '';

    return StartAgentResponse(success: success, requestId: requestId);
  }
}
