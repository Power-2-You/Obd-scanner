import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/telemetry/redactor.dart';
import '../../core/theme/app_theme.dart';
import '../../history/history_repository.dart';
import '../../vehicle/vehicle_repository.dart';
import '../widgets/common.dart';
import 'garage_screen.dart';
import 'vehicle_editor_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});
  final String vehicleId;

  static Future<void> open(BuildContext context, String id) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: id)));

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  bool _showVin = false;

  Future<void> _delete() async {
    final repo = context.read<VehicleRepository>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.surfaceRaised,
        title: const Text('Remove vehicle?'),
        content: const Text('Saved reports stay in your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.remove(widget.vehicleId);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<VehicleRepository>();
    final v = repo.byId(widget.vehicleId);
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final reports = context.watch<HistoryRepository>().forVehicle(v.id);
    final isActive = repo.active?.id == v.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(v.displayName),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => VehicleEditorScreen.open(context, vehicle: v),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            MghCard(
              highlight: isActive,
              child: Column(
                children: [
                  _row('Manufacturer', v.make),
                  _row('Model', v.model),
                  _row('Year', v.year?.toString() ?? '—'),
                  _row('Engine', v.engine.isEmpty ? '—' : v.engine),
                  Row(
                    children: [
                      Expanded(
                        child: _row(
                          'VIN',
                          v.vin == null
                              ? 'Not saved'
                              : (_showVin ? v.vin! : Redactor.maskVin(v.vin!)),
                        ),
                      ),
                      if (v.vin != null)
                        IconButton(
                          tooltip: _showVin ? 'Hide VIN' : 'Show VIN',
                          onPressed: () => setState(() => _showVin = !_showVin),
                          icon: Icon(
                            _showVin
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: BrandColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!isActive)
              FilledButton.icon(
                onPressed: () => repo.setActive(v.id),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Use for diagnostics'),
              )
            else
              const InfoNote(
                icon: Icons.check_circle_outline,
                color: BrandColors.success,
                text: 'This vehicle is used for reports and AI mechanic questions.',
              ),
            SectionTitle('Diagnostic history (${reports.length})'),
            if (reports.isEmpty)
              const Text(
                'No saved reports for this vehicle yet.',
                style: TextStyle(color: BrandColors.muted),
              ),
            for (final r in reports) ReportTile(report: r),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(color: BrandColors.muted)),
        ),
        Expanded(
          child: Text(
            val,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ),
      ],
    ),
  );
}
