import 'package:flutter/foundation.dart';

import '../transport/simulated/simulated_vehicle.dart';
import 'app_services.dart';

/// Screenshot/preview helper for the web preview build ONLY.
///
/// Active only when compiled with `--dart-define=PREVIEW=true` AND running on
/// the web. It reads `?screen=…&scenario=…` from the URL, skips onboarding and
/// connects the clearly-labelled simulated scanner. It is a no-op in every
/// iOS/Android build.
class PreviewHarness {
  const PreviewHarness._();

  static const bool enabled = bool.fromEnvironment('PREVIEW') && kIsWeb;

  static String screen = '';
  static int initialTab = 0;

  static Future<void> apply(AppServices s) async {
    if (!enabled) return;
    final q = Uri.base.queryParameters;
    screen = q['screen'] ?? '';
    if (screen.isEmpty || screen == 'onboarding') return;

    await s.settings.completeOnboarding();
    if (q['vehicle'] != 'none') {
      await s.vehicles.add(
        make: 'Toyota',
        model: 'HiLux SR5',
        year: 2019,
        engine: '2.8L turbo diesel',
        nickname: 'Work ute',
      );
    }
    initialTab = switch (screen) {
      'faults' || 'fault' => 1,
      'ai' => 2,
      'garage' => 3,
      _ => 0,
    };
    if (screen == 'disconnected' || screen == 'connect') return;
    final scenario = SimulationScenario.values.firstWhere(
      (v) => v.name == q['scenario'],
      orElse: () => SimulationScenario.checkEngine,
    );
    await s.connection.connectSimulated(scenario);
    if (screen == 'faults' ||
        screen == 'fault' ||
        screen == 'ai' ||
        screen == 'report') {
      s.live.start();
      await Future<void>.delayed(const Duration(seconds: 3));
      await s.faults.scan();
    }
  }
}
