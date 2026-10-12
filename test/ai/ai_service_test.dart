import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_garage_hero_iq/ai/ai_mechanic_service.dart';
import 'package:my_garage_hero_iq/ai/ai_models.dart';
import 'package:my_garage_hero_iq/core/errors/app_exception.dart';

/// Contract test: the JSON below has the exact shape returned by
/// backend/ai_proxy (see backend/ai_proxy/README.md).
const proxyAnswer = {
  'summary': 'A cylinder 1 misfire is the main concern.',
  'possibleCauses': [
    {
      'cause': 'Worn spark plug',
      'likelihood': 'common',
      'reasoning': 'Frequent.',
    },
  ],
  'nextChecks': [
    {'step': 'Check coil', 'who': 'workshop', 'why': 'Swap test'},
  ],
  'safetyLevel': 'avoidDriving',
  'safetyNotes': ['Flashing light means severe misfire.'],
  'costOutlook': 'Usually modest.',
  'unknowns': ['Mileage'],
  'disclaimer': 'AI-generated guidance … not a confirmed mechanical diagnosis.',
  'generatedAt': '2026-10-12T00:00:00.000Z',
  'model': 'claude-opus-5-5',
};

AiMechanicRequest request() => const AiMechanicRequest(
  question: 'Is it safe?',
  context: DiagnosticContext(
    dataOrigin: 'live',
    vehicle: {
      'make': 'Toyota',
      'model': 'Corolla',
      'year': 2015,
      'engine': '1.8L',
    },
    faultCodes: [
      {'code': 'P0301', 'status': 'stored'},
    ],
  ),
);

void main() {
  test('posts to /v1/mechanic and parses the proxy answer', () async {
    late http.Request sent;
    final svc = BackendAiMechanicService(
      baseUrl: 'https://ai.example.com',
      client: MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode(proxyAnswer),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final a = await svc.ask(request());
    expect(sent.url.toString(), 'https://ai.example.com/v1/mechanic');
    expect(sent.headers['content-type'], startsWith('application/json'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['question'], 'Is it safe?');
    expect(body['context']['faultCodes'][0]['code'], 'P0301');
    expect(body.toString().contains('vin'), isFalse);
    expect(a.safetyLevel, SafetyLevel.avoidDriving);
    expect(a.possibleCauses.single.likelihood, 'common');
    expect(a.nextChecks.single.who, 'workshop');
    expect(a.model, 'claude-opus-5-5');
  });

  test('maps 429 and bad payloads to typed errors', () async {
    final limited = BackendAiMechanicService(
      baseUrl: 'https://ai.example.com',
      client: MockClient((_) async => http.Response('{}', 429)),
    );
    await expectLater(
      limited.ask(request()),
      throwsA(
        isA<AiException>().having(
          (e) => e.failure,
          'failure',
          AiFailure.rateLimited,
        ),
      ),
    );
    final garbage = BackendAiMechanicService(
      baseUrl: 'https://ai.example.com',
      client: MockClient((_) async => http.Response('not json', 200)),
    );
    await expectLater(
      garbage.ask(request()),
      throwsA(
        isA<AiException>().having(
          (e) => e.failure,
          'failure',
          AiFailure.invalidResponse,
        ),
      ),
    );
  });

  test('unconfigured service refuses with a clear message', () async {
    const svc = UnconfiguredAiMechanicService();
    expect(svc.isConfigured, isFalse);
    await expectLater(svc.ask(request()), throwsA(isA<AiException>()));
  });

  test('answer JSON round-trips for saved reports', () {
    final a = AiMechanicAnswer.fromJson(proxyAnswer);
    final b = AiMechanicAnswer.fromJson(a.toJson());
    expect(b.summary, a.summary);
    expect(b.safetyLevel, a.safetyLevel);
  });
}
