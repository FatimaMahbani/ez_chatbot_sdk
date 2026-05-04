import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../chatbot_client.dart';
import '../chatbot_exception.dart';
import '../models/chat_message.dart';
import '../models/start_agent_response.dart';

/// Packaged screenshots for FAQ article `buy_new` (mirrors web `/chatbot-widget/images/ez-*.jpg`).
abstract final class _EzFaqArticleImages {
  static const home = 'assets/faq/ez-home.png';
  static const login = 'assets/faq/ez-login.png';
  static const register = 'assets/faq/ez-register.png';
  static const otp = 'assets/faq/ez-otp.png';
}

/// Web `chatbot-widget.css` (`#insurance-chatbot`, `--ez-*`) design tokens.
abstract final class _Ez {
  static const blue = Color(0xFF4E86D9);
  static const blue2 = Color(0xFF3F7FD8);
  static const headerGradientA = Color(0xFF5B8FD9);
  static const page = Color(0xFFF5F6FA);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF3F4658);
  static const muted = Color(0xFF8F96A8);
  static const border = Color(0xFFEEF2F7);
  static const botBubble = Color(0xFFEEF3F6);
  static const supportIconBg = Color(0xFFEEF4FF);
  /// `box-shadow: 0 18px 48px rgba(31, 45, 61, 0.18)`
  static const panelShadow = Color(0x2E1F2D3D);
  /// `0 8px 20px rgba(0, 0, 0, 0.06)`
  static const cardShadowSoft = Color(0x0F000000);
  static const toggleShadow = Color(0x381F2D3D);
  static const toggleShadowHover = Color(0x421F2D3D);
  static const actionBarTopBorder = Color(0x0F122E4E);
  static const composerTopBorder = Color(0x14122E4E);
  static const inputBorder = Color(0x1F122E4E);
  static const radiusPanel = 24.0;
  static const radiusBubble = 18.0;
  static const radiusHeaderBtn = 12.0;
  static const radiusRating = 16.0;
  static const radiusRatingBtn = 12.0;
  static const composerGap = 10.0;
  static const headerHeight = 128.0;
  static const headerHeightChat = 132.0;
  static const fabSize = 64.0;
  static const panelW = 420.0;
  static const panelH = 620.0;
}

/// Web `chatbot-widget.js` template — header watermark logo.
const String _kEzHeaderLogoUrl =
    'https://fc-use1-00-pics-bkt-00.s3.amazonaws.com/742cbb0e27a2f1913c29af682e2cde3bfba308a89a0d2c7b29ae1aaf881ecdfc/f_appLevelPicFull/img_advekcqdbm_222351d293de3f9feb9c39e156cba69a5676303120114a4c8a3da7b6252c554a.png';

enum _PanelScreen { home, chat }

/// FAQ area under the gradient header (mirrors web `data-screen` home/vehicles/cancel/article).
enum _HomeShell { main, vehicles, cancel, article }

/// Mirrors web `step`: `lang` | `menu` | `phone` | `submitting` | `done`.
enum _FlowStep { lang, menu, phone, submitting, done }

enum _SenderKind { customer, agent, system }

_SenderKind _senderKind(String sender) {
  final s = sender.trim();
  if (s == 'Customer') return _SenderKind.customer;
  if (s == 'System') return _SenderKind.system;
  return _SenderKind.agent;
}

String _formatMessageTime(DateTime createdAtUtc) {
  final local = createdAtUtc.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatWallClock(DateTime local) {
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

double _bubbleMaxWidth(double panelInnerWidth) {
  return math.min(panelInnerWidth * 0.92, 20 * 16.0);
}

/// Web `#insurance-chatbot` chat column is RTL; Flutter uses LTR for English chat.
AlignmentDirectional _userBubbleAlignment(TextDirection td) =>
    td == TextDirection.rtl
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;

CrossAxisAlignment _userBubbleCross(TextDirection td) =>
    td == TextDirection.rtl ? CrossAxisAlignment.start : CrossAxisAlignment.end;

AlignmentDirectional _botBubbleAlignment(TextDirection td) =>
    td == TextDirection.rtl
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;

CrossAxisAlignment _botBubbleCross(TextDirection td) =>
    td == TextDirection.rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;

/// Same rules as [ApiService] base URL normalization (widget-only duplicate for start-agent Dio call).
String _ezNormalizeApiBaseUrl(String url) {
  var u = url.trim();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// Mirrors [ApiService] `_mapDioException` messages for start-agent failures.
String _userMessageForStartAgentDio(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return 'Connection error';
  }

  final status = e.response?.statusCode;
  switch (status) {
    case 400:
      return 'Bad request';
    case 401:
      return 'Unauthorized';
    case 404:
      return 'Not found';
    case 500:
    case 502:
    case 503:
      return 'Server error';
    default:
      if (status != null && status >= 500) {
        return 'Server error';
      }
      if (status != null) {
        return 'Bad request';
      }
      if (e.type == DioExceptionType.badResponse) {
        return 'Server error';
      }
      return 'Connection error';
  }
}

// --- Web `SERVICES_AR` / `SERVICES_EN` (chatbot-widget.js) ---

typedef _Svc = ({String label, String key});

const _servicesAr = <_Svc>[
  (label: 'شراء تأمين', key: 'buy_insurance'),
  (label: 'تجديد وثيقة', key: 'renew_policy'),
  (label: 'مطالبة', key: 'claim'),
  (label: 'استفسار', key: 'inquiry'),
  (label: 'دعم فني', key: 'technical_support'),
];

const _servicesEn = <_Svc>[
  (label: 'Buy Insurance', key: 'buy_insurance'),
  (label: 'Renew Policy', key: 'renew_policy'),
  (label: 'Claim', key: 'claim'),
  (label: 'Inquiry', key: 'inquiry'),
  (label: 'Technical Support', key: 'technical_support'),
];

/// Same keys as web `chatbot-widget.js` `startAgentRequest` JSON `service` field (not display labels).
const _startAgentServiceKeys = <String>{
  'buy_insurance',
  'renew_policy',
  'claim',
  'inquiry',
  'technical_support',
};

/// Timeline entries: scripted UI + API messages (web `messagesEl` + polling).
sealed class _TEntry {
  _TEntry(this.sortKey);
  final int sortKey;
  DateTime get sortTime;
}

final class _TLocalUser extends _TEntry {
  _TLocalUser(super.sortKey, this.text, this.at, {this.optimistic = false});
  final String text;
  final DateTime at;
  /// When true, row may be removed when the same text arrives from polling as Customer.
  final bool optimistic;
  @override
  DateTime get sortTime => at;
}

final class _TLocalBot extends _TEntry {
  _TLocalBot(
    super.sortKey,
    this.lines,
    this.at, {
    this.pending = false,
    this.subtle = false,
  });
  final List<String> lines;
  final DateTime at;
  final bool pending;
  /// System-style line (conversation ended, thanks) — web-muted.
  final bool subtle;
  @override
  DateTime get sortTime => at;
}

final class _TApi extends _TEntry {
  _TApi(super.sortKey, this.message);
  final ChatMessage message;
  @override
  DateTime get sortTime => message.createdAt.toLocal();
}

/// Ready-to-use floating chat UI backed by [ChatbotClient].
///
/// Flow matches the hosted web widget (`chatbot-widget.js`): **home** → open
/// support → **language** → **service** → **phone** (composer) →
/// `startAgent` → **messages** → close → **rating**.
///
/// Place inside a [Stack] over your page. Does not export [ApiService].
class EZChatbotWidget extends StatefulWidget {
  const EZChatbotWidget({
    super.key,
    required this.baseUrl,
    this.phone,
    this.language,
    this.service,
    this.title = 'EZ Insurance Support',
    this.rtl = true,
  });

  final String baseUrl;
  final String? phone;
  final String? language;
  final String? service;
  final String title;
  final bool rtl;

  @override
  State<EZChatbotWidget> createState() => _EZChatbotWidgetState();
}

class _EZChatbotWidgetState extends State<EZChatbotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panelAnim;
  final _composerCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _faqArticleScroll = ScrollController();
  final _composerFocus = FocusNode();

  _PanelScreen _panelScreen = _PanelScreen.home;
  _HomeShell _homeShell = _HomeShell.main;
  /// Web `data-article-back`: parent list when leaving article via subheader back.
  _HomeShell _articleParent = _HomeShell.vehicles;
  String _articleKey = 'buy_new';
  int? _articleFeedback; // 1 = up, 0 = down, null = none
  bool _flowStarted = false;
  String? _uiLang;
  String? _selectedServiceKey;

  _FlowStep _step = _FlowStep.lang;

  final List<_TEntry> _timeline = [];
  int _sortSeq = 0;

  List<_Svc> _langButtons = [];
  List<_Svc> _serviceButtons = [];

  ChatbotClient? _client;
  String? _requestId;
  List<ChatMessage> _apiMessages = [];
  StreamSubscription<List<ChatMessage>>? _pollSub;
  Object? _lastError;
  bool _closedLineShown = false;
  bool _agentSubmitting = false;
  bool _sending = false;
  bool _closing = false;
  bool _ratingBusy = false;
  bool _panelOpen = false;
  bool _showRating = false;

  bool get _homeUsesEn =>
      (widget.language ?? '').toLowerCase().startsWith('en');

  bool get _flowIsEn => _uiLang == 'en';

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    unawaited(_pollSub?.cancel());
    _composerCtrl.dispose();
    _scrollController.dispose();
    _faqArticleScroll.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  /// Web: `.chatbot-composer.is-active` for `phone` | `done`, plus visible (disabled) during `submitting`.
  bool get _composerRowVisible =>
      _panelScreen == _PanelScreen.chat &&
      !_showRating &&
      (_step == _FlowStep.phone ||
          _step == _FlowStep.submitting ||
          _step == _FlowStep.done);

  bool get _closeEnabled =>
      _requestId != null &&
      _step == _FlowStep.done &&
      !_closing &&
      !_showRating;

  void _setPanelOpen(bool open) {
    setState(() {
      _panelOpen = open;
      // Web `setOpen(true)` calls `showScreen("home")` for the FAQ stage.
      if (open && _panelScreen == _PanelScreen.home) {
        _homeShell = _HomeShell.main;
      }
    });
    if (open) {
      _panelAnim.forward();
    } else {
      // Web: header X only hides the panel; conversation + polling continue.
      _panelAnim.reverse();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _enterChat() {
    setState(() => _panelScreen = _PanelScreen.chat);
    if (!_flowStarted) {
      _flowStarted = true;
      _showWelcomeAndLanguage();
    }
    _scrollToBottom();
  }

  void _goHomeFromChat() {
    setState(() {
      _panelScreen = _PanelScreen.home;
      _homeShell = _HomeShell.main;
    });
  }

  /// Web `showWelcomeAndLanguage`.
  void _showWelcomeAndLanguage() {
    _composerCtrl.clear();
    setState(() {
      _closedLineShown = false;
      _step = _FlowStep.lang;
      _uiLang = null;
      _selectedServiceKey = null;
      _timeline
        ..clear()
        ..add(
          _TLocalBot(
            _sortSeq++,
            const [
              'أهلًا بك 👋',
              'كيف يمكننا مساعدتك اليوم؟',
              '',
              'اختر اللغة للمتابعة',
              'Choose your preferred language',
            ],
            DateTime.now(),
          ),
        );
      _langButtons = const [
        (label: 'العربية', key: 'ar'),
        (label: 'English', key: 'en'),
      ];
      _serviceButtons = [];
    });
  }

  void _onLanguagePicked(_Svc choice) {
    setState(() {
      _uiLang = choice.key;
      _appendLocalUser(choice.label);
      _langButtons = [];
    });
    _showServiceMenu();
  }

  /// Web `showServiceMenu`.
  void _showServiceMenu() {
    final lines =
        _flowIsEn ? const ['How can we help you?'] : const ['كيف نقدر نخدمك؟'];
    setState(() {
      _step = _FlowStep.menu;
      _timeline.add(_TLocalBot(_sortSeq++, lines, DateTime.now()));
      _serviceButtons = _flowIsEn ? _servicesEn : _servicesAr;
    });
    _scrollToBottom();
  }

  void _onServicePicked(_Svc item) {
    setState(() {
      _selectedServiceKey = item.key;
      _appendLocalUser(item.label);
      _serviceButtons = [];
      _step = _FlowStep.phone;
      final prompt = _flowIsEn
          ? 'Please enter your mobile number'
          : 'الرجاء إدخال رقم الجوال';
      _timeline.add(_TLocalBot(_sortSeq++, [prompt], DateTime.now()));
    });
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  void _appendLocalUser(String text, {bool optimistic = false}) {
    _timeline.add(_TLocalUser(_sortSeq++, text, DateTime.now(), optimistic: optimistic));
  }

  void _appendClosedLineOnce() {
    if (_closedLineShown) return;
    _closedLineShown = true;
    final line = _flowIsEn ? 'Conversation ended.' : 'تم إنهاء المحادثة.';
    _timeline.add(_TLocalBot(_sortSeq++, [line], DateTime.now(), subtle: true));
  }

  void _appendThanksLine() {
    final line = _flowIsEn ? 'Thank you for your feedback.' : 'شكرًا لتقييمك.';
    _timeline.add(_TLocalBot(_sortSeq++, [line], DateTime.now(), subtle: true));
  }

  void _removePendingAgentBubble() {
    _timeline.removeWhere((e) => e is _TLocalBot && e.pending);
  }

  /// Web `startAgentRequest`: JSON `language` is exactly `"ar"` or `"en"` (chatbot-widget.js).
  String _canonicalStartAgentLanguage() {
    final u = (_uiLang ?? '').trim().toLowerCase();
    return u == 'en' ? 'en' : 'ar';
  }

  /// Web `submitPhone` + `startAgentRequest`.
  Future<void> _submitPhone() async {
    if (_step != _FlowStep.phone || _uiLang == null) return;
    final raw = _composerCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _lastError = _flowIsEn
            ? 'Please enter your mobile number'
            : 'الرجاء إدخال رقم الجوال';
      });
      _composerFocus.requestFocus();
      return;
    }

    final serviceCode = _selectedServiceKey?.trim();
    if (serviceCode == null ||
        serviceCode.isEmpty ||
        !_startAgentServiceKeys.contains(serviceCode)) {
      setState(() {
        _lastError = _flowIsEn
            ? 'Please choose a service from the buttons, then enter your phone.'
            : 'الرجاء اختيار الخدمة من الأزرار ثم إدخال رقم الجوال.';
      });
      _composerFocus.requestFocus();
      return;
    }

    final languageCode = _canonicalStartAgentLanguage();

    setState(() => _lastError = null);
    _appendLocalUser(raw);
    _composerCtrl.clear();
    setState(() {
      _step = _FlowStep.submitting;
      _timeline.add(
        _TLocalBot(
          _sortSeq++,
          const ['جاري تحويلك لموظف...'],
          DateTime.now(),
          pending: true,
        ),
      );
      _agentSubmitting = true;
    });
    _scrollToBottom();

    final base = widget.baseUrl.trim();
    if (base.isEmpty) {
      _onStartAgentFailed(removePending: true, message: 'Invalid API URL');
      return;
    }

    // Web widget sends composer text only — never `EZChatbotWidget` constructor `phone`.
    final normalizedBase = _ezNormalizeApiBaseUrl(base);
    debugPrint(
      'START_AGENT_PAYLOAD:\n'
      'baseUrl: $normalizedBase\n'
      'language: $languageCode\n'
      'service: $serviceCode\n'
      'phone: $raw',
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: normalizedBase,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {Headers.contentTypeHeader: Headers.jsonContentType},
        validateStatus: (_) => true,
      ),
    );

    final String rid;
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/api/chat/start-agent',
        data: <String, dynamic>{
          'language': languageCode,
          'service': serviceCode,
          'phone': raw,
        },
      );
      final code = res.statusCode ?? 0;
      final data = res.data;
      if (data == null) {
        debugPrint('START_AGENT_FAILURE: null response data (HTTP $code)');
        if (mounted) {
          _onStartAgentFailed(removePending: true, message: 'Bad request');
        }
        return;
      }

      final parsed = StartAgentResponse.fromJson(data);
      if (code < 200 ||
          code >= 300 ||
          !parsed.success ||
          parsed.requestId.isEmpty) {
        debugPrint(
          'START_AGENT_FAILURE HTTP $code full response body: $data',
        );
        if (mounted) {
          var userMsg = code >= 500 ? 'Server error' : 'Bad request';
          final err = data['error']?.toString().trim();
          if (err != null && err.isNotEmpty) {
            userMsg = err;
          }
          _onStartAgentFailed(removePending: true, message: userMsg);
        }
        return;
      }

      rid = parsed.requestId;
      debugPrint('START_AGENT_SUCCESS requestId=$rid');
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      debugPrint(
        'START_AGENT_FAILURE DioException type=${e.type} '
        'HTTP status=$status\n'
        'response body: $body\n'
        'message: ${e.message}\n'
        'stack: $st',
      );
      if (mounted) {
        _onStartAgentFailed(
          removePending: true,
          message: _userMessageForStartAgentDio(e),
        );
      }
      return;
    } catch (e, st) {
      debugPrint('START_AGENT_FAILURE: $e\nstack: $st');
      if (mounted) {
        _onStartAgentFailed(removePending: true, message: e.toString());
      }
      return;
    }

    if (!mounted) return;
    _removePendingAgentBubble();
    final client = ChatbotClient(baseUrl: normalizedBase);
    setState(() {
      _closedLineShown = false;
      _client = client;
      _requestId = rid;
      _step = _FlowStep.done;
      _agentSubmitting = false;
      _timeline.add(
        _TLocalBot(
          _sortSeq++,
          _flowIsEn
              ? const [
                  'Your request has been received ✅',
                  'You will be connected to a specialist agent now',
                ]
              : const [
                  'تم استلام طلبك ✅',
                  'سيتم تحويلك لموظف مختص الآن',
                ],
          DateTime.now(),
        ),
      );
      _apiMessages = const [];
    });
    _listenPoll(client, rid);
  }

  void _onStartAgentFailed({required bool removePending, String? message}) {
    if (removePending) _removePendingAgentBubble();
    setState(() {
      _agentSubmitting = false;
      _client = null;
      _requestId = null;
      _step = _FlowStep.phone;
      _timeline.add(
        _TLocalBot(
          _sortSeq++,
          [
            message ??
                (_flowIsEn
                    ? 'Something went wrong, please try again.'
                    : 'حدث خطأ، حاول مرة أخرى'),
          ],
          DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _listenPoll(ChatbotClient client, String requestId) {
    _pollSub = client.pollMessages(requestId).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _apiMessages = list;
          _timeline.removeWhere((e) => e is _TApi);
          for (final m in list) {
            if (_senderKind(m.sender) == _SenderKind.customer) {
              final body = m.message.trim();
              _timeline.removeWhere((e) {
                if (e is! _TLocalUser) return false;
                return e.optimistic && e.text.trim() == body;
              });
            }
            _timeline.add(_TApi(_sortSeq++, m));
          }
          _lastError = null;
        });
        _scrollToBottom();
      },
      onError: (e, _) {
        if (!mounted) return;
        setState(() {
          _lastError = e is ChatbotException ? e.message : e.toString();
        });
      },
      onDone: () {
        if (!mounted) return;
        unawaited(_pollSub?.cancel());
        _pollSub = null;
        setState(() {
          _appendClosedLineOnce();
          _showRating = true;
        });
        _scrollToBottom();
      },
    );
  }

  void _submitComposer() {
    if (_step == _FlowStep.phone) {
      unawaited(_submitPhone());
      return;
    }
    if (_step != _FlowStep.done || _requestId == null) return;
    final raw = _composerCtrl.text.trim();
    if (raw.isEmpty) {
      _composerFocus.requestFocus();
      return;
    }
    const endKeys = ['/end', 'end', 'انهاء', 'إنهاء'];
    final lower = raw.toLowerCase();
    if (endKeys.any((k) => lower == k.toLowerCase())) {
      unawaited(_forceEndFromComposer());
      return;
    }
    unawaited(_send());
  }

  Future<void> _forceEndFromComposer() async {
    final client = _client;
    final rid = _requestId;
    if (client == null || rid == null) return;
    _composerCtrl.clear();
    try {
      await client.closeChat(rid);
    } catch (_) {}
    if (!mounted) return;
    unawaited(_pollSub?.cancel());
    _pollSub = null;
    setState(() {
      _appendClosedLineOnce();
      _showRating = true;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final client = _client;
    final rid = _requestId;
    final text = _composerCtrl.text.trim();
    if (client == null || rid == null || text.isEmpty || _sending) return;
    setState(() {
      _lastError = null;
      _appendLocalUser(text, optimistic: true);
      _composerCtrl.clear();
    });
    setState(() => _sending = true);
    try {
      await client.sendMessage(rid, text);
    } on ChatbotException catch (e) {
      setState(() => _lastError = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close() async {
    final client = _client;
    final rid = _requestId;
    if (client == null || rid == null || _closing) return;
    setState(() {
      _lastError = null;
      _closing = true;
    });
    try {
      await client.closeChat(rid);
      if (!mounted) return;
      unawaited(_pollSub?.cancel());
      _pollSub = null;
      setState(() {
        _closing = false;
        _appendClosedLineOnce();
        _showRating = true;
      });
      _scrollToBottom();
    } on ChatbotException catch (e) {
      if (mounted) setState(() => _lastError = e.message);
    } finally {
      if (mounted && _closing) setState(() => _closing = false);
    }
  }

  Future<void> _submitRating(String rating) async {
    final client = _client;
    final rid = _requestId;
    if (client == null || rid == null || _ratingBusy) return;
    setState(() => _ratingBusy = true);
    try {
      await client.rateChat(rid, rating);
      if (!mounted) return;
      _afterRating();
    } on ChatbotException catch (e) {
      if (mounted) setState(() => _lastError = e.message);
    } finally {
      if (mounted) setState(() => _ratingBusy = false);
    }
  }

  void _afterRating() {
    unawaited(_pollSub?.cancel());
    _pollSub = null;
    setState(() {
      _appendThanksLine();
      _client = null;
      _requestId = null;
      _apiMessages = const [];
      _lastError = null;
      _showRating = false;
      _sending = false;
      _closing = false;
      _closedLineShown = false;
      _flowStarted = false;
      _panelScreen = _PanelScreen.home;
      _homeShell = _HomeShell.main;
    });
  }

  String _agentSenderLabel() => _flowIsEn ? 'Malak' : 'Ez insurance';

  String _systemLabel() => _flowIsEn ? 'Notice' : 'تنبيه';

  String _helloLine() => _homeUsesEn ? 'Hello 👋' : 'أهلاً بك 👋';

  String _supportCardTitle() =>
      _homeUsesEn ? 'Customer service' : 'خدمة العملاء';

  String _supportRowTitle() =>
      _homeUsesEn ? 'Contact support' : 'التواصل مع الدعم';

  String _supportRowSubtitle() =>
      _homeUsesEn ? 'Our team is ready to help' : 'فريقنا جاهز لمساعدتك';

  String _faqTitle() => _homeUsesEn ? 'FAQ' : 'الأسئلة الشائعة';

  String _waitMessages() =>
      _flowIsEn ? 'Waiting for messages…' : 'في انتظار الرسائل…';

  String _ratingTitle() => _flowIsEn ? 'Rate your experience' : 'قيّم تجربتك';

  String _composerHint() {
    if (!_composerRowVisible) return '';
    if (_step == _FlowStep.phone) {
      return _flowIsEn ? 'e.g. 0512345678' : 'مثال: 0512345678';
    }
    return _flowIsEn ? 'Type your message..' : 'اكتب رسالتك..';
  }

  String _endChat() => _flowIsEn ? 'End' : 'إنهاء';

  TextDirection _chatDirection() {
    if (_uiLang != null) {
      return _flowIsEn ? TextDirection.ltr : TextDirection.rtl;
    }
    return widget.rtl ? TextDirection.rtl : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildBody(context);
    if (!widget.rtl) return content;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: content,
    );
  }

  Widget _buildBody(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = math.max(media.padding.bottom, 24.0);
    final endInset = math.max(media.padding.right, 24.0);
    final startInset = math.max(media.padding.left, 24.0);
    final narrow = media.size.width <= 520;
    final panelWidth =
        narrow ? (media.size.width - 20).clamp(280.0, _Ez.panelW) : _Ez.panelW;
    final panelHeight = narrow
        ? math.min(
            _Ez.panelH,
            media.size.height - bottomInset - _Ez.fabSize - 24,
          )
        : _Ez.panelH;

    final panelCurve = CurvedAnimation(
      parent: _panelAnim,
      curve: const Cubic(0.34, 1.12, 0.64, 1.0),
    );
    final panelSlide =
        Tween<double>(begin: narrow ? 14.0 : 12.0, end: 0).animate(panelCurve);
    final panelFade = Tween<double>(begin: 0, end: 1).animate(panelCurve);

    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!_panelAnim.isDismissed)
              Positioned.directional(
                textDirection: Directionality.of(context),
                end: endInset,
                start: startInset,
                bottom: bottomInset + _Ez.fabSize + 24,
                child: Opacity(
                  opacity: panelFade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, panelSlide.value),
                    child: Transform.scale(
                      scale: 0.98 + 0.02 * panelFade.value,
                      alignment: narrow
                          ? Alignment.bottomCenter
                          : AlignmentDirectional.bottomEnd
                              .resolve(Directionality.of(context)),
                      child: Align(
                        alignment: narrow
                            ? Alignment.bottomCenter
                            : AlignmentDirectional.bottomEnd,
                        child: SizedBox(
                          width: panelWidth,
                          height: panelHeight,
                          child: _buildChatPanel(context, panelWidth),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.directional(
              textDirection: Directionality.of(context),
              end: endInset,
              bottom: bottomInset,
              child: _FabHover(
                pressed: _panelOpen,
                onTap: () => _setPanelOpen(!_panelOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context, double panelWidth) {
    return Material(
      color: _Ez.page,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Ez.radiusPanel),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Ez.radiusPanel),
          color: _Ez.page,
          boxShadow: const [
            BoxShadow(
              color: _Ez.panelShadow,
              blurRadius: 48,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_Ez.radiusPanel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFcHeader(context),
              Expanded(
                child: _panelScreen == _PanelScreen.home
                    ? _buildHome(context)
                    : Directionality(
                        textDirection: _chatDirection(),
                        child: _buildChatScreen(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Web: taller header + back when `chat` or FAQ sub-screens (`vehicles`/`cancel`/`article`).
  bool get _headerElevated =>
      _panelScreen == _PanelScreen.chat || _homeShell != _HomeShell.main;

  void _headerBackPressed() {
    if (_panelScreen == _PanelScreen.chat) {
      _goHomeFromChat();
    } else {
      setState(() {
        _homeShell = _HomeShell.main;
        _articleFeedback = null;
      });
    }
  }

  Widget _buildFcHeader(BuildContext context) {
    final logoTop = _headerElevated ? 18.0 : 14.0;
    return Container(
      height: _headerElevated ? _Ez.headerHeightChat : _Ez.headerHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Ez.headerGradientA, _Ez.blue2],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x2EFFFFFF),
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_Ez.radiusPanel)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: logoTop,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.28,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      170,
                      MediaQuery.sizeOf(context).width * 0.72,
                    ),
                  ),
                  child: Image.network(
                    _kEzHeaderLogoUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.support_agent_rounded,
                      size: 88,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_headerElevated)
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 16,
              start: 16,
              child: _headerChromeButton(
                onPressed: _headerBackPressed,
                icon: Icons.arrow_back_rounded,
                tooltip: _homeUsesEn ? 'Back' : 'رجوع',
              ),
            ),
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: 16,
            end: 16,
            child: _headerChromeButton(
              onPressed: () => _setPanelOpen(false),
              icon: Icons.close_rounded,
              tooltip: _homeUsesEn ? 'Close' : 'إغلاق',
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: _headerElevated ? 74 : 48,
            child: Column(
              children: [
                Text(
                  _helloLine(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.98),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    shadows: const [
                      Shadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _panelScreen == _PanelScreen.chat
                      ? widget.title
                      : (_homeUsesEn ? "We're here to help" : 'نحن هنا لخدمتك'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: _panelScreen == _PanelScreen.chat ? 0.96 : 0.98,
                    ),
                    fontSize: _panelScreen == _PanelScreen.chat ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    height: _panelScreen == _PanelScreen.chat ? 1.45 : 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChromeButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(_Ez.radiusHeaderBtn),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_Ez.radiusHeaderBtn),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _openArticle(String key, {required _HomeShell parent}) {
    setState(() {
      _articleKey = key;
      _articleParent = parent;
      _homeShell = _HomeShell.article;
      _articleFeedback = null;
    });
  }

  /// Web `fc-subheader` (inner back — not the gradient header).
  Widget _faqScreenSubheader({
    required BuildContext context,
    required String title,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: _homeUsesEn ? 'Back' : 'رجوع',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _Ez.text,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _Ez.text,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  /// Web `fc-option` — white pill row with trailing chevron (RTL-aware).
  Widget _faqOptionTile({
    required String title,
    required VoidCallback onTap,
    bool firstInList = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: firstInList ? 4 : 0),
      child: Material(
        color: _Ez.card,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          hoverColor: const Color(0xFFF4F7FB),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _Ez.border),
              boxShadow: const [
                BoxShadow(
                  color: _Ez.cardShadowSoft,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _Ez.text,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: _Ez.muted.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _kArticleTitles = <String, String>{
    'buy_new': 'شراء وثيقة تأمين جديدة',
    'cancel_medgulf': 'إلغاء وثيقة التأمين - ميدغلف',
    'cancel_salama': 'إلغاء وثيقة التأمين - سلامة',
    'cancel_aseej': 'إلغاء وثيقة التأمين - أسيج',
    'cancel_wataniya': 'إلغاء وثيقة التأمين - الوطنية',
    'cancel_etihad': 'إلغاء وثيقة التأمين - الاتحاد',
  };

  String _articleTitleForKey(String key) =>
      _kArticleTitles[key] ?? _kArticleTitles['buy_new']!;

  Widget _articleStepTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _Ez.text,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _articleParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: _Ez.text,
        ),
      ),
    );
  }

  Widget _articleBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: _Ez.text,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: _Ez.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Fallback when a packaged article image fails to load.
  Widget _articleImagePlaceholder(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Ez.border),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: _Ez.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Web `<img class="article-image" />` — bundled under `assets/faq/` in this package.
  Widget _articlePackagedImage(String assetPath, String semanticLabel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: const Color(0xFFF0F2F7),
            child: Image.asset(
              assetPath,
              package: 'ez_chatbot_sdk',
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) =>
                  _articleImagePlaceholder(semanticLabel),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _articleBodyWidgets(String key) {
    switch (key) {
      case 'buy_new':
        return [
          _articleStepTitle(
            'أولًا: كيف يمكنني إنشاء حساب جديد أو تسجيل الدخول إلى منصة EZ Insurance؟',
          ),
          _articleStepTitle('الخطوة 1: تسجيل الدخول أو إنشاء حساب'),
          _articleParagraph('ابدأ رحلتك معنا بسهولة.'),
          _articleParagraph(
            'اضغط على "تسجيل دخول" في أعلى الصفحة لإنشاء حساب جديد أو الدخول إلى حسابك الحالي.',
          ),
          _articlePackagedImage(
            _EzFaqArticleImages.home,
            'الصفحة الرئيسية - EZ Insurance',
          ),
          _articleStepTitle('الخطوة 2: تسجيل الدخول إلى حسابك'),
          _articleParagraph(
            'إذا كنت تملك حسابًا مسبقًا، قم بإدخال بياناتك لتسجيل الدخول:',
          ),
          _articleBulletList(const [
            'البريد الإلكتروني',
            'كلمة المرور',
          ]),
          _articleParagraph(
            'ثم اضغط على زر "تسجيل دخول" للوصول إلى حسابك والاستفادة من خدمات التأمين الإلكترونية.',
          ),
          _articleParagraph(
            'في حال نسيت كلمة المرور، يمكنك استعادتها بسهولة من خلال الرابط أسفل الحقول.',
          ),
          _articlePackagedImage(
            _EzFaqArticleImages.login,
            'تسجيل الدخول - EZ Insurance',
          ),
          _articleStepTitle('الخطوة 3: إنشاء حساب جديد'),
          _articleParagraph(
            'في حال لا تملك حسابًا على منصة EZ Insurance، يمكنك إنشاء حساب جديد بكل سهولة.',
          ),
          _articleParagraph('قم بتعبئة البيانات التالية:'),
          _articleBulletList(const [
            'رقم الهوية أو الإقامة',
            'البريد الإلكتروني',
            'رقم الجوال',
            'كلمة المرور',
          ]),
          _articleParagraph('بعد الانتهاء، اضغط على "إنشاء حساب" للمتابعة.'),
          _articleParagraph(
            'تأكد من صحة البيانات لتسهيل عملية تسجيل الدخول لاحقًا واستخدام الخدمات الإلكترونية بسلاسة.',
          ),
          _articlePackagedImage(
            _EzFaqArticleImages.register,
            'إنشاء حساب جديد - EZ Insurance',
          ),
          _articleStepTitle('الخطوة 4: تفعيل رقم الجوال'),
          _articleParagraph(
            'لضمان حماية حسابك، سيتم إرسال رمز تحقق مكوّن من 6 أرقام إلى رقم جوالك.',
          ),
          _articleParagraph(
            'قم بإدخال الرمز في الحقول المخصصة ثم اضغط على "تفعيل" لإكمال إنشاء الحساب.',
          ),
          _articleParagraph(
            'لم يصلك الرمز؟ يمكنك طلب رمز جديد بعد انتهاء المؤقت.',
          ),
          _articlePackagedImage(
            _EzFaqArticleImages.otp,
            'تفعيل رقم الجوال (رمز التحقق) - EZ Insurance',
          ),
        ];
      case 'cancel_medgulf':
        return _articleCancelParagraphs(const [
          'شروط الإلغاء تختلف حسب حالة الوثيقة. بشكل عام قد يتطلب الإلغاء عدم وجود مطالبات وتقديم الطلب خلال مدة محددة.',
          'لإلغاء وثيقة ميدغلف، جهّز رقم الوثيقة وبيانات المالك ثم تواصل مع الدعم لإكمال الطلب.',
          'قد يتم احتساب رسوم/استقطاع حسب المدة والاستخدام وفق سياسة الشركة.',
        ]);
      case 'cancel_salama':
        return _articleCancelParagraphs(const [
          'شروط الإلغاء تختلف حسب حالة الوثيقة. بشكل عام قد يتطلب الإلغاء عدم وجود مطالبات وتقديم الطلب خلال مدة محددة.',
          'لإلغاء وثيقة سلامة، يتم التحقق من حالة الوثيقة وعدم وجود مطالبات قبل اعتماد الإلغاء.',
          'سيتم تزويدك بالتفاصيل المطلوبة عبر الدعم.',
        ]);
      case 'cancel_aseej':
        return _articleCancelParagraphs(const [
          'شروط الإلغاء تختلف حسب حالة الوثيقة. بشكل عام قد يتطلب الإلغاء عدم وجود مطالبات وتقديم الطلب خلال مدة محددة.',
          'إلغاء وثيقة أسيج يتطلب مطابقة بيانات الوثيقة والمالك والتحقق من الشروط.',
          'تواصل مع الدعم لتقديم الطلب وإرفاق ما يلزم.',
        ]);
      case 'cancel_wataniya':
        return _articleCancelParagraphs(const [
          'شروط الإلغاء تختلف حسب حالة الوثيقة. بشكل عام قد يتطلب الإلغاء عدم وجود مطالبات وتقديم الطلب خلال مدة محددة.',
          'لإلغاء وثيقة الوطنية، قد تحتاج إلى معلومات الوثيقة وسبب الإلغاء.',
          'الدعم سيساعدك في رفع الطلب ومتابعته.',
        ]);
      case 'cancel_etihad':
        return _articleCancelParagraphs(const [
          'شروط الإلغاء تختلف حسب حالة الوثيقة. بشكل عام قد يتطلب الإلغاء عدم وجود مطالبات وتقديم الطلب خلال مدة محددة.',
          'لإلغاء وثيقة الاتحاد، جهّز رقم الوثيقة وبيانات المالك ثم تواصل مع الدعم لإكمال الطلب.',
          'قد يتم احتساب رسوم/استقطاع حسب سياسة الشركة.',
        ]);
      default:
        return [];
    }
  }

  List<Widget> _articleCancelParagraphs(List<String> lines) =>
      lines.map(_articleParagraph).toList();

  /// Web `fc-home` (open-chat → `enterConversation`, no `startAgent` here).
  Widget _buildHome(BuildContext context) {
    switch (_homeShell) {
      case _HomeShell.main:
        return _buildHomeMain(context);
      case _HomeShell.vehicles:
        return _buildHomeVehicles(context);
      case _HomeShell.cancel:
        return _buildHomeCancel(context);
      case _HomeShell.article:
        return _buildHomeArticle(context);
    }
  }

  Widget _buildHomeMain(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _errorBanner(),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Text(
                          _supportCardTitle(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _Ez.text,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _enterChat,
                          hoverColor: const Color(0xFFF7F9FF),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _supportRowTitle(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _Ez.text,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _supportRowSubtitle(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.35,
                                          color: _Ez.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: _Ez.supportIconBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.headset_mic_rounded,
                                    color: _Ez.blue,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _fcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _faqTitle(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _Ez.text,
                                ),
                              ),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.86),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE7EAF2),
                                ),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: _Ez.muted,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _faqRow(
                        context,
                        label: _homeUsesEn ? 'Vehicles' : 'المركبات',
                        preview: _homeUsesEn
                            ? 'Quick answers on vehicle topics'
                            : 'إجابات سريعة لمواضيع المركبات',
                        onTap: () => setState(() => _homeShell = _HomeShell.vehicles),
                      ),
                      _faqRow(
                        context,
                        label: _homeUsesEn
                            ? 'Cancel a policy'
                            : 'إلغاء وثيقة التأمين',
                        preview: _homeUsesEn
                            ? 'Steps and conditions by insurer'
                            : 'خطوات وشروط الإلغاء حسب شركة التأمين',
                        onTap: () => setState(() => _homeShell = _HomeShell.cancel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeVehicles(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorBanner(),
        _faqScreenSubheader(
          context: context,
          title: _homeUsesEn ? 'Vehicles' : 'المركبات',
          onBack: () => setState(() => _homeShell = _HomeShell.main),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            children: [
              _faqOptionTile(
                title: _homeUsesEn
                    ? 'Buy a new insurance policy'
                    : 'شراء وثيقة تأمين جديدة',
                firstInList: true,
                onTap: () => _openArticle('buy_new', parent: _HomeShell.vehicles),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeCancel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorBanner(),
        _faqScreenSubheader(
          context: context,
          title: _homeUsesEn
              ? 'Cancel an insurance policy'
              : 'إلغاء وثيقة التأمين',
          onBack: () => setState(() => _homeShell = _HomeShell.main),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            children: [
              _faqOptionTile(
                title: _homeUsesEn
                    ? 'Cancel Medgulf policy'
                    : 'إلغاء وثيقة ميدغلف',
                firstInList: true,
                onTap: () =>
                    _openArticle('cancel_medgulf', parent: _HomeShell.cancel),
              ),
              _faqOptionTile(
                title: _homeUsesEn
                    ? 'Cancel Salama policy'
                    : 'إلغاء وثيقة سلامة',
                onTap: () =>
                    _openArticle('cancel_salama', parent: _HomeShell.cancel),
              ),
              _faqOptionTile(
                title:
                    _homeUsesEn ? 'Cancel Aseej policy' : 'إلغاء وثيقة أسيج',
                onTap: () =>
                    _openArticle('cancel_aseej', parent: _HomeShell.cancel),
              ),
              _faqOptionTile(
                title: _homeUsesEn
                    ? 'Cancel Wataniya policy'
                    : 'إلغاء وثيقة الوطنية',
                onTap: () =>
                    _openArticle('cancel_wataniya', parent: _HomeShell.cancel),
              ),
              _faqOptionTile(
                title: _homeUsesEn
                    ? 'Cancel Etihad policy'
                    : 'إلغاء وثيقة الاتحاد',
                onTap: () =>
                    _openArticle('cancel_etihad', parent: _HomeShell.cancel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeArticle(BuildContext context) {
    final title = _articleTitleForKey(_articleKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorBanner(),
        _faqScreenSubheader(
          context: context,
          title: title,
          onBack: () {
            setState(() {
              _homeShell = _articleParent;
              _articleFeedback = null;
            });
          },
        ),
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              scrollbarTheme: const ScrollbarThemeData(
                thumbVisibility: WidgetStatePropertyAll(true),
                thickness: WidgetStatePropertyAll(5),
                radius: Radius.circular(5),
                thumbColor: WidgetStatePropertyAll(Color(0x24122E4E)),
              ),
            ),
            child: Scrollbar(
              controller: _faqArticleScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _faqArticleScroll,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: _fcCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._articleBodyWidgets(_articleKey),
                        const Divider(height: 28, color: _Ez.border),
                        Text(
                          _homeUsesEn
                              ? 'Was this article helpful?'
                              : 'هل كانت هذه المقالة مفيدة؟',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _Ez.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _feedbackThumb(
                              selected: _articleFeedback == 1,
                              emoji: '👍',
                              tooltip: _homeUsesEn ? 'Helpful' : 'مفيدة',
                              onTap: () =>
                                  setState(() => _articleFeedback = 1),
                            ),
                            const SizedBox(width: 10),
                            _feedbackThumb(
                              selected: _articleFeedback == 0,
                              emoji: '👎',
                              tooltip:
                                  _homeUsesEn ? 'Not helpful' : 'غير مفيدة',
                              onTap: () =>
                                  setState(() => _articleFeedback = 0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackThumb({
    required bool selected,
    required String emoji,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? _Ez.supportIconBg
            : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fcCard({required Widget child, double radius = 24}) {
    return Container(
      decoration: BoxDecoration(
        color: _Ez.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _Ez.border),
        boxShadow: const [
          BoxShadow(
            color: _Ez.cardShadowSoft,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  /// Web `fc-row fc-row--faq` — chevron on visual start; `InkWell` full row.
  Widget _faqRow(
    BuildContext context, {
    required String label,
    required String preview,
    required VoidCallback onTap,
  }) {
    final textBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _Ez.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: _Ez.muted,
            ),
          ),
        ],
      ),
    );
    final chevron = Icon(
      Icons.chevron_left,
      size: 28,
      color: _Ez.muted.withValues(alpha: 0.85),
    );
    final gap = const SizedBox(width: 10);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final rowChildren = rtl
        ? <Widget>[textBlock, gap, chevron]
        : <Widget>[chevron, gap, textBlock];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF4F7FB),
        child: Ink(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _Ez.border)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: rowChildren),
            ),
          ),
        ),
      ),
    );
  }

  /// Web `fc-chat`: messages + `chatbot-buttons` + optional composer.
  Widget _buildChatScreen(BuildContext context) {
    return ColoredBox(
      color: _Ez.card,
      child: Column(
        children: [
          _errorBanner(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bubbleW = _bubbleMaxWidth(constraints.maxWidth);
                return Theme(
                  data: Theme.of(context).copyWith(
                    scrollbarTheme: const ScrollbarThemeData(
                      thumbVisibility: WidgetStatePropertyAll(true),
                      thickness: WidgetStatePropertyAll(5),
                      radius: Radius.circular(5),
                      thumbColor: WidgetStatePropertyAll(Color(0x24122E4E)),
                    ),
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 5,
                    radius: const Radius.circular(5),
                    child: ColoredBox(
                      color: _Ez.page,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                        children: [
                          for (final e in _timeline)
                            _fadeInMessageTile(context, e, bubbleW),
                          if (_requestId != null &&
                              _apiMessages.isEmpty &&
                              _step == _FlowStep.done &&
                              !_showRating)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 24, bottom: 8),
                              child: Center(
                                child: Text(
                                  _waitMessages(),
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: _Ez.muted, fontSize: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_langButtons.isNotEmpty || _serviceButtons.isNotEmpty)
            _buildActionButtons(),
          if (_showRating) _buildRatingBlock(),
          if (_composerRowVisible) _buildComposer(context),
        ],
      ),
    );
  }

  /// Web `.chatbot-btn` stack (`.chatbot-buttons`).
  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: _Ez.page,
        border: Border(top: BorderSide(color: _Ez.actionBarTopBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in _langButtons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _chatbotPillButton(
                  label: b.label, onTap: () => _onLanguagePicked(b)),
            ),
          for (final s in _serviceButtons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _chatbotPillButton(
                  label: s.label, onTap: () => _onServicePicked(s)),
            ),
        ],
      ),
    );
  }

  Widget _chatbotPillButton(
      {required String label, required VoidCallback onTap}) {
    return Material(
      color: _Ez.blue,
      elevation: 0,
      shadowColor: const Color(0x386F94C2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(111, 148, 194, 0.22),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fadeInMessageTile(BuildContext context, _TEntry e, double bubbleW) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _timelineTile(context, e, bubbleW);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(e.sortKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: _timelineTile(context, e, bubbleW),
    );
  }

  Widget _timelineTile(
      BuildContext context, _TEntry e, double bubbleMaxWidth) {
    final td = Directionality.of(context);
    return switch (e) {
      _TLocalUser u => _localUserBubble(td, u.text, bubbleMaxWidth, u.at),
      _TLocalBot b => _localBotBubble(td, b, bubbleMaxWidth),
      _TApi a => _messageGroup(td, a.message, bubbleMaxWidth),
    };
  }

  /// Web `#insurance-chatbot`: customer visually toward screen edge; text `text-align:left` in CSS.
  Widget _localUserBubble(
      TextDirection td, String text, double bubbleMaxWidth, DateTime at) {
    final time = _formatWallClock(at);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: _userBubbleAlignment(td),
        child: Column(
          crossAxisAlignment: _userBubbleCross(td),
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _Ez.blue,
                  borderRadius: BorderRadius.circular(_Ez.radiusBubble),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(111, 148, 194, 0.22),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 14, height: 1.6, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Ez.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localBotBubble(TextDirection td, _TLocalBot b, double bubbleMaxWidth) {
    final time = _formatWallClock(b.at);
    final body = b.lines.where((s) => s.isNotEmpty).join('\n');
    if (b.subtle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: _Ez.muted.withValues(alpha: 0.92),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: _botBubbleAlignment(td),
        child: Column(
          crossAxisAlignment: _botBubbleCross(td),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _agentSenderLabel(),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _Ez.muted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _Ez.botBubble,
                  borderRadius: BorderRadius.circular(_Ez.radiusBubble),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(18, 46, 78, 0.06),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: b.pending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                body,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.6, color: _Ez.text),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _Ez.blue),
                            ),
                          ],
                        )
                      : Text(
                          body,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 14, height: 1.6, color: _Ez.text),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Ez.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(_Ez.radiusRating),
        border: Border.all(color: const Color(0x244E86D9)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x141F2D3D), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ratingTitle(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _Ez.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ratingBtn(
                child: const Text('👍', style: TextStyle(fontSize: 20)),
                label: 'up',
                tooltip: _flowIsEn ? 'Helpful' : 'مفيد',
              ),
              const SizedBox(width: 10),
              _ratingBtn(
                child: const Text('👎', style: TextStyle(fontSize: 20)),
                label: 'down',
                tooltip: _flowIsEn ? 'Not helpful' : 'غير مفيد',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingBtn({
    required Widget child,
    required String label,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_Ez.radiusRatingBtn),
        child: InkWell(
          onTap: _ratingBusy ? null : () => _submitRating(label),
          borderRadius: BorderRadius.circular(_Ez.radiusRatingBtn),
          hoverColor: const Color(0x0F4E86D9),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_Ez.radiusRatingBtn),
              border: Border.all(color: const Color(0x2E4E86D9)),
            ),
            child: _ratingBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _Ez.blue),
                  )
                : child,
          ),
        ),
      ),
    );
  }

  Widget _messageGroup(
      TextDirection td, ChatMessage m, double bubbleMaxWidth) {
    final kind = _senderKind(m.sender);
    final time = _formatMessageTime(m.createdAt);

    if (kind == _SenderKind.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _systemLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _Ez.muted.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _Ez.botBubble.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(_Ez.radiusBubble),
                    border: Border.all(color: _Ez.border),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08122E4E),
                          blurRadius: 2,
                          offset: Offset(0, 1)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      m.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, height: 1.6, color: _Ez.text),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _Ez.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCustomer = kind == _SenderKind.customer;
    final align = isCustomer
        ? _userBubbleAlignment(td)
        : _botBubbleAlignment(td);
    final cross =
        isCustomer ? _userBubbleCross(td) : _botBubbleCross(td);
    final bubbleColor = isCustomer ? _Ez.blue : _Ez.botBubble;
    final fg = isCustomer ? Colors.white : _Ez.text;
    final ta = isCustomer ? TextAlign.left : TextAlign.right;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: align,
        child: Column(
          crossAxisAlignment: cross,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCustomer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _agentSenderLabel(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _Ez.muted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(_Ez.radiusBubble),
                  boxShadow: [
                    BoxShadow(
                      color: isCustomer
                          ? const Color.fromRGBO(111, 148, 194, 0.22)
                          : const Color.fromRGBO(18, 46, 78, 0.06),
                      blurRadius: isCustomer ? 10 : 2,
                      offset: Offset(0, isCustomer ? 2 : 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    m.message,
                    textAlign: ta,
                    style: TextStyle(fontSize: 14, height: 1.6, color: fg),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                time,
                textAlign: isCustomer ? TextAlign.left : TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _Ez.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: _Ez.card,
        border: Border(top: BorderSide(color: _Ez.composerTopBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _composerInput()),
          const SizedBox(width: _Ez.composerGap),
          _composerEndButton(),
          const SizedBox(width: _Ez.composerGap),
          _composerSendButton(),
        ],
      ),
    );
  }

  Widget _composerEndButton() {
    final enabled = _closeEnabled;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? _close : null,
        borderRadius: BorderRadius.circular(999),
        hoverColor: const Color(0x144E86D9),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x404E86D9)),
            ),
            child: _closing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _Ez.blue),
                  )
                : Text(
                    _endChat(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _Ez.text,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _composerInput() {
    const radius = Radius.circular(22);
    final phoneMode = _step == _FlowStep.phone;
    final textMode = _step == _FlowStep.done && _requestId != null;
    final submitting = _step == _FlowStep.submitting;
    final enabled = _composerRowVisible &&
        !_showRating &&
        !_closing &&
        !submitting &&
        (phoneMode ? true : (textMode && !_sending));

    return TextField(
      controller: _composerCtrl,
      focusNode: _composerFocus,
      enabled: enabled,
      keyboardType: phoneMode ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(fontSize: 14, color: _Ez.text),
      decoration: InputDecoration(
        hintText: _composerHint(),
        hintStyle: const TextStyle(color: _Ez.muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(radius),
          borderSide: const BorderSide(color: _Ez.inputBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(radius),
          borderSide: BorderSide(color: _Ez.blue, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(radius),
          borderSide: const BorderSide(color: _Ez.inputBorder),
        ),
      ),
      minLines: 1,
      maxLines: phoneMode ? 1 : 4,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _submitComposer(),
    );
  }

  Widget _composerSendButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _composerCtrl,
      builder: (context, value, _) {
        final raw = value.text.trim();
        final phoneMode = _step == _FlowStep.phone;
        final textMode = _step == _FlowStep.done && _requestId != null;

        final submitting = _step == _FlowStep.submitting;
        final canPhone = phoneMode &&
            _composerRowVisible &&
            !_showRating &&
            !_closing &&
            !submitting &&
            !_agentSubmitting &&
            raw.isNotEmpty;
        final canText = textMode &&
            _composerRowVisible &&
            !_showRating &&
            !_sending &&
            !_closing &&
            raw.isNotEmpty;

        final can = canPhone || canText;
        final busy =
            submitting ? _agentSubmitting : (phoneMode ? _agentSubmitting : _sending);

        return Material(
          color: can ? _Ez.blue : _Ez.blue.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: can ? _submitComposer : null,
            child: SizedBox(
              width: 48,
              height: 48,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
            ),
          ),
        );
      },
    );
  }

  Widget _errorBanner() {
    if (_lastError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: Colors.red.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lastError.toString(),
                  style: TextStyle(
                      color: Colors.red.shade900, fontSize: 12, height: 1.35),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _lastError = null),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web `#insurance-chatbot .chatbot-toggle` hover / pressed affordances.
class _FabHover extends StatefulWidget {
  const _FabHover({required this.pressed, required this.onTap});

  final bool pressed;
  final VoidCallback onTap;

  @override
  State<_FabHover> createState() => _FabHoverState();
}

class _FabHoverState extends State<_FabHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final pressed = widget.pressed;
    final hovered = _hover && !pressed;
    final lift = hovered ? -2.0 : 0.0;
    final scale = hovered ? 1.04 : (pressed ? 0.98 : 1.0);
    final bg = pressed || hovered ? _Ez.blue2 : _Ez.blue;
    final shadow = pressed
        ? const BoxShadow(
            color: _Ez.toggleShadow, blurRadius: 20, offset: Offset(0, 8))
        : BoxShadow(
            color: hovered ? _Ez.toggleShadowHover : _Ez.toggleShadow,
            blurRadius: hovered ? 30 : 24,
            offset: Offset(0, hovered ? 12 : 10),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Transform.translate(
              offset: Offset(0, lift),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _Ez.fabSize,
                height: _Ez.fabSize,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  boxShadow: [shadow],
                ),
                child: const Icon(Icons.chat_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
