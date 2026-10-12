import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/ai_models.dart';
import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../dtc/dtc.dart';
import '../../dtc/dtc_guidance.dart';
import '../../dtc/fault_scan_controller.dart';
import '../../history/diagnostic_report.dart';
import '../../history/history_repository.dart';
import '../../history/report_builder.dart';
import '../../obd/live_data_controller.dart';
import '../../vehicle/vehicle.dart';
import '../../vehicle/vehicle_repository.dart';
import '../faults/faults_screen.dart';
import '../widgets/common.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.report, required this.saved});
  final DiagnosticReport report;
  final bool saved;

  /// Builds a fresh report from the current session.
  static Future<void> openDraft(
    BuildContext context, {
    String? aiQuestion,
    AiMechanicAnswer? aiAnswer,
  }) {
    var r = ReportBuilder.snapshot(
      connection: context.read<ConnectionController>(),
      faults: context.read<FaultScanController>(),
      live: context.read<LiveDataController>(),
      vehicle: context.read<VehicleRepository>().active,
    );
    if (aiAnswer != null) {
      r = r.copyWith(aiQuestion: aiQuestion, aiAnswer: aiAnswer);
    }
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportScreen(report: r, saved: false)),
    );
  }

  static Future<void> openSaved(BuildContext context, DiagnosticReport r) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportScreen(report: r, saved: true)),
      );

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DiagnosticReport _report = widget.report;
  late bool _saved = widget.saved;
  late final _notes = TextEditingController(text: widget.report.notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DiagnosticReport get _current => _report.copyWith(notes: _notes.text.trim());

  Future<void> _save() async {
    final history = context.read<HistoryRepository>();
    final messenger = ScaffoldMessenger.of(context);
    await history.save(_current);
    setState(() => _saved = true);
    messenger.showSnackBar(
      const SnackBar(content: Text('Report saved to your garage')),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final r = _current;
    await SharePlus.instance.share(
      ShareParams(
        text: ReportBuilder.toText(r),
        subject: 'Diagnostic report – ${r.vehicleName}',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _delete() async {
    final history = context.read<HistoryRepository>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.surfaceRaised,
        title: const Text('Delete report?'),
        content: const Text('This removes the report from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await history.remove(_report.id);
      nav.pop();
    }
  }

  void _assignVehicle(Vehicle? v) {
    setState(() {
      _report = DiagnosticReport(
        id: _report.id,
        createdAt: _report.createdAt,
        dataOrigin: _report.dataOrigin,
        scannerName: _report.scannerName,
        scannerFamily: _report.scannerFamily,
        protocol: _report.protocol,
        vehicleId: v?.id,
        vehicle: v?.toJson(includeVin: false),
        storedCodes: _report.storedCodes,
        pendingCodes: _report.pendingCodes,
        milOn: _report.milOn,
        readings: _report.readings,
        aiQuestion: _report.aiQuestion,
        aiAnswer: _report.aiAnswer,
        notes: _notes.text,
      );
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final vehicles = context.watch<VehicleRepository>().vehicles;
    final df = DateFormat('EEEE d MMMM yyyy, h:mm a');
    final steps = ReportBuilder.nextSteps(r);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.saved ? 'Saved report' : 'Diagnostic report'),
        actions: [
          if (widget.saved)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (r.isSimulated)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: SimulatedBanner(),
              ),
            MghCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VEHICLE',
                    style: TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (vehicles.isEmpty)
                    Text(
                      r.vehicleName,
                      style: Theme.of(context).textTheme.titleLarge,
                    )
                  else
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: vehicles.any((v) => v.id == r.vehicleId)
                            ? r.vehicleId
                            : null,
                        dropdownColor: BrandColors.surfaceRaised,
                        hint: const Text('Choose a vehicle'),
                        style: Theme.of(context).textTheme.titleLarge,
                        items: [
                          for (final v in vehicles)
                            DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                v.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) => _assignVehicle(
                          vehicles.firstWhere((v) => v.id == id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    df.format(r.createdAt),
                    style: const TextStyle(color: BrandColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.scannerName}${r.scannerFamily == null ? '' : ' · ${r.scannerFamily}'}',
                    style: const TextStyle(color: BrandColors.muted),
                  ),
                  if (r.protocol != null)
                    Text(
                      r.protocol!,
                      style: const TextStyle(
                        color: BrandColors.faint,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            SectionTitle(
              'Fault codes (${r.codeCount})',
              trailing: r.milOn == null
                  ? null
                  : Pill(
                      'Light ${r.milOn! ? 'ON' : 'OFF'}',
                      color: r.milOn!
                          ? BrandColors.danger
                          : BrandColors.success,
                    ),
            ),
            if (r.codeCount == 0)
              const MghCard(
                child: Text(
                  'No stored or pending codes were reported in this session.',
                ),
              ),
            for (final c in [...r.storedCodes, ...r.pendingCodes])
              _CodeRow(dtc: c),
            const SectionTitle('Sensor readings'),
            MghCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  if (r.readings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No live readings were captured.',
                        style: TextStyle(color: BrandColors.muted),
                      ),
                    ),
                  for (final x in r.readings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              x.name,
                              style: const TextStyle(color: BrandColors.muted),
                            ),
                          ),
                          Text(
                            x.display,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: AppTheme.tabular,
                              color: x.value == null
                                  ? BrandColors.faint
                                  : BrandColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (r.aiAnswer != null) ...[
              const SectionTitle(
                'AI explanation',
                trailing: Pill('Not a diagnosis', color: BrandColors.info),
              ),
              MghCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.aiQuestion != null)
                      Text(
                        '“${r.aiQuestion}”',
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      r.aiAnswer!.summary,
                      style: const TextStyle(height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Safety: ${r.aiAnswer!.safetyLevel.label}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.aiAnswer!.disclaimer,
                      style: const TextStyle(
                        color: BrandColors.faint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SectionTitle('Recommended next steps'),
            MghCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in steps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_right_rounded,
                            color: BrandColors.yellow,
                          ),
                          Expanded(
                            child: Text(s, style: const TextStyle(height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SectionTitle('Notes'),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() => _saved = false),
              decoration: const InputDecoration(
                hintText: 'Symptoms, noises, when it happens…',
              ),
            ),
            const SizedBox(height: 22),
            Builder(
              builder: (bctx) => FilledButton.icon(
                onPressed: () => _share(bctx),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share report'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saved ? null : _save,
              icon: Icon(_saved ? Icons.check_rounded : Icons.save_alt_rounded),
              label: Text(_saved ? 'Saved' : 'Save to garage'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.dtc});
  final DiagnosticTroubleCode dtc;

  @override
  Widget build(BuildContext context) {
    final g = DtcGuidance.forCode(dtc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MghCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                dtc.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dtc.description ?? 'Description not available',
                    style: TextStyle(
                      color: dtc.description == null
                          ? BrandColors.muted
                          : BrandColors.lightGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dtc.status.label} · ${dtc.ecuLabel}',
                    style: const TextStyle(
                      color: BrandColors.faint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Pill(g.level.label, color: guidanceColor(g.level)),
          ],
        ),
      ),
    );
  }
}
