import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../dtc/fault_scan_controller.dart';
import '../../obd/elm327_session.dart';
import '../../obd/live_data_controller.dart';
import '../../obd/pids.dart';
import '../../vehicle/vehicle_repository.dart';
import '../connect/connect_screen.dart';
import '../developer/developer_screen.dart';
import '../home/home_shell.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/connection_pill.dart';
import '../widgets/gauges.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _autoStartedFor;

  void _maybeAutoStart(ConnectionController c, LiveDataController live) {
    if (c.isReady &&
        !live.polling &&
        c.connectedAt != _autoStartedFor &&
        live.error == null) {
      _autoStartedFor = c.connectedAt;
      WidgetsBinding.instance.addPostFrameCallback((_) => live.start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    final live = context.watch<LiveDataController>();
    final vehicle = context.watch<VehicleRepository>().active;
    _maybeAutoStart(c, live);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandWordmark(size: 0.9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ConnectionPill(),
                  IconButton(
                    tooltip: 'Developer diagnostics',
                    onPressed: () => DeveloperScreen.open(context),
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: BrandColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => HomeTabs.of(context)?.select(HomeTabs.garage),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(color: BrandColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle?.displayName ?? 'Add your vehicle',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: BrandColors.faint,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            sliver: SliverList.list(
              children: c.isReady
                  ? _connectedContent(context, c, live)
                  : [_NotConnected(connection: c)],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  List<Widget> _connectedContent(
    BuildContext context,
    ConnectionController c,
    LiveDataController live,
  ) {
    final faults = context.watch<FaultScanController>();
    double? v(int pid) {
      final r = live.readings[pid];
      return r != null && r.hasValue ? r.value : null;
    }

    String status(int pid) {
      if (live.isUnsupported(pid)) return 'Not supported by vehicle';
      final r = live.readings[pid];
      if (r == null) return live.polling ? 'Reading…' : 'Paused';
      return switch (r.status) {
        ReadingStatus.noData => 'No data',
        ReadingStatus.error => 'Read error',
        ReadingStatus.unsupported => 'Not supported by vehicle',
        ReadingStatus.live => '',
      };
    }

    final rpm = Pids.all[Pids.rpm]!;
    final speed = Pids.all[Pids.speed]!;
    final monitor = live.monitorStatus ?? faults.monitor;
    final dtcCount = monitor?.dtcCount ?? faults.stored?.codes.length;
    final milOn = monitor?.milOn ?? false;

    Widget tile(int pid, IconData icon, {double? warnAbove}) {
      final def = Pids.all[pid]!;
      final value = v(pid);
      return MetricTile(
        icon: icon,
        label: def.shortName,
        unit: def.unit,
        value: value,
        decimals: def.decimals,
        history: live.history[pid],
        statusText: status(pid),
        accent: warnAbove != null && value != null && value >= warnAbove
            ? BrandColors.caution
            : BrandColors.yellow,
      );
    }

    return [
      if (c.isSimulated)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: SimulatedBanner(),
        ),
      MghCard(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 8) / 2;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ArcGauge(
                      label: 'Engine',
                      unit: 'rpm',
                      min: 0,
                      max: rpm.max,
                      value: v(Pids.rpm),
                      size: w.clamp(120, 190),
                      warnAbove: 6000,
                      unavailableText: status(Pids.rpm).isEmpty
                          ? 'Unavailable'
                          : status(Pids.rpm),
                    ),
                    ArcGauge(
                      label: 'Speed',
                      unit: 'km/h',
                      min: 0,
                      max: speed.max,
                      value: v(Pids.speed),
                      size: w.clamp(120, 190),
                      unavailableText: status(Pids.speed).isEmpty
                          ? 'Unavailable'
                          : status(Pids.speed),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            _PollingBar(live: live),
          ],
        ),
      ),
      if (live.error != null) ...[
        const SizedBox(height: 12),
        InfoNote(
          text: live.error!,
          icon: Icons.pause_circle_outline,
          color: BrandColors.caution,
        ),
      ],
      const SectionTitle('Engine & electrical'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          tile(Pids.coolantTemp, Icons.thermostat_rounded, warnAbove: 110),
          tile(Pids.moduleVoltage, Icons.bolt_rounded),
          tile(Pids.engineLoad, Icons.av_timer_rounded),
          tile(Pids.throttle, Icons.tune_rounded),
          MetricTile(
            icon: milOn ? Icons.warning_rounded : Icons.check_circle_outline,
            label: milOn ? 'Codes · light ON' : 'Trouble codes',
            unit: dtcCount == 1 ? 'code' : 'codes',
            value: dtcCount?.toDouble(),
            statusText: 'Tap to scan',
            accent: milOn ? BrandColors.danger : BrandColors.success,
            onTap: () => HomeTabs.of(context)?.select(HomeTabs.faults),
          ),
          MetricTile(
            icon: Icons.battery_charging_full_rounded,
            label: 'Battery at port',
            unit: 'V',
            value: live.adapterVoltage,
            decimals: 1,
            statusText: live.polling ? 'Reading…' : 'Unavailable',
          ),
        ],
      ),
      if (live.activePids.any(Pids.extras.contains)) ...[
        const SectionTitle('More readings'),
        MghCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              for (final pid in live.activePids.where(Pids.extras.contains))
                _ExtraRow(
                  name: Pids.all[pid]!.name,
                  value: v(pid) == null
                      ? (status(pid).isEmpty ? '—' : status(pid))
                      : '${v(pid)!.toStringAsFixed(Pids.all[pid]!.decimals)} ${Pids.all[pid]!.unit}',
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      const InfoNote(
        text:
            'Only values your vehicle reports are shown. Anything it does not '
            'support is marked as unavailable – the app never estimates readings. '
            '"Battery at port" is measured by the scanner itself.',
      ),
    ];
  }
}

class _PollingBar extends StatelessWidget {
  const _PollingBar({required this.live});
  final LiveDataController live;

  @override
  Widget build(BuildContext context) {
    final updated = live.lastUpdate;
    return Row(
      children: [
        IconButton.filled(
          tooltip: live.polling ? 'Pause live data' : 'Resume live data',
          style: IconButton.styleFrom(
            backgroundColor: live.polling
                ? BrandColors.surfaceHigh
                : BrandColors.yellow,
            foregroundColor: live.polling
                ? BrandColors.white
                : BrandColors.charcoal,
          ),
          onPressed: live.toggle,
          icon: Icon(
            live.polling ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            live.polling
                ? 'Live · updated ${updated == null ? '…' : DateFormat('h:mm:ss a').format(updated)}'
                : 'Paused',
            style: const TextStyle(color: BrandColors.muted, fontSize: 12.5),
          ),
        ),
        PopupMenuButton<int>(
          tooltip: 'Update rate',
          initialValue: live.intervalMs,
          onSelected: live.setInterval,
          color: BrandColors.surfaceRaised,
          itemBuilder: (_) => [
            for (final ms in LiveDataController.intervalsMs)
              PopupMenuItem(value: ms, child: Text('Every ${_fmt(ms)}')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BrandColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: BrandColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  _fmt(live.intervalMs),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(int ms) => ms < 1000 ? '${ms / 1000}s' : '${ms ~/ 1000}s';
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.name, required this.value});
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(name, style: const TextStyle(color: BrandColors.muted)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ],
    ),
  );
}

class _NotConnected extends StatelessWidget {
  const _NotConnected({required this.connection});
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    final busy = connection.isBusy;
    return MghCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          IqHeroGraphic(size: 170, animate: busy),
          const SizedBox(height: 10),
          Text(
            busy ? connection.statusLabel : 'Connect your IQ to see live data',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            connection.phase == ConnectionPhase.noVehicle
                ? 'The scanner is connected but the vehicle is not answering. Turn the ignition on.'
                : 'Engine speed, temperatures, voltage and more – straight from your car.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => ConnectScreen.open(context),
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(busy ? 'View progress' : 'Connect My IQ'),
          ),
        ],
      ),
    );
  }
}
