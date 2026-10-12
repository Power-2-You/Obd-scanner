// On-device end-to-end test (iPhone, iOS Simulator or Android).
//
//   flutter test integration_test/app_test.dart -d <device-id>
//
// Uses the built-in simulated scanner, so no hardware is needed. Real IQ
// verification is done with the in-app Developer › Milestone runner.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_garage_hero_iq/ai/ai_mechanic_service.dart';
import 'package:my_garage_hero_iq/app/app.dart';
import 'package:my_garage_hero_iq/app/app_services.dart';
import 'package:my_garage_hero_iq/obd/pids.dart';
import 'package:my_garage_hero_iq/storage/document_store.dart';
import 'package:my_garage_hero_iq/transport/simulated/simulated_vehicle.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo scanner: connect, live data, fault scan', (tester) async {
    final s = await AppServices.create(
      store: MemoryDocumentStore(),
      aiService: const UnconfiguredAiMechanicService(),
    );
    await s.settings.completeOnboarding();
    await tester.pumpWidget(MghApp(services: s));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 300),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    unawaited(s.connection.connectSimulated(SimulationScenario.checkEngine));
    for (var i = 0; i < 60 && !s.connection.isReady; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(s.connection.isReady, isTrue);

    for (
      var i = 0;
      i < 40 && s.live.readings[Pids.rpm]?.hasValue != true;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(s.live.readings[Pids.rpm]?.hasValue, isTrue);
    expect(find.textContaining('SIMULATED DATA'), findsWidgets);

    s.live.stop();
    await tester.tap(find.text('Faults'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Scan for codes'));
    for (var i = 0; i < 40 && s.faults.scanning; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('P0301'), findsOneWidget);

    await s.connection.disconnect();
    await tester.pump(const Duration(seconds: 1));
  });
}
