import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../connect/connect_screen.dart';
import 'common.dart';

/// Always-visible connection indicator; tapping opens the connect screen.
class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key});

  static Color colorFor(ConnectionController c) => switch (c.phase) {
    ConnectionPhase.ready =>
      c.isSimulated ? BrandColors.yellow : BrandColors.success,
    ConnectionPhase.noVehicle => BrandColors.caution,
    ConnectionPhase.failed => BrandColors.danger,
    ConnectionPhase.idle => BrandColors.faint,
    _ => BrandColors.info,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    final color = colorFor(c);
    final label = switch (c.phase) {
      ConnectionPhase.ready => c.isSimulated ? 'Demo' : 'Connected',
      ConnectionPhase.noVehicle => 'No vehicle',
      ConnectionPhase.failed => 'Retry',
      ConnectionPhase.idle => 'Connect',
      _ => 'Connecting',
    };
    return Semantics(
      button: true,
      label: 'Scanner connection: ${c.statusLabel}',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ConnectScreen.open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: BrandColors.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(
                color: color,
                pulse: c.isBusy || (c.isReady && !c.isSimulated),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
