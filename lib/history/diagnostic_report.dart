import 'package:flutter/foundation.dart';

import '../ai/ai_models.dart';
import '../dtc/dtc.dart';

@immutable
class ReadingSnapshot {
  const ReadingSnapshot({
    required this.key,
    required this.name,
    required this.unit,
    required this.status,
    this.value,
    this.decimals = 0,
  });

  final String key;
  final String name;
  final String unit;

  /// live | unsupported | noData | error
  final String status;
  final double? value;
  final int decimals;

  String get display => value == null
      ? (status == 'unsupported' ? 'Not supported by vehicle' : 'Unavailable')
      : '${value!.toStringAsFixed(decimals)} $unit';

  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    'unit': unit,
    'status': status,
    'value': value,
    'decimals': decimals,
  };

  factory ReadingSnapshot.fromJson(Map<String, dynamic> j) => ReadingSnapshot(
    key: j['key'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String? ?? '',
    status: j['status'] as String? ?? 'error',
    value: (j['value'] as num?)?.toDouble(),
    decimals: (j['decimals'] as num?)?.toInt() ?? 0,
  );
}

/// A saved diagnostic session.
@immutable
class DiagnosticReport {
  const DiagnosticReport({
    required this.id,
    required this.createdAt,
    required this.dataOrigin,
    required this.scannerName,
    this.vehicleId,
    this.vehicle,
    this.scannerFamily,
    this.protocol,
    this.storedCodes = const [],
    this.pendingCodes = const [],
    this.milOn,
    this.readings = const [],
    this.aiQuestion,
    this.aiAnswer,
    this.notes = '',
  });

  final String id;
  final DateTime createdAt;

  /// 'live' or 'simulated'.
  final String dataOrigin;
  final String scannerName;
  final String? vehicleId;

  /// Snapshot of the vehicle profile at report time (VIN excluded).
  final Map<String, Object?>? vehicle;
  final String? scannerFamily;
  final String? protocol;
  final List<DiagnosticTroubleCode> storedCodes;
  final List<DiagnosticTroubleCode> pendingCodes;
  final bool? milOn;
  final List<ReadingSnapshot> readings;
  final String? aiQuestion;
  final AiMechanicAnswer? aiAnswer;
  final String notes;

  bool get isSimulated => dataOrigin != 'live';
  int get codeCount => storedCodes.length + pendingCodes.length;

  String get vehicleName {
    final v = vehicle;
    if (v == null) return 'Unspecified vehicle';
    final nick = v['nickname'] as String? ?? '';
    if (nick.isNotEmpty) return nick;
    return [
      v['year'],
      v['make'],
      v['model'],
    ].where((e) => e != null && '$e'.isNotEmpty).join(' ');
  }

  DiagnosticReport copyWith({
    String? aiQuestion,
    AiMechanicAnswer? aiAnswer,
    String? notes,
  }) => DiagnosticReport(
    id: id,
    createdAt: createdAt,
    dataOrigin: dataOrigin,
    scannerName: scannerName,
    vehicleId: vehicleId,
    vehicle: vehicle,
    scannerFamily: scannerFamily,
    protocol: protocol,
    storedCodes: storedCodes,
    pendingCodes: pendingCodes,
    milOn: milOn,
    readings: readings,
    aiQuestion: aiQuestion ?? this.aiQuestion,
    aiAnswer: aiAnswer ?? this.aiAnswer,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'dataOrigin': dataOrigin,
    'scannerName': scannerName,
    'vehicleId': vehicleId,
    'vehicle': vehicle,
    'scannerFamily': scannerFamily,
    'protocol': protocol,
    'storedCodes': storedCodes.map((c) => c.toJson()).toList(),
    'pendingCodes': pendingCodes.map((c) => c.toJson()).toList(),
    'milOn': milOn,
    'readings': readings.map((r) => r.toJson()).toList(),
    'aiQuestion': aiQuestion,
    'aiAnswer': aiAnswer?.toJson(),
    'notes': notes,
  };

  factory DiagnosticReport.fromJson(Map<String, dynamic> j) {
    List<DiagnosticTroubleCode> codes(String k) => (j[k] as List? ?? [])
        .whereType<Map>()
        .map(
          (m) => DiagnosticTroubleCode.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();
    return DiagnosticReport(
      id: j['id'] as String,
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      dataOrigin: j['dataOrigin'] as String? ?? 'simulated',
      scannerName: j['scannerName'] as String? ?? '',
      vehicleId: j['vehicleId'] as String?,
      vehicle: (j['vehicle'] as Map?)?.cast<String, Object?>(),
      scannerFamily: j['scannerFamily'] as String?,
      protocol: j['protocol'] as String?,
      storedCodes: codes('storedCodes'),
      pendingCodes: codes('pendingCodes'),
      milOn: j['milOn'] as bool?,
      readings: (j['readings'] as List? ?? [])
          .whereType<Map>()
          .map((m) => ReadingSnapshot.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      aiQuestion: j['aiQuestion'] as String?,
      aiAnswer: j['aiAnswer'] is Map
          ? AiMechanicAnswer.fromJson(
              Map<String, dynamic>.from(j['aiAnswer'] as Map),
            )
          : null,
      notes: j['notes'] as String? ?? '',
    );
  }
}
