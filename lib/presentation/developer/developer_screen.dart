import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/telemetry/diagnostic_log.dart';
import '../../core/telemetry/redactor.dart';
import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../device/device_discovery.dart';
import '../../device/discovered_device.dart';
import '../../device/milestone_runner.dart';
import '../../obd/parsing/elm_reply.dart';
import '../../transport/ble/ble_profiles.dart';
import '../../transport/iq/iq_adapter.dart';
import '../connect/connect_screen.dart';
import '../widgets/common.dart';
import '../widgets/connection_pill.dart';
import 'hardware_report.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DeveloperScreen()));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Developer diagnostics'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: ConnectionPill(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: BrandColors.yellow,
            labelColor: BrandColors.yellow,
            unselectedLabelColor: BrandColors.muted,
            tabs: [
              Tab(text: 'Status'),
              Tab(text: 'Milestone'),
              Tab(text: 'Traffic'),
              Tab(text: 'Log'),
              Tab(text: 'Hardware'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StatusTab(),
            _MilestoneTab(),
            _TrafficTab(),
            _LogTab(),
            _HardwareTab(),
          ],
        ),
      ),
    );
  }
}

Widget _kv(String k, String? v, {bool mono = false, VoidCallback? onTap}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: const TextStyle(color: BrandColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: v == null
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: v)),
              onTap: onTap,
              child: Text(
                v ?? '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null,
                  color: v == null ? BrandColors.faint : BrandColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

class _StatusTab extends StatefulWidget {
  const _StatusTab();
  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  bool _revealId = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    context.watch<DiagnosticLog>();
    final d = c.details;
    final s = c.session;
    final ch = c.channel;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (c.isSimulated)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SimulatedBanner(compact: true),
          ),
        const SectionTitle(
          'Connection',
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
        ),
        MghCard(
          child: Column(
            children: [
              _kv('State', '${c.phase.name} – ${c.statusLabel}'),
              _kv('Transport', d?.kind.label),
              _kv('Device name', d?.deviceName),
              _kv(
                'Device identifier',
                d == null
                    ? null
                    : (_revealId
                          ? d.deviceId
                          : '${Redactor.deviceId(d.deviceId)}  (tap to reveal)'),
                mono: true,
                onTap: () => setState(() => _revealId = !_revealId),
              ),
              _kv('Endpoint', d?.endpoint, mono: true),
              if (c.error != null)
                _kv(
                  'Last error',
                  '${c.error!.userMessage}${c.error!.detail == null ? '' : '\n${c.error!.detail}'}',
                ),
            ],
          ),
        ),
        const SectionTitle('Bluetooth profile'),
        MghCard(
          child: Column(
            children: [
              _kv('Matched profile', d?.profileName),
              _kv('Profile source', d?.profileSource),
              _kv('Service UUID', d?.serviceUuid, mono: true),
              _kv('Notify char.', d?.notifyUuid, mono: true),
              _kv('Write char.', d?.writeUuid, mono: true),
              _kv(
                'GATT services',
                d == null
                    ? null
                    : '${d.gattServices.length} discovered (see Hardware tab)',
              ),
            ],
          ),
        ),
        const SectionTitle('Scanner & vehicle'),
        MghCard(
          child: Column(
            children: [
              _kv('ATZ banner', s?.identity?.banner),
              _kv(
                'Interpreter',
                s?.identity == null
                    ? null
                    : '${s!.identity!.family} ${s.identity!.version ?? ''}',
              ),
              _kv(
                'Initialised',
                s == null ? null : (s.isInitialised ? 'Yes' : 'No'),
              ),
              _kv(
                'Init warnings',
                s == null || s.warnings.isEmpty ? null : s.warnings.join('\n'),
              ),
              _kv('Protocol', s?.protocol.label),
              _kv(
                'Supported PIDs',
                s == null || s.supported.pids.isEmpty
                    ? null
                    : (s.supported.pids.toList()..sort())
                          .map(
                            (p) => p
                                .toRadixString(16)
                                .padLeft(2, '0')
                                .toUpperCase(),
                          )
                          .join(' '),
                mono: true,
              ),
              _kv(
                'Commands sent',
                ch == null
                    ? null
                    : '${ch.commandsSent} (${ch.timeouts} timeouts)',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InfoNote(text: 'Long-press any value to copy it.'),
      ],
    );
  }
}

class _MilestoneTab extends StatelessWidget {
  const _MilestoneTab();

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MilestoneRunner>();
    final c = context.watch<ConnectionController>();
    final passedHw =
        m.hardwareVerified &&
        m.steps.every((s) => s.state == ProgressState.done);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Milestone 1 – real scanner connectivity',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 6),
        const Text(
          'Proves the app can retrieve genuine diagnostic data. It only counts '
          'as passed when run against a real IQ plugged into a running vehicle.',
          style: TextStyle(color: BrandColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (!c.isReady)
          OutlinedButton.icon(
            onPressed: () => ConnectScreen.open(context),
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Connect a scanner first'),
          )
        else
          FilledButton.icon(
            onPressed: m.running ? null : m.run,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(m.running ? 'Running…' : 'Run milestone test'),
          ),
        const SizedBox(height: 16),
        MghCard(
          child: Column(
            children: [
              for (final s in m.steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stepIcon(s.state),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.number}. ${s.title}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (s.detail.isNotEmpty)
                              Text(
                                s.detail,
                                style: const TextStyle(
                                  color: BrandColors.muted,
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MghCard(
          highlight: m.rpm != null,
          child: Column(
            children: [
              const Text(
                'DECODED ENGINE RPM',
                style: TextStyle(
                  color: BrandColors.muted,
                  letterSpacing: 1.4,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                m.rpm == null ? '—' : m.rpm!.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              if (m.rpm != null && c.isSimulated)
                const Text(
                  'SIMULATED',
                  style: TextStyle(
                    color: BrandColors.yellow,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoNote(
          text: m.verdict,
          icon: passedHw ? Icons.verified_outlined : Icons.info_outline,
          color: passedHw ? BrandColors.success : BrandColors.yellow,
        ),
      ],
    );
  }

  Widget _stepIcon(ProgressState s) => switch (s) {
    ProgressState.done => const Icon(
      Icons.check_circle_rounded,
      color: BrandColors.success,
      size: 20,
    ),
    ProgressState.failed => const Icon(
      Icons.cancel_rounded,
      color: BrandColors.danger,
      size: 20,
    ),
    ProgressState.running => const SizedBox.square(
      dimension: 20,
      child: Padding(
        padding: EdgeInsets.all(2),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    _ => const Icon(
      Icons.radio_button_unchecked,
      color: BrandColors.faint,
      size: 20,
    ),
  };
}

class _TrafficTab extends StatelessWidget {
  const _TrafficTab();

  @override
  Widget build(BuildContext context) {
    context.watch<DiagnosticLog>();
    final c = context.watch<ConnectionController>();
    final history = (c.channel?.history ?? const []).reversed.toList();
    final tf = DateFormat('HH:mm:ss.SSS');
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_vert_rounded,
        title: 'No traffic yet',
        message:
            'Commands sent to the scanner and its raw responses appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = history[i];
        final ok = e.status == ElmStatus.ok;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '> ${e.command}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: BrandColors.yellow,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${e.elapsed.inMilliseconds} ms · ${tf.format(e.time)}',
                    style: const TextStyle(
                      color: BrandColors.faint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '< ${e.response.isEmpty ? '(nothing)' : e.response}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              const SizedBox(height: 3),
              Text(
                e.error ?? e.status?.name ?? '',
                style: TextStyle(
                  fontSize: 11.5,
                  color: ok ? BrandColors.success : BrandColors.caution,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogTab extends StatefulWidget {
  const _LogTab();
  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  final Set<LogCategory> _filter = {};

  @override
  Widget build(BuildContext context) {
    final log = context.watch<DiagnosticLog>();
    final entries = log.entries
        .where((e) => _filter.isEmpty || _filter.contains(e.category))
        .toList()
        .reversed
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [
              for (final cat in LogCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat.name),
                    selected: _filter.contains(cat),
                    onSelected: (v) => setState(
                      () => v ? _filter.add(cat) : _filter.remove(cat),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text(
                '${entries.length} entries',
                style: const TextStyle(color: BrandColors.muted),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: log.clear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Clear'),
              ),
              Builder(
                builder: (bctx) => TextButton.icon(
                  onPressed: () =>
                      _share(bctx, log.exportText(), 'My Garage Hero IQ log'),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final color = switch (e.level) {
                LogLevel.error => BrandColors.danger,
                LogLevel.warning => BrandColors.caution,
                LogLevel.debug => BrandColors.faint,
                LogLevel.info => BrandColors.lightGrey,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  e.format(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: color,
                    height: 1.3,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _share(BuildContext ctx, String text, String subject) async {
  final box = ctx.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

class _HardwareTab extends StatefulWidget {
  const _HardwareTab();
  @override
  State<_HardwareTab> createState() => _HardwareTabState();
}

class _HardwareTabState extends State<_HardwareTab> {
  bool _inspecting = false;
  String? _message;

  Future<void> _inspect(DiscoveredDevice d) async {
    final c = context.read<ConnectionController>();
    setState(() {
      _inspecting = true;
      _message = null;
    });
    try {
      final services = await c.inspectDevice(d);
      final match = BleProfiles.match(services);
      _message =
          '${d.name}: ${services.length} services. '
          '${match.matched ? 'Matches documented profile ${match.profile!.name}.' : 'No documented OBD profile – nothing was written.'}';
    } catch (e) {
      _message = 'Inspection failed: $e';
    } finally {
      if (mounted) setState(() => _inspecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    final disc = context.watch<DeviceDiscovery>();
    final d = c.details;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MghCard(
          highlight: !IqAdapterSpec.verified,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    IqAdapterSpec.verified
                        ? Icons.verified
                        : Icons.pending_outlined,
                    color: IqAdapterSpec.verified
                        ? BrandColors.success
                        : BrandColors.yellow,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    IqAdapterSpec.verified
                        ? 'IQ adapter verified'
                        : 'IQ adapter NOT verified',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The Boost N\' Inflate IQ\'s radio protocol has not been confirmed. '
                'Search with the IQ powered on, inspect it read-only below, then '
                'share the hardware report so the IQ adapter can be completed.',
                style: TextStyle(color: BrandColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (bctx) => FilledButton.icon(
                  onPressed: () => _share(
                    bctx,
                    HardwareReport.build(c, disc),
                    'IQ hardware report',
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share hardware report'),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(
          'Discovered GATT table${d == null ? '' : ' – ${d.deviceName}'}',
        ),
        if (d == null || d.gattServices.isEmpty)
          const Text(
            'Connect to or inspect a Bluetooth device to see its services.',
            style: TextStyle(color: BrandColors.muted),
          )
        else
          for (final s in d.gattServices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MghCard(
                padding: const EdgeInsets.all(14),
                highlight: BleProfiles.documented.any(
                  (p) => p.serviceUuid == s.uuid,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service ${shortUuid(s.uuid)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final ch in s.characteristics)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 10),
                        child: Text(
                          '↳ ${shortUuid(ch.uuid)}  [${ch.properties.join(', ')}]',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: BrandColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        const SectionTitle('Read-only inspection'),
        const Text(
          'Connects, lists services and disconnects. Never writes to the device.',
          style: TextStyle(color: BrandColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: disc.scanning ? disc.stop : disc.start,
          icon: Icon(disc.scanning ? Icons.stop : Icons.radar),
          label: Text(disc.scanning ? 'Stop scan' : 'Scan all nearby devices'),
        ),
        if (_message != null) ...[
          const SizedBox(height: 10),
          InfoNote(text: _message!, color: BrandColors.yellow),
        ],
        const SizedBox(height: 8),
        for (final dev in disc.devices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(dev.name),
            subtitle: Text(
              '${Redactor.deviceId(dev.id)} · ${dev.rssi ?? '?'} dBm · ${dev.compatibility.label}'
              '${dev.serviceUuids.isEmpty ? '' : '\nadv: ${dev.serviceUuids.map(shortUuid).join(', ')}'}',
              style: const TextStyle(fontSize: 12, color: BrandColors.muted),
            ),
            trailing: TextButton(
              onPressed: _inspecting || c.isBusy ? null : () => _inspect(dev),
              child: const Text('Inspect'),
            ),
          ),
        const SectionTitle('Documented profiles'),
        for (final p in BleProfiles.documented)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MghCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.notes,
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    'Source: ${p.source}',
                    style: const TextStyle(
                      color: BrandColors.faint,
                      fontSize: 11.5,
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
