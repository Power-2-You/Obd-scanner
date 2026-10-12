import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_repository.dart';
import '../../core/telemetry/redactor.dart';
import '../../core/theme/app_theme.dart';
import '../../device/connection_controller.dart';
import '../../device/device_discovery.dart';
import '../../device/discovered_device.dart';
import '../../transport/ble/ble_gateway.dart';
import '../../transport/obd_transport.dart';
import '../../transport/simulated/simulated_vehicle.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const ConnectScreen(),
    ),
  );

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _showOthers = false;
  final _scroll = ScrollController();
  ConnectionPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<ConnectionController>();
      if (!c.isReady && !c.isBusy) {
        context.read<DeviceDiscovery>().refreshAvailability();
      }
    });
  }

  DeviceDiscovery? _discovery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _discovery = context.read<DeviceDiscovery>();
  }

  @override
  void dispose() {
    _discovery?.stop();
    _scroll.dispose();
    super.dispose();
  }

  /// Bring the progress card into view whenever a connection starts.
  void _followPhase(ConnectionPhase phase) {
    if (phase == _lastPhase) return;
    final started = phase == ConnectionPhase.connecting;
    _lastPhase = phase;
    if (!started) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _connectBle(DiscoveredDevice d) async {
    final discovery = context.read<DeviceDiscovery>();
    final c = context.read<ConnectionController>();
    if (d.compatibility == DeviceCompatibility.unknown) {
      final go = await _confirmUnknown(d);
      if (go != true) return;
    }
    await discovery.stop();
    await c.connectBle(d);
  }

  Future<bool?> _confirmUnknown(DiscoveredDevice d) =>
      showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check this device?',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                '"${d.name}" does not advertise a known OBD scanner profile. '
                'The app will connect and read its list of Bluetooth services, '
                'but it will only send data if that list matches a documented '
                'OBD-II scanner profile.',
                style: const TextStyle(color: BrandColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Check device'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickDemo() async {
    final c = context.read<ConnectionController>();
    final s = await showModalBottomSheet<SimulationScenario>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(
                'Demo scenarios',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                'Simulated data for exploring the app. Every screen will be '
                'clearly marked as simulated.',
                style: TextStyle(color: BrandColors.muted),
              ),
            ),
            for (final sc in SimulationScenario.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MghCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.pop(ctx, sc),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        color: BrandColors.yellow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sc.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sc.description,
                              style: const TextStyle(
                                color: BrandColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: BrandColors.faint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (s != null) await c.connectSimulated(s);
  }

  Future<void> _wifi() async {
    final settings = context.read<SettingsRepository>();
    final c = context.read<ConnectionController>();
    final host = TextEditingController(text: settings.wifiHost);
    final port = TextEditingController(text: '${settings.wifiPort}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wi-Fi scanner', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Only if your scanner creates its own Wi-Fi network. Join that '
              'network in iOS Settings first. 192.168.0.10 : 35000 is a common '
              'ELM327 default – it has not been verified for the IQ.',
              style: TextStyle(color: BrandColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: host,
              decoration: const InputDecoration(labelText: 'IP address'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final p = int.tryParse(port.text.trim()) ?? 35000;
    await settings.setWifiEndpoint(host.text.trim(), p);
    await c.connectWifi(host.text.trim(), p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ConnectionController>();
    final d = context.watch<DeviceDiscovery>();
    final settings = context.watch<SettingsRepository>();
    _followPhase(c.phase);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect your IQ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            _StatusHeader(connection: c, scanning: d.scanning),
            const SizedBox(height: 16),
            if (c.isBusy ||
                c.phase == ConnectionPhase.failed ||
                c.phase == ConnectionPhase.noVehicle)
              _ProgressCard(connection: c),
            if (c.isReady) _ConnectedCard(connection: c),
            if (!c.isReady && !c.isBusy) ...[
              if (settings.savedDevice != null &&
                  settings.savedDevice!.kind == TransportKind.bleElm327 &&
                  c.phase != ConnectionPhase.noVehicle)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _SavedDeviceCard(
                    saved: settings.savedDevice!,
                    onConnect: () async {
                      await d.stop();
                      await c.connectSavedBle(settings.savedDevice!);
                    },
                    onForget: c.forgetSavedDevice,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: d.scanning ? d.stop : d.start,
                icon: d.scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: BrandColors.charcoal,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  d.scanning ? 'Searching… tap to stop' : 'Search for scanners',
                ),
              ),
              if (d.error != null) ...[
                const SizedBox(height: 12),
                InfoNote(
                  text: d.error!,
                  icon: Icons.error_outline,
                  color: BrandColors.caution,
                ),
              ],
              if (d.availability == BleAvailability.unsupported &&
                  d.error == null) ...[
                const SizedBox(height: 12),
                const InfoNote(
                  text: 'Bluetooth is not available here. You can still explore the app with the demo IQ.',
                ),
              ],
              _DeviceSection(
                title: 'Compatible scanners',
                devices: d.candidates,
                emptyText: d.scanning ? 'Looking for your IQ…' : 'No scanners found yet. Make sure the IQ is on and its OBD-II scanner is connected to the car.',
                onTap: _connectBle,
              ),
              if (d.others.isNotEmpty) ...[
                SectionTitle(
                  'Other Bluetooth devices (${d.others.length})',
                  trailing: TextButton(
                    onPressed: () => setState(() => _showOthers = !_showOthers),
                    child: Text(_showOthers ? 'Hide' : 'Show'),
                  ),
                ),
                if (_showOthers)
                  for (final dev in d.others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DeviceTile(
                        device: dev,
                        onTap: () => _connectBle(dev),
                      ),
                    ),
              ],
              const SectionTitle('No IQ handy?'),
              MghCard(
                onTap: _pickDemo,
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, color: BrandColors.yellow),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Try the demo IQ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Simulated scanner and vehicle – clearly labelled.',
                            style: TextStyle(
                              color: BrandColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: BrandColors.faint),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              MghCard(
                onTap: _wifi,
                child: const Row(
                  children: [
                    Icon(Icons.wifi_rounded, color: BrandColors.muted),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Wi-Fi scanner (advanced)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: BrandColors.faint),
                  ],
                ),
              ),
            ],
            const SectionTitle('Troubleshooting'),
            const _Troubleshooting(),
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.connection, required this.scanning});
  final ConnectionController connection;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    final active = c.isBusy || scanning;
    final title = c.isReady
        ? (c.isSimulated
              ? 'Demo scanner connected'
              : 'Your scanner is connected')
        : c.isBusy
        ? c.statusLabel
        : scanning
        ? 'Searching nearby…'
        : 'Let\'s find your IQ';
    final subtitle = c.isReady
        ? 'Head to the dashboard to see live data.'
        : 'Connect the IQ\'s OBD-II scanner to the car, turn the ignition on, and keep your phone close.';
    return Column(
      children: [
        IqHeroGraphic(
          size: 170,
          animate: active || c.isReady,
          active: c.isReady,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: BrandColors.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.connection});
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    return MghCard(
      highlight: c.phase == ConnectionPhase.failed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in c.steps) _StepRow(step: s),
          if (c.error != null) ...[
            const Divider(height: 24),
            InfoNote(
              text: c.error!.userMessage,
              icon: c.phase == ConnectionPhase.noVehicle
                  ? Icons.key_outlined
                  : Icons.error_outline,
              color: c.phase == ConnectionPhase.noVehicle
                  ? BrandColors.caution
                  : BrandColors.danger,
            ),
          ],
          const SizedBox(height: 14),
          if (c.isBusy)
            OutlinedButton(onPressed: c.disconnect, child: const Text('Cancel'))
          else if (c.phase == ConnectionPhase.noVehicle)
            Column(
              children: [
                FilledButton(
                  onPressed: c.retryVehicleDetection,
                  child: const Text('Ignition is on – try again'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: c.disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            )
          else
            OutlinedButton(
              onPressed: () => c.disconnect(),
              child: const Text('Dismiss'),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final ConnectionStep step;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (step.state) {
      ProgressState.done => (Icons.check_circle_rounded, BrandColors.success),
      ProgressState.failed => (Icons.cancel_rounded, BrandColors.danger),
      ProgressState.running => (Icons.radio_button_checked, BrandColors.yellow),
      _ => (Icons.radio_button_unchecked, BrandColors.faint),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: step.state == ProgressState.running
                ? const Padding(
                    padding: EdgeInsets.all(3),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: BrandColors.yellow,
                    ),
                  )
                : Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: step.state == ProgressState.pending
                        ? BrandColors.faint
                        : BrandColors.white,
                  ),
                ),
                if (step.detail != null && step.state == ProgressState.done)
                  Text(
                    step.detail!,
                    style: const TextStyle(
                      color: BrandColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.connection});
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    final d = c.details!;
    final s = c.session!;
    return Column(
      children: [
        if (c.isSimulated)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SimulatedBanner(),
          ),
        MghCard(
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusDot(color: BrandColors.success, size: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.deviceName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Pill(
                    d.kind == TransportKind.simulated
                        ? 'Simulated'
                        : (s.identity?.verifiedByBehaviour ?? false)
                        ? 'ELM327-compatible'
                        : 'Verified ELM327',
                    color: d.kind == TransportKind.simulated
                        ? BrandColors.yellow
                        : BrandColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _kv('Scanner', s.identity?.banner ?? '—'),
              _kv('Link', d.kind.label),
              if (d.profileName != null) _kv('Profile', d.profileName!),
              _kv('Vehicle protocol', s.protocol.label),
              _kv('Device ID', Redactor.deviceId(d.deviceId)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: c.disconnect,
                      child: const Text('Disconnect'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(color: BrandColors.muted)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _SavedDeviceCard extends StatelessWidget {
  const _SavedDeviceCard({
    required this.saved,
    required this.onConnect,
    required this.onForget,
  });
  final SavedDevice saved;
  final VoidCallback onConnect;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return MghCard(
      onTap: onConnect,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BrandColors.yellowSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: BrandColors.yellow),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reconnect to ${saved.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Last verified scanner',
                  style: TextStyle(color: BrandColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Forget this scanner',
            onPressed: onForget,
            icon: const Icon(Icons.close, color: BrandColors.faint, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.devices,
    required this.emptyText,
    required this.onTap,
  });
  final String title;
  final List<DiscoveredDevice> devices;
  final String emptyText;
  final void Function(DiscoveredDevice) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              emptyText,
              style: const TextStyle(color: BrandColors.muted),
            ),
          ),
        for (final dev in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DeviceTile(device: dev, onTap: () => onTap(dev)),
          ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});
  final DiscoveredDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (device.compatibility) {
      DeviceCompatibility.documentedProfile ||
      DeviceCompatibility.iq => BrandColors.success,
      DeviceCompatibility.likelyScanner => BrandColors.yellow,
      DeviceCompatibility.unknown => BrandColors.faint,
    };
    return MghCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.bluetooth_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(device.compatibility.label, color: color),
                    Text(
                      'ID ${Redactor.deviceId(device.id)}',
                      style: const TextStyle(
                        color: BrandColors.faint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SignalBars(bars: device.signalBars, rssi: device.rssi),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars, required this.rssi});
  final int bars;
  final int? rssi;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rssi == null ? 'Signal unknown' : '$rssi dBm',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.only(left: 2),
              width: 4,
              height: 6.0 + i * 4,
              decoration: BoxDecoration(
                color: i < bars ? BrandColors.yellow : BrandColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _Troubleshooting extends StatelessWidget {
  const _Troubleshooting();

  static const tips = [
    (
      'Ignition on',
      'Most cars only answer diagnostic requests with the ignition on or the engine running.',
    ),
    (
      'Firmly connected',
      'The OBD-II port is usually under the dashboard near the steering column. Make sure the scanner\'s connector is pushed fully in.',
    ),
    (
      'Close other apps',
      'Bluetooth scanners accept one connection at a time. Fully close Mini OBDII or any other OBD app.',
    ),
    (
      'Don\'t pair in Settings',
      'Bluetooth LE scanners connect from inside the app – they do not need pairing in iOS Settings.',
    ),
    (
      'Bluetooth permission',
      'If nothing appears, check Settings › My Garage Hero IQ › Bluetooth is allowed.',
    ),
    (
      'Power cycle',
      'Unplug the scanner for 10 seconds, plug it back in, then search again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MghCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text(
            'Can\'t connect?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: const Icon(Icons.help_outline, color: BrandColors.yellow),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final (t, b) in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: BrandColors.yellow,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$t. ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: b,
                              style: const TextStyle(color: BrandColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
