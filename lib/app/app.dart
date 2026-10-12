import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings/settings_repository.dart';
import '../core/theme/app_theme.dart';
import '../presentation/home/home_shell.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import 'app_services.dart';

class MghApp extends StatelessWidget {
  const MghApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = services;
    return MultiProvider(
      providers: [
        Provider.value(value: s),
        ChangeNotifierProvider.value(value: s.log),
        ChangeNotifierProvider.value(value: s.settings),
        ChangeNotifierProvider.value(value: s.vehicles),
        ChangeNotifierProvider.value(value: s.history),
        ChangeNotifierProvider.value(value: s.discovery),
        ChangeNotifierProvider.value(value: s.connection),
        ChangeNotifierProvider.value(value: s.live),
        ChangeNotifierProvider.value(value: s.faults),
        ChangeNotifierProvider.value(value: s.milestone),
        ChangeNotifierProvider.value(value: s.ai),
      ],
      child: MaterialApp(
        title: 'My Garage Hero IQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Selector<SettingsRepository, bool>(
          selector: (_, s) => s.onboardingComplete,
          builder: (_, done, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: done ? const HomeShell() : const OnboardingScreen(),
          ),
        ),
      ),
    );
  }
}
