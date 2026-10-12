import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_garage_hero_iq/ai/ai_mechanic_service.dart';
import 'package:my_garage_hero_iq/ai/ai_models.dart';
import 'package:my_garage_hero_iq/app/app.dart';
import 'package:my_garage_hero_iq/app/app_services.dart';
import 'package:my_garage_hero_iq/obd/pids.dart';
import 'package:my_garage_hero_iq/storage/document_store.dart';
import 'package:my_garage_hero_iq/transport/ble/ble_gateway.dart';
import 'package:my_garage_hero_iq/transport/obd_transport.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_vehicle.dart';

class NoRadioGateway implements BleGateway {
  @override
  Future<BleAvailability> availability() async => BleAvailability.unsupported;
  @override
  Stream<BleAvailability> get availabilityChanges => const Stream.empty();
  @override
  Future<void> requestPermissions() async {}
  @override
  Stream<BleScanHit> get scanResults => const Stream.empty();
  @override
  Future<void> startScan({List<String> withServices = const []}) async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = Duration.zero,
  }) async => throw UnsupportedError('no radio');
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Stream<bool> connectionChanges(String deviceId) => const Stream.empty();
  @override
  Future<List<GattServiceInfo>> discoverServices(String deviceId) async =>
      const [];
  @override
  Future<void> subscribe(
    String d,
    String s,
    String c, {
    bool indicate = false,
  }) async {}
  @override
  Stream<Uint8List> values(String d, String c) => const Stream.empty();
  @override
  Future<void> write(
    String d,
    String s,
    String c,
    Uint8List v, {
    bool withoutResponse = false,
  }) async {}
}

class FakeAi implements AiMechanicService {
  AiMechanicRequest? last;
  @override
  bool get isConfigured => true;
  @override
  Future<AiMechanicAnswer> ask(AiMechanicRequest request) async {
    last = request;
    return AiMechanicAnswer(
      summary: 'A cylinder 1 misfire is the main concern.',
      possibleCauses: const [
        PossibleCause(
          cause: 'Worn spark plug',
          likelihood: 'common',
          reasoning: 'Frequent cause.',
        ),
      ],
      nextChecks: const [
        NextCheck(
          step: 'Inspect the cylinder 1 coil',
          who: 'workshop',
          why: 'Swap test',
        ),
      ],
      safetyLevel: SafetyLevel.driveWithCaution,
      safetyNotes: const ['Avoid heavy load.'],
      costOutlook: 'Usually modest if it is a plug or coil.',
      unknowns: const ['Mileage not provided'],
      disclaimer: AiMechanicAnswer.standardDisclaimer,
      generatedAt: DateTime(2026),
    );
  }
}

Future<AppServices> boot(WidgetTester tester, {AiMechanicService? ai}) async {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone-sized
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final services = await AppServices.create(
    store: MemoryDocumentStore(),
    gateway: NoRadioGateway(),
    aiService: ai ?? const UnconfiguredAiMechanicService(),
  );
  await tester.pumpWidget(MghApp(services: services));
  await tester.pump();
  return services;
}

Future<void> settle(WidgetTester tester, {int steps = 20, int ms = 150}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<void> shutdown(WidgetTester tester, AppServices s) async {
  s.live.stop();
  unawaited(s.connection.disconnect());
  await settle(tester, steps: 10);
}

void main() {
  testWidgets('onboarding → demo connect → live RPM on the dashboard', (
    tester,
  ) async {
    final s = await boot(tester);
    expect(find.text('Your IQ just got smarter.'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await settle(tester, steps: 5);
    expect(find.text('Allow Bluetooth'), findsOneWidget);
    await tester.tap(find.text('Connect My IQ'));
    await settle(tester, steps: 8);

    // Connect screen opened from onboarding.
    expect(find.text('Connect your IQ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Try the demo IQ'), 200);
    await tester.tap(find.text('Try the demo IQ'));
    await settle(tester, steps: 5);
    await tester.tap(find.text('Healthy car – short drive'));
    await settle(tester, steps: 30);

    expect(
      s.connection.isReady,
      isTrue,
      reason: s.connection.error?.toString(),
    );
    expect(s.connection.transport!.kind, TransportKind.simulated);
    expect(find.text('Demo scanner connected'), findsOneWidget);

    await tester.ensureVisible(find.text('Done'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settle(tester, steps: 30);

    // Dashboard: simulated banner + live RPM gauge.
    expect(find.textContaining('SIMULATED DATA'), findsWidgets);
    expect(find.text('ENGINE'), findsOneWidget);
    expect(s.live.polling, isTrue);
    expect(s.live.readings[Pids.rpm]?.hasValue, isTrue);
    // No saved device for simulated connections.
    expect(s.settings.savedDevice, isNull);

    await shutdown(tester, s);
  });

  testWidgets('fault scan shows codes, detail screen, and no clear option', (
    tester,
  ) async {
    final s = await boot(tester);
    await s.settings.completeOnboarding();
    await settle(tester, steps: 4);

    unawaited(s.connection.connectSimulated(SimulationScenario.checkEngine));
    await settle(tester, steps: 30);
    expect(s.connection.isReady, isTrue);

    await tester.tap(find.text('Faults'));
    await settle(tester, steps: 4);
    await tester.tap(find.text('Scan for codes'));
    await settle(tester, steps: 30);

    expect(find.text('P0301'), findsOneWidget);
    expect(find.text('Cylinder 1 Misfire Detected'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('PENDING CODES'), 200);
    expect(find.textContaining('PENDING CODES'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('P0301'), -200);
    expect(
      find.textContaining(RegExp('clear codes', caseSensitive: false)),
      findsNothing,
    );

    await tester.tap(find.text('P0301'));
    await settle(tester, steps: 10);
    expect(find.text('CONFIRMED FROM YOUR VEHICLE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Further diagnosis required'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Further diagnosis required'), findsOneWidget);

    await shutdown(tester, s);
  });

  testWidgets('AI mechanic separates confirmed data from AI interpretation', (
    tester,
  ) async {
    final ai = FakeAi();
    final s = await boot(tester, ai: ai);
    await s.settings.completeOnboarding();
    await s.vehicles.add(
      make: 'Toyota',
      model: 'Corolla',
      year: 2015,
      vin: 'MGHDEM00000000009',
    );
    await settle(tester, steps: 4);
    unawaited(s.connection.connectSimulated(SimulationScenario.checkEngine));
    await settle(tester, steps: 30);
    s.live.stop();
    await settle(tester, steps: 10);
    unawaited(s.faults.scan());
    await settle(tester, steps: 20);

    await tester.tap(find.text('AI Mechanic'));
    await settle(tester, steps: 4);
    await tester.tap(find.text('Is it safe to keep driving?'));
    await settle(tester, steps: 10);

    expect(find.text('Confirmed diagnostic data'), findsOneWidget);
    expect(find.text('Possible causes'), findsOneWidget);
    expect(find.text('Safety considerations'), findsOneWidget);
    expect(find.text('AI interpretation'), findsWidgets);
    // The VIN never leaves the phone.
    final payload = ai.last!.toJson().toString();
    expect(payload.contains('MGHDEM00000000009'), isFalse);
    expect(
      ai.last!.context.faultCodes.map((c) => c['code']),
      contains('P0301'),
    );

    await shutdown(tester, s);
  });
}
