import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../storage/document_store.dart';
import 'vehicle.dart';

/// Local garage of vehicle profiles.
class VehicleRepository extends ChangeNotifier {
  VehicleRepository(this._store);

  final DocumentStore _store;
  static const _key = 'vehicles';
  static const _uuid = Uuid();

  final List<Vehicle> _vehicles = [];
  String? _activeId;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);

  Vehicle? get active {
    for (final v in _vehicles) {
      if (v.id == _activeId) return v;
    }
    return _vehicles.isEmpty ? null : _vehicles.first;
  }

  Vehicle? byId(String? id) {
    for (final v in _vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final j = await _store.read(_key);
      if (j is Map) {
        _vehicles
          ..clear()
          ..addAll(
            (j['items'] as List? ?? []).whereType<Map>().map(
              (m) => Vehicle.fromJson(Map<String, dynamic>.from(m)),
            ),
          );
        _activeId = j['activeId'] as String?;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.write(_key, {
      'items': _vehicles.map((v) => v.toJson()).toList(),
      'activeId': _activeId,
    });
    notifyListeners();
  }

  Future<Vehicle> add({
    required String make,
    required String model,
    int? year,
    String engine = '',
    String? vin,
    String nickname = '',
  }) async {
    final now = DateTime.now();
    final v = Vehicle(
      id: _uuid.v4(),
      make: make.trim(),
      model: model.trim(),
      year: year,
      engine: engine.trim(),
      vin: (vin == null || vin.trim().isEmpty)
          ? null
          : vin.trim().toUpperCase(),
      nickname: nickname.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _vehicles.add(v);
    _activeId ??= v.id;
    await _save();
    return v;
  }

  Future<void> update(Vehicle v) async {
    final i = _vehicles.indexWhere((e) => e.id == v.id);
    if (i < 0) return;
    _vehicles[i] = v.copyWith(updatedAt: DateTime.now());
    await _save();
  }

  Future<void> remove(String id) async {
    _vehicles.removeWhere((v) => v.id == id);
    if (_activeId == id) {
      _activeId = _vehicles.isEmpty ? null : _vehicles.first.id;
    }
    await _save();
  }

  Future<void> setActive(String id) async {
    _activeId = id;
    await _save();
  }
}
