import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../history/diagnostic_report.dart';
import '../../history/history_repository.dart';
import '../../vehicle/vehicle.dart';
import '../../vehicle/vehicle_repository.dart';
import '../report/report_screen.dart';
import '../widgets/common.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_editor_screen.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<VehicleRepository>();
    final history = context.watch<HistoryRepository>();
    final active = repo.active;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Garage',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filled(
                tooltip: 'Add vehicle',
                onPressed: () => VehicleEditorScreen.open(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your vehicles and diagnostic history, stored on this phone.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 16),
          if (repo.vehicles.isEmpty)
            EmptyState(
              icon: Icons.directions_car_filled_outlined,
              title: 'Add your first vehicle',
              message:
                  'Save make, model and engine so reports and AI answers '
                  'are about your car.',
              action: FilledButton.icon(
                onPressed: () => VehicleEditorScreen.open(context),
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            ),
          for (final v in repo.vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VehicleCard(
                vehicle: v,
                active: v.id == active?.id,
                reports: history.forVehicle(v.id).length,
              ),
            ),
          if (history.reports.isNotEmpty) ...[
            SectionTitle('Recent reports (${history.reports.length})'),
            for (final r in history.reports.take(20)) ReportTile(report: r),
          ],
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.active,
    required this.reports,
  });
  final Vehicle vehicle;
  final bool active;
  final int reports;

  @override
  Widget build(BuildContext context) {
    return MghCard(
      highlight: active,
      onTap: () => VehicleDetailScreen.open(context, vehicle.id),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: active ? BrandColors.yellowGradient : null,
              color: active ? null : BrandColors.surfaceHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: active ? BrandColors.charcoal : BrandColors.muted,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (vehicle.subtitle.isNotEmpty)
                  Text(
                    vehicle.subtitle,
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (active) const Pill('Active', color: BrandColors.yellow),
                    Pill(
                      '$reports report${reports == 1 ? '' : 's'}',
                      color: BrandColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: BrandColors.faint),
        ],
      ),
    );
  }
}

class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MghCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => ReportScreen.openSaved(context, r),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: r.codeCount > 0
                  ? BrandColors.caution
                  : BrandColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.vehicleName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('d MMM yyyy, h:mm a').format(r.createdAt)} · '
                    '${r.codeCount == 0 ? 'no codes' : '${r.codeCount} code(s)'}',
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (r.isSimulated)
              const Pill('Simulated', color: BrandColors.yellow),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: BrandColors.faint),
          ],
        ),
      ),
    );
  }
}
