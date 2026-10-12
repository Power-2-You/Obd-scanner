import 'package:flutter/foundation.dart';

import '../storage/document_store.dart';
import 'diagnostic_report.dart';

/// Local diagnostic history, newest first.
class HistoryRepository extends ChangeNotifier {
  HistoryRepository(this._store, {this.maxReports = 200});

  final DocumentStore _store;
  final int maxReports;
  static const _key = 'reports';
  final List<DiagnosticReport> _reports = [];

  List<DiagnosticReport> get reports => List.unmodifiable(_reports);

  List<DiagnosticReport> forVehicle(String vehicleId) =>
      _reports.where((r) => r.vehicleId == vehicleId).toList();

  DiagnosticReport? byId(String id) {
    for (final r in _reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final j = await _store.read(_key);
      if (j is List) {
        _reports
          ..clear()
          ..addAll(
            j.whereType<Map>().map(
              (m) => DiagnosticReport.fromJson(Map<String, dynamic>.from(m)),
            ),
          );
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save(DiagnosticReport report) async {
    _reports.removeWhere((r) => r.id == report.id);
    _reports.insert(0, report);
    while (_reports.length > maxReports) {
      _reports.removeLast();
    }
    await _store.write(_key, _reports.map((r) => r.toJson()).toList());
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _reports.removeWhere((r) => r.id == id);
    await _store.write(_key, _reports.map((r) => r.toJson()).toList());
    notifyListeners();
  }
}
