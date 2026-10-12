import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_mechanic_controller.dart';
import '../../ai/ai_models.dart';
import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../dtc/fault_scan_controller.dart';
import '../../history/report_builder.dart';
import '../../obd/live_data_controller.dart';
import '../../vehicle/vehicle_repository.dart';
import '../home/home_shell.dart';
import '../report/report_screen.dart';
import '../widgets/common.dart';

class AiMechanicScreen extends StatefulWidget {
  const AiMechanicScreen({super.key});

  @override
  State<AiMechanicScreen> createState() => _AiMechanicScreenState();
}

class _AiMechanicScreenState extends State<AiMechanicScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  DiagnosticContext _context() {
    final report = ReportBuilder.snapshot(
      connection: context.read<ConnectionController>(),
      faults: context.read<FaultScanController>(),
      live: context.read<LiveDataController>(),
      vehicle: context.read<VehicleRepository>().active,
    );
    return ReportBuilder.contextFor(report);
  }

  Future<void> _ask(String q) async {
    final ai = context.read<AiMechanicController>();
    _input.clear();
    FocusScope.of(context).unfocus();
    final f = ai.ask(q, _context());
    _scrollToEnd();
    await f;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiMechanicController>();
    context.watch<FaultScanController>();
    context.watch<VehicleRepository>();
    final draft = ai.takeDraft();
    if (draft != null) _input.text = draft;
    final ctx = _context();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Mechanic',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (ai.exchanges.isNotEmpty)
                      TextButton(
                        onPressed: ai.clear,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ask about your scan in plain English.',
                  style: TextStyle(color: BrandColors.muted),
                ),
                const SizedBox(height: 16),
                if (!ai.isConfigured) const _NotConfiguredCard(),
                _ContextCard(ctx: ctx),
                const SizedBox(height: 14),
                if (ai.exchanges.isEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final q in AiMechanicController.suggestedQuestions)
                        ActionChip(
                          avatar: const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: BrandColors.yellow,
                          ),
                          label: Text(q),
                          onPressed: ai.busy || !ai.isConfigured
                              ? null
                              : () => _ask(q),
                        ),
                    ],
                  ),
                for (final ex in ai.exchanges) ...[
                  _UserBubble(text: ex.question),
                  if (ex.pending) const _Thinking(),
                  if (ex.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: InfoNote(
                        text: ex.error!,
                        icon: Icons.error_outline,
                        color: BrandColors.danger,
                      ),
                    ),
                  if (ex.answer != null) _AnswerCard(exchange: ex),
                ],
              ],
            ),
          ),
          _InputBar(
            controller: _input,
            enabled: ai.isConfigured && !ai.busy,
            onSend: _ask,
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredCard extends StatelessWidget {
  const _NotConfiguredCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: MghCard(
        highlight: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: BrandColors.yellow),
                SizedBox(width: 10),
                Text(
                  'AI service not connected',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'This build has no AI proxy configured, so questions cannot be '
              'answered yet. Your confirmed scan data and the general guidance '
              'on each fault code remain available.',
              style: TextStyle(color: BrandColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.ctx});
  final DiagnosticContext ctx;

  @override
  Widget build(BuildContext context) {
    final v = ctx.vehicle;
    final vehicleName = v == null
        ? 'No vehicle selected'
        : [
            v['year'],
            v['make'],
            v['model'],
          ].where((e) => e != null && '$e'.isNotEmpty).join(' ');
    return MghCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: BrandColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'What the AI will see',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Pill(
                ctx.isSimulated ? 'Simulated' : 'Live data',
                color: ctx.isSimulated
                    ? BrandColors.yellow
                    : BrandColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            vehicleName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (ctx.faultCodes.isEmpty)
            Text(
              ctx.readings.isEmpty
                  ? 'No scan data yet. Connect and scan for codes so answers are based on your car.'
                  : 'No fault codes scanned yet – answers will use live readings only.',
              style: const TextStyle(color: BrandColors.muted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in ctx.faultCodes)
                  Pill('${c['code']}', color: BrandColors.caution),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            '${ctx.readings.length} live reading(s) · VIN never shared',
            style: const TextStyle(color: BrandColors.faint, fontSize: 12),
          ),
          if (ctx.faultCodes.isEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => HomeTabs.of(context)?.select(HomeTabs.faults),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Go to fault scan'),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12, left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: BrandColors.yellowGradient,
        borderRadius: BorderRadius.circular(18)
            .copyWith(bottomRight: const Radius.circular(6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: BrandColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _Thinking extends StatelessWidget {
  const _Thinking();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: BrandColors.yellow,
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Reviewing your scan data…',
          style: TextStyle(color: BrandColors.muted),
        ),
      ],
    ),
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.exchange});
  final AiExchange exchange;

  @override
  Widget build(BuildContext context) {
    final a = exchange.answer!;
    final ctx = exchange.context;
    final safetyColor = switch (a.safetyLevel) {
      SafetyLevel.okToDrive => BrandColors.success,
      SafetyLevel.driveWithCaution => BrandColors.yellow,
      SafetyLevel.avoidDriving => BrandColors.caution,
      SafetyLevel.stopSafely => BrandColors.danger,
      SafetyLevel.unknown => BrandColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MghCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.summary,
              style: const TextStyle(fontSize: 15.5, height: 1.5),
            ),
            _Section(
              icon: Icons.fact_check_outlined,
              color: BrandColors.success,
              title: 'Confirmed diagnostic data',
              tag: 'From your vehicle',
              children: [
                if (ctx.isSimulated)
                  const Text(
                    'Simulated scan – not from a real vehicle.',
                    style: TextStyle(
                      color: BrandColors.yellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (ctx.milOn != null)
                  _bullet('Check-engine light: ${ctx.milOn! ? 'ON' : 'OFF'}'),
                for (final c in ctx.faultCodes)
                  _bullet(
                    '${c['code']} (${c['status']}) – ${c['description'] ?? 'description not available'}',
                  ),
                if (ctx.faultCodes.isEmpty)
                  _bullet('No fault codes in this scan'),
                for (final r in ctx.readings.take(6))
                  _bullet(
                    '${r['name']}: ${(r['value'] as num).toStringAsFixed(1)} ${r['unit']}',
                  ),
              ],
            ),
            if (a.possibleCauses.isNotEmpty)
              _Section(
                icon: Icons.psychology_alt_outlined,
                color: BrandColors.info,
                title: 'Possible causes',
                tag: 'AI interpretation',
                children: [
                  for (final c in a.possibleCauses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.cause,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Pill(
                                c.likelihood.replaceAll('_', ' '),
                                color: BrandColors.info,
                              ),
                            ],
                          ),
                          if (c.reasoning.isNotEmpty)
                            Text(
                              c.reasoning,
                              style: const TextStyle(
                                color: BrandColors.muted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (a.nextChecks.isNotEmpty)
              _Section(
                icon: Icons.checklist_rounded,
                color: BrandColors.yellow,
                title: 'Suggested next checks',
                tag: 'AI interpretation',
                children: [
                  for (final (i, c) in a.nextChecks.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(
                              color: BrandColors.yellow,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.step,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (c.why.isNotEmpty)
                                  Text(
                                    c.why,
                                    style: const TextStyle(
                                      color: BrandColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Pill(
                            c.who == 'owner' ? 'You' : 'Workshop',
                            color: c.who == 'owner'
                                ? BrandColors.success
                                : BrandColors.muted,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            _Section(
              icon: Icons.health_and_safety_outlined,
              color: safetyColor,
              title: 'Safety considerations',
              tag: a.safetyLevel.label,
              children: [
                for (final n in a.safetyNotes) _bullet(n),
                if (a.safetyNotes.isEmpty) _bullet(a.safetyLevel.summary),
              ],
            ),
            if (a.costOutlook.isNotEmpty)
              _Section(
                icon: Icons.payments_outlined,
                color: BrandColors.muted,
                title: 'Cost outlook',
                tag: 'AI estimate',
                children: [
                  Text(a.costOutlook, style: const TextStyle(height: 1.45)),
                ],
              ),
            if (a.unknowns.isNotEmpty || ctx.unsupported.isNotEmpty)
              _Section(
                icon: Icons.help_outline,
                color: BrandColors.faint,
                title: 'Unknown or unsupported',
                tag: 'Limits of this answer',
                children: [
                  for (final u in a.unknowns) _bullet(u),
                  if (ctx.unsupported.isNotEmpty)
                    _bullet(
                      'Not reported by the vehicle: ${ctx.unsupported.join(', ')}',
                    ),
                ],
              ),
            const Divider(height: 26),
            Text(
              a.disclaimer,
              style: const TextStyle(
                color: BrandColors.faint,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ReportScreen.openDraft(
                  context,
                  aiQuestion: exchange.question,
                  aiAnswer: a,
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Add to report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: BrandColors.faint)),
        Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.tag,
    required this.children,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String tag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Pill(tag, color: color),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: const BoxDecoration(
        color: BrandColors.surface,
        border: Border(top: BorderSide(color: BrandColors.outline, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? onSend : null,
              decoration: InputDecoration(
                counterText: '',
                hintText: enabled
                    ? 'Ask about your car…'
                    : 'AI mechanic unavailable',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: enabled ? () => onSend(controller.text) : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
