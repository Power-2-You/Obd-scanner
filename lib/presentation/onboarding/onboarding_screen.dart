import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({bool openConnect = true}) async {
    final settings = context.read<SettingsRepository>();
    // The home shell opens the connect flow once it has been built.
    settings.openConnectOnHome = openConnect;
    await settings.completeOnboarding();
  }

  void _next() {
    if (_page < 2) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandWordmark(),
                    ),
                  ),
                  if (_page < 2)
                    TextButton(
                      onPressed: () => _pages.animateToPage(
                        2,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _IntroPage(),
                  _FeaturesPage(),
                  _BluetoothPage(),
                ],
              ),
            ),
            _Dots(count: 3, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _page < 2
                    ? FilledButton(
                        key: const ValueKey('next'),
                        onPressed: _next,
                        child: const Text('Continue'),
                      )
                    : Column(
                        key: const ValueKey('final'),
                        children: [
                          FilledButton.icon(
                            onPressed: () => _finish(),
                            icon: const Icon(Icons.bluetooth_searching),
                            label: const Text('Connect My IQ'),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _finish(openConnect: false),
                            child: const Text('Explore the app first'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 24),
        const Center(child: IqHeroGraphic(size: 240)),
        const SizedBox(height: 24),
        Text('Your IQ just got smarter.', style: t.headlineMedium),
        const SizedBox(height: 12),
        const Text(
          'The Boost N\' Inflate IQ already jump starts, inflates and lights the '
          'way. Plug its diagnostic cable into your car\'s OBD-II port and this '
          'app turns it into a clear, friendly window into your vehicle\'s health.',
          style: TextStyle(color: BrandColors.muted, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const features = [
      (
        Icons.speed_rounded,
        'Live engine data',
        'RPM, speed, coolant temperature, voltage, load and throttle – when your car reports them.',
      ),
      (
        Icons.warning_amber_rounded,
        'Check-engine codes',
        'Read stored and pending trouble codes with plain-English descriptions.',
      ),
      (
        Icons.auto_awesome_rounded,
        'AI Mechanic',
        'Ask what a code means and what to check first. Clearly separated from confirmed data.',
      ),
      (
        Icons.description_outlined,
        'Shareable reports',
        'Save sessions to your garage and send a tidy report to your mechanic.',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 28),
        Text('Diagnostics, made clear.', style: t.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Everything you need before you visit the workshop.',
          style: TextStyle(color: BrandColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 22),
        for (final (icon, title, body) in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MghCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BrandColors.yellowSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: BrandColors.yellow),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BluetoothPage extends StatelessWidget {
  const _BluetoothPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandColors.yellowSoft,
              border: Border.all(
                color: BrandColors.yellow.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              size: 46,
              color: BrandColors.yellow,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Allow Bluetooth',
          style: t.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'When you tap Connect, iOS will ask permission to use Bluetooth. '
          'The app needs it to find and talk to your IQ.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BrandColors.muted, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 22),
        const MghCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Check(
                'Only reads diagnostic data – it never changes your car\'s settings',
              ),
              _Check(
                'Cannot clear codes, reprogram modules or affect your IQ\'s jump-start, inflate or light functions',
              ),
              _Check('No location tracking. Your VIN stays on your phone'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InfoNote(
          text:
              'Before connecting: plug the IQ\'s OBD cable into the port under '
              'your dashboard and turn the ignition on.',
          icon: Icons.lightbulb_outline,
          color: BrandColors.yellow,
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: BrandColors.success,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == index ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: i == index ? BrandColors.yellow : BrandColors.outline,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
    ],
  );
}
