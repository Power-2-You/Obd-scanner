import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../dtc/dtc.dart';
import '../../dtc/dtc_guidance.dart';
import '../../dtc/fault_scan_controller.dart';
import '../connect/connect_screen.dart';
import '../report/report_screen.dart';
import '../widgets/common.dart';
import '../widgets/connection_pill.dart';
import 'fault_detail_screen.dart';

Color guidanceColor(GuidanceLevel l) => switch (l) {
  GuidanceLevel.checkSoon => BrandColors.yellow,
  GuidanceLevel.inspectPromptly => BrandColors.caution,
  GuidanceLevel.stopAndInspect => BrandColors.danger,
};

class FaultsScreen extends StatelessWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    final f = context.watch<FaultScanController>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fault codes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const ConnectionPill(),
            ],
          ),
          const SizedBox(height: 16),
          if (f.scannedSimulated == true)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: SimulatedBanner(),
            ),
          _ScanCard(connection: c, faults: f),
          if (f.error != null) ...[
            const SizedBox(height: 12),
            InfoNote(
              text: f.error!,
              icon: Icons.error_outline,
              color: BrandColors.danger,
            ),
          ],
          if (f.hasResult) ..._results(context, f),
          const SizedBox(height: 18),
          const InfoNote(
            icon: Icons.lock_outline,
            text:
                'Clearing codes is not available in this version. Leaving them '
                'stored helps your mechanic diagnose the fault, and clearing '
                'also resets emissions readiness monitors.',
          ),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, FaultScanController f) {
    final stored = f.stored?.codes ?? const <DiagnosticTroubleCode>[];
    final pending = f.pending?.codes ?? const <DiagnosticTroubleCode>[];
    return [
      if (stored.isEmpty && pending.isEmpty)
        const EmptyState(
          icon: Icons.verified_outlined,
          title: 'No trouble codes reported',
          message:
              'The vehicle did not report any stored or pending '
              'emission-related codes.',
        ),
      if (stored.isNotEmpty) ...[
        SectionTitle('Stored codes (${stored.length})'),
        for (final d in stored) _FaultCard(dtc: d),
      ],
      if (pending.isNotEmpty) ...[
        SectionTitle('Pending codes (${pending.length})'),
        const Padding(
          padding: EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            'Detected once but not yet confirmed by the vehicle.',
            style: TextStyle(color: BrandColors.muted, fontSize: 13),
          ),
        ),
        for (final d in pending) _FaultCard(dtc: d),
      ],
      if (f.problems.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final p in f.problems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InfoNote(
              text: p,
              icon: Icons.report_gmailerrorred_outlined,
              color: BrandColors.caution,
            ),
          ),
      ],
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => ReportScreen.openDraft(context),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Create diagnostic report'),
      ),
    ];
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.connection, required this.faults});
  final ConnectionController connection;
  final FaultScanController faults;

  @override
  Widget build(BuildContext context) {
    final f = faults;
    final mil = f.monitor?.milOn;
    final scanned = f.scannedAt;
    final (icon, color, title) = !f.hasResult
        ? (
            Icons.manage_search_rounded,
            BrandColors.yellow,
            'Check for trouble codes',
          )
        : mil == true
        ? (
            Icons.warning_rounded,
            BrandColors.danger,
            'Check-engine light is ON',
          )
        : f.allCodes.isEmpty
        ? (Icons.check_circle_rounded, BrandColors.success, 'All clear')
        : (
            Icons.info_rounded,
            BrandColors.caution,
            '${f.allCodes.length} code(s) found',
          );

    return MghCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      scanned == null
                          ? 'Reads stored and pending codes from your vehicle.'
                          : 'Last scan ${DateFormat('h:mm a, d MMM').format(scanned)}'
                                '${mil == null ? '' : ' · light ${mil ? 'ON' : 'OFF'}'}',
                      style: const TextStyle(
                        color: BrandColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (connection.isReady)
            FilledButton.icon(
              onPressed: f.scanning ? null : f.scan,
              icon: f.scanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: BrandColors.faint,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                f.scanning
                    ? 'Reading codes…'
                    : (f.hasResult ? 'Scan again' : 'Scan for codes'),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => ConnectScreen.open(context),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect your IQ to scan'),
            ),
        ],
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.dtc});
  final DiagnosticTroubleCode dtc;

  @override
  Widget build(BuildContext context) {
    final g = DtcGuidance.forCode(dtc);
    final color = guidanceColor(g.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MghCard(
        padding: EdgeInsets.zero,
        onTap: () => FaultDetailScreen.open(context, dtc),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dtc.code,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              fontFeatures: AppTheme.tabular,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Pill(g.level.label, color: color),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: BrandColors.faint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dtc.description ??
                            (dtc.definitionType ==
                                    DtcDefinitionType.manufacturer
                                ? 'Manufacturer-specific code – description depends on the make.'
                                : 'Description not in the local database.'),
                        style: TextStyle(
                          height: 1.35,
                          color: dtc.description == null
                              ? BrandColors.muted
                              : BrandColors.lightGrey,
                          fontStyle: dtc.description == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${dtc.system.label} · ${dtc.definitionType.label} · ${dtc.ecuLabel}',
                        style: const TextStyle(
                          color: BrandColors.faint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
