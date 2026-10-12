import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_repository.dart';
import '../ai/ai_mechanic_screen.dart';
import '../connect/connect_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../faults/faults_screen.dart';
import '../garage/garage_screen.dart';

/// Lets nested screens switch tabs (e.g. "Ask the AI mechanic" from a fault).
class HomeTabs extends InheritedWidget {
  const HomeTabs({super.key, required this.select, required super.child});
  final void Function(int index) select;

  static const dashboard = 0, faults = 1, mechanic = 2, garage = 3;

  static HomeTabs? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabs>();

  @override
  bool updateShouldNotify(HomeTabs old) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsRepository>();
      if (settings.openConnectOnHome && mounted) {
        settings.openConnectOnHome = false;
        ConnectScreen.open(context);
      }
    });
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return HomeTabs(
      select: _select,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            DashboardScreen(),
            FaultsScreen(),
            AiMechanicScreen(),
            GarageScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.warning_amber_outlined),
              selectedIcon: Icon(Icons.warning_amber_rounded),
              label: 'Faults',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI Mechanic',
            ),
            NavigationDestination(
              icon: Icon(Icons.garage_outlined),
              selectedIcon: Icon(Icons.garage),
              label: 'Garage',
            ),
          ],
        ),
      ),
    );
  }
}
