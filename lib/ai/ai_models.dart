import 'package:flutter/foundation.dart';

/// Confirmed facts sent to the AI. Built by the app from real scan data – the
/// AI never produces these. The VIN is deliberately not part of this model.
@immutable
class DiagnosticContext {
  const DiagnosticContext({
    required this.dataOrigin,
    this.vehicle,
    this.faultCodes = const [],
    this.readings = const [],
    this.unsupported = const [],
    this.milOn,
    this.reportedDtcCount,
    this.protocol,
    this.scanTime,
  });

  /// 'live' (real vehicle) or 'simulated'.
  final String dataOrigin;
  final Map<String, Object?>? vehicle;
  final List<Map<String, Object?>> faultCodes;
  final List<Map<String, Object?>> readings;
  final List<String> unsupported;
  final bool? milOn;
  final int? reportedDtcCount;
  final String? protocol;
  final DateTime? scanTime;

  bool get isSimulated => dataOrigin != 'live';
  bool get hasData => faultCodes.isNotEmpty || readings.isNotEmpty;

  Map<String, Object?> toJson() => {
    'dataOrigin': dataOrigin,
    'vehicle': vehicle,
    'faultCodes': faultCodes,
    'readings': readings,
    'unsupported': unsupported,
    'milOn': milOn,
    'reportedDtcCount': reportedDtcCount,
    'protocol': protocol,
    'scanTime': scanTime?.toIso8601String(),
  };

  factory DiagnosticContext.fromJson(Map<String, dynamic> j) =>
      DiagnosticContext(
        dataOrigin: j['dataOrigin'] as String? ?? 'simulated',
        vehicle: (j['vehicle'] as Map?)?.cast<String, Object?>(),
        faultCodes: (j['faultCodes'] as List? ?? [])
            .whereType<Map>()
            .map((m) => m.cast<String, Object?>())
            .toList(),
        readings: (j['readings'] as List? ?? [])
            .whereType<Map>()
            .map((m) => m.cast<String, Object?>())
            .toList(),
        unsupported: (j['unsupported'] as List? ?? [])
            .whereType<String>()
            .toList(),
        milOn: j['milOn'] as bool?,
        reportedDtcCount: (j['reportedDtcCount'] as num?)?.toInt(),
        protocol: j['protocol'] as String?,
        scanTime: DateTime.tryParse(j['scanTime'] as String? ?? ''),
      );
}

@immutable
class ChatTurn {
  const ChatTurn({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  final String text;
  Map<String, String> toJson() => {'role': role, 'text': text};
}

@immutable
class AiMechanicRequest {
  const AiMechanicRequest({
    required this.question,
    required this.context,
    this.history = const [],
  });
  final String question;
  final DiagnosticContext context;
  final List<ChatTurn> history;

  Map<String, Object?> toJson() => {
    'question': question,
    'context': context.toJson(),
    'history': history.map((h) => h.toJson()).toList(),
  };
}

enum SafetyLevel {
  okToDrive('Likely OK to drive', 'Monitor for changes'),
  driveWithCaution(
    'Drive with caution',
    'Limit driving and get it checked soon',
  ),
  avoidDriving('Avoid driving', 'Drive only if necessary, to a workshop'),
  stopSafely('Stop safely', 'Do not continue driving'),
  unknown('Unknown', 'Not enough information to judge');

  const SafetyLevel(this.label, this.summary);
  final String label;
  final String summary;

  static SafetyLevel parse(Object? v) => SafetyLevel.values.firstWhere(
    (s) => s.name == v,
    orElse: () => SafetyLevel.unknown,
  );
}

@immutable
class PossibleCause {
  const PossibleCause({
    required this.cause,
    required this.likelihood,
    required this.reasoning,
  });
  final String cause;
  final String likelihood; // common | possible | less_likely
  final String reasoning;

  factory PossibleCause.fromJson(Map<String, dynamic> j) => PossibleCause(
    cause: '${j['cause'] ?? ''}',
    likelihood: '${j['likelihood'] ?? 'possible'}',
    reasoning: '${j['reasoning'] ?? ''}',
  );
  Map<String, String> toJson() => {
    'cause': cause,
    'likelihood': likelihood,
    'reasoning': reasoning,
  };
}

@immutable
class NextCheck {
  const NextCheck({required this.step, required this.who, required this.why});
  final String step;
  final String who; // owner | workshop
  final String why;

  factory NextCheck.fromJson(Map<String, dynamic> j) => NextCheck(
    step: '${j['step'] ?? ''}',
    who: '${j['who'] ?? 'workshop'}',
    why: '${j['why'] ?? ''}',
  );
  Map<String, String> toJson() => {'step': step, 'who': who, 'why': why};
}

/// Structured AI answer. Every field is an interpretation, never a confirmed
/// diagnosis; the UI labels it accordingly.
@immutable
class AiMechanicAnswer {
  const AiMechanicAnswer({
    required this.summary,
    required this.possibleCauses,
    required this.nextChecks,
    required this.safetyLevel,
    required this.safetyNotes,
    required this.costOutlook,
    required this.unknowns,
    required this.disclaimer,
    required this.generatedAt,
    this.model,
  });

  final String summary;
  final List<PossibleCause> possibleCauses;
  final List<NextCheck> nextChecks;
  final SafetyLevel safetyLevel;
  final List<String> safetyNotes;
  final String costOutlook;
  final List<String> unknowns;
  final String disclaimer;
  final DateTime generatedAt;
  final String? model;

  static const String standardDisclaimer =
      'AI-generated guidance based on the data shown. It is not a confirmed '
      'mechanical diagnosis. Have a qualified mechanic inspect the vehicle '
      'before replacing parts or if you have any safety concern.';

  factory AiMechanicAnswer.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List? ?? [])
            .whereType<Map>()
            .map((m) => f(Map<String, dynamic>.from(m)))
            .toList();
    List<String> strings(String k) => (j[k] as List? ?? [])
        .map((e) => '$e')
        .where((s) => s.isNotEmpty)
        .toList();
    return AiMechanicAnswer(
      summary: '${j['summary'] ?? ''}',
      possibleCauses: list('possibleCauses', PossibleCause.fromJson),
      nextChecks: list('nextChecks', NextCheck.fromJson),
      safetyLevel: SafetyLevel.parse(j['safetyLevel']),
      safetyNotes: strings('safetyNotes'),
      costOutlook: '${j['costOutlook'] ?? ''}',
      unknowns: strings('unknowns'),
      disclaimer: (j['disclaimer'] as String?)?.isNotEmpty == true
          ? j['disclaimer'] as String
          : standardDisclaimer,
      generatedAt:
          DateTime.tryParse(j['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      model: j['model'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'summary': summary,
    'possibleCauses': possibleCauses.map((c) => c.toJson()).toList(),
    'nextChecks': nextChecks.map((c) => c.toJson()).toList(),
    'safetyLevel': safetyLevel.name,
    'safetyNotes': safetyNotes,
    'costOutlook': costOutlook,
    'unknowns': unknowns,
    'disclaimer': disclaimer,
    'generatedAt': generatedAt.toIso8601String(),
    'model': model,
  };
}
