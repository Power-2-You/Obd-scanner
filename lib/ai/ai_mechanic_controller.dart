import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/telemetry/diagnostic_log.dart';
import 'ai_mechanic_service.dart';
import 'ai_models.dart';

class AiExchange {
  AiExchange({required this.question, required this.context});
  final String question;
  final DiagnosticContext context;
  final DateTime askedAt = DateTime.now();
  AiMechanicAnswer? answer;
  String? error;
  bool get pending => answer == null && error == null;
}

class AiMechanicController extends ChangeNotifier {
  AiMechanicController({required this.service, required this.log});

  final AiMechanicService service;
  final DiagnosticLog log;
  final List<AiExchange> exchanges = [];
  bool busy = false;

  String? _draft;

  /// Question pre-filled from another screen (e.g. a fault detail).
  String? get draft => _draft;
  set draft(String? value) {
    _draft = value;
    notifyListeners();
  }

  /// Returns and clears the pending draft.
  String? takeDraft() {
    final d = _draft;
    _draft = null;
    return d;
  }

  static const suggestedQuestions = [
    'What does this fault code mean?',
    'What should I check first?',
    'Is it safe to keep driving?',
    'Could this be an expensive repair?',
  ];

  bool get isConfigured => service.isConfigured;

  Future<void> ask(String question, DiagnosticContext context) async {
    final q = question.trim();
    if (q.isEmpty || busy) return;
    final ex = AiExchange(question: q, context: context);
    exchanges.add(ex);
    busy = true;
    notifyListeners();
    final history = <ChatTurn>[
      for (final e
          in exchanges
              .where((e) => e.answer != null)
              .toList()
              .reversed
              .take(3)
              .toList()
              .reversed) ...[
        ChatTurn(role: 'user', text: e.question),
        ChatTurn(role: 'assistant', text: e.answer!.summary),
      ],
    ];
    // Question text is user content – log only its length.
    log.info(
      LogCategory.ai,
      'AI request (${q.length} chars, '
      '${context.faultCodes.length} codes, ${context.dataOrigin})',
    );
    try {
      ex.answer = await service.ask(
        AiMechanicRequest(question: q, context: context, history: history),
      );
      log.info(
        LogCategory.ai,
        'AI answer received (${ex.answer!.safetyLevel.name})',
      );
    } on AiException catch (e) {
      ex.error = e.userMessage;
      log.warn(
        LogCategory.ai,
        'AI request failed: ${e.failure.name} ${e.detail ?? ''}',
      );
    } catch (e) {
      ex.error = 'Something went wrong. Please try again.';
      log.error(LogCategory.ai, 'AI request error: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clear() {
    exchanges.clear();
    notifyListeners();
  }
}
