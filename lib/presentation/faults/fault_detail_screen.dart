import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_mechanic_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../dtc/dtc.dart';
import '../../dtc/dtc_database.dart';
import '../../dtc/dtc_guidance.dart';
import '../../dtc/fault_scan_controller.dart';
import '../home/home_shell.dart';
import '../widgets/common.dart';
import 'faults_screen.dart';

class FaultDetailScreen extends StatelessWidget {
  const FaultDetailScreen({super.key, required this.dtc, required this.tabs});
  final DiagnosticTroubleCode dtc;
  final HomeTabs? tabs;

  static Future<void> open(BuildContext context, DiagnosticTroubleCode dtc) {
    final tabs = HomeTabs.of(context);
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaultDetailScreen(dtc: dtc, tabs: tabs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = DtcGuidance.forCode(dtc);
    final color = guidanceColor(g.level);
    final simulated =
        context.watch<FaultScanController>().scannedSimulated == true;

    return Scaffold(
      appBar: AppBar(title: Text(dtc.code)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            if (simulated)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: SimulatedBanner(),
              ),
            Text(
              dtc.code,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: BrandColors.white,
                fontFeatures: AppTheme.tabular,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dtc.description ?? 'Description not available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: dtc.description == null
                    ? BrandColors.muted
                    : BrandColors.white,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(dtc.status.label, color: BrandColors.info),
                Pill(dtc.system.label, color: BrandColors.lightGrey),
                Pill(dtc.definitionType.label, color: BrandColors.lightGrey),
                Pill(g.level.label, color: color),
              ],
            ),
            const SectionTitle('Confirmed from your vehicle'),
            MghCard(
              child: Column(
                children: [
                  _row('Code', dtc.code),
                  _row(
                    'Status',
                    '${dtc.status.label} – ${dtc.status.description}',
                  ),
                  _row('Reported by', dtc.ecuLabel),
                  _row(
                    'System',
                    '${dtc.system.label} – ${dtc.system.description}',
                  ),
                  _row('Area', dtc.subsystem),
                  _row(
                    'Description source',
                    dtc.description != null
                        ? DtcDatabase.sourceLabel
                        : 'Not available locally',
                  ),
                ],
              ),
            ),
            if (dtc.definitionType == DtcDefinitionType.manufacturer) ...[
              const SizedBox(height: 12),
              const InfoNote(
                icon: Icons.factory_outlined,
                color: BrandColors.caution,
                text:
                    'This is a manufacturer-specific code. Its meaning depends on '
                    'the make and model, so the app does not guess a description. '
                    'A dealer or workshop with manufacturer software can look it up.',
              ),
            ],
            const SectionTitle('General guidance'),
            MghCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: color),
                      const SizedBox(width: 8),
                      Text(
                        g.level.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.level.summary,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(g.safetyNote, style: const TextStyle(height: 1.45)),
                  if (g.quickCheck != null) ...[
                    const SizedBox(height: 12),
                    InfoNote(
                      text: 'Quick check: ${g.quickCheck!}',
                      icon: Icons.lightbulb_outline,
                      color: BrandColors.yellow,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Commonly inspected for ${g.family.toLowerCase()} codes:',
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in g.commonAreas) Chip(label: Text(a)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Rule-based general information for this family of codes – '
                    'not a diagnosis of your vehicle.',
                    style: TextStyle(
                      color: BrandColors.faint,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MghCard(
              color: BrandColors.surfaceRaised,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.engineering_outlined,
                    color: BrandColors.yellow,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Further diagnosis required',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DtcGuidance.diagnosisNote,
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                context.read<AiMechanicController>().draft =
                    'What does ${dtc.code} mean for my car, and what should I check first?';
                Navigator.of(context).pop();
                tabs?.select(HomeTabs.mechanic);
              },
              icon: const Icon(Icons.auto_awesome),
              label: Text('Ask the AI Mechanic about ${dtc.code}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(k, style: const TextStyle(color: BrandColors.muted)),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
