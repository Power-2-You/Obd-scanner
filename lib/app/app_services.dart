import '../ai/ai_mechanic_controller.dart';
import '../ai/ai_mechanic_service.dart';
import '../core/settings/settings_repository.dart';
import '../core/telemetry/diagnostic_log.dart';
import '../core/telemetry/telemetry.dart';
import '../device/connection_controller.dart';
import '../device/device_discovery.dart';
import '../device/milestone_runner.dart';
import '../dtc/fault_scan_controller.dart';
import '../history/history_repository.dart';
import '../obd/live_data_controller.dart';
import '../storage/document_store.dart';
import '../storage/platform_store.dart';
import '../transport/ble/ble_gateway.dart';
import '../vehicle/vehicle_repository.dart';

/// Composition root: creates every service once and wires dependencies.
class AppServices {
  AppServices._({
    required this.log,
    required this.telemetry,
    required this.settings,
    required this.vehicles,
    required this.history,
    required this.discovery,
    required this.connection,
    required this.live,
    required this.faults,
    required this.milestone,
    required this.ai,
  });

  final DiagnosticLog log;
  final Telemetry telemetry;
  final SettingsRepository settings;
  final VehicleRepository vehicles;
  final HistoryRepository history;
  final DeviceDiscovery discovery;
  final ConnectionController connection;
  final LiveDataController live;
  final FaultScanController faults;
  final MilestoneRunner milestone;
  final AiMechanicController ai;

  static Future<AppServices> create({
    DocumentStore? store,
    BleGateway? gateway,
    AiMechanicService? aiService,
  }) async {
    final log = DiagnosticLog();
    final telemetry = Telemetry(log: log);
    final docs = store ?? await createPlatformDocumentStore();
    final ble = gateway ?? UniversalBleGateway();

    final settings = SettingsRepository(docs);
    final vehicles = VehicleRepository(docs);
    final history = HistoryRepository(docs);
    await Future.wait([settings.load(), vehicles.load(), history.load()]);

    final connection = ConnectionController(
      gateway: ble,
      settings: settings,
      log: log,
      telemetry: telemetry,
    );
    log.info(LogCategory.app, 'App started');
    return AppServices._(
      log: log,
      telemetry: telemetry,
      settings: settings,
      vehicles: vehicles,
      history: history,
      discovery: DeviceDiscovery(gateway: ble, log: log),
      connection: connection,
      live: LiveDataController(
        connection: connection,
        settings: settings,
        log: log,
      ),
      faults: FaultScanController(connection: connection, telemetry: telemetry),
      milestone: MilestoneRunner(connection: connection, log: log),
      ai: AiMechanicController(
        service: aiService ?? createAiMechanicService(),
        log: log,
      ),
    );
  }
}
