import 'package:flutter/foundation.dart';

/// A saved vehicle profile. [vin] is optional and only stored locally.
@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    this.year,
    this.engine = '',
    this.vin,
    this.nickname = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String make;
  final String model;
  final int? year;
  final String engine;
  final String? vin;
  final String nickname;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    return [
      if (year != null) '$year',
      make,
      model,
    ].where((s) => s.isNotEmpty).join(' ');
  }

  String get subtitle => [
    if (nickname.isNotEmpty) [if (year != null) '$year', make, model].join(' '),
    if (engine.isNotEmpty) engine,
  ].join(' · ');

  Vehicle copyWith({
    String? make,
    String? model,
    int? year,
    String? engine,
    String? vin,
    bool clearVin = false,
    String? nickname,
    DateTime? updatedAt,
  }) => Vehicle(
    id: id,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    engine: engine ?? this.engine,
    vin: clearVin ? null : (vin ?? this.vin),
    nickname: nickname ?? this.nickname,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, Object?> toJson({bool includeVin = true}) => {
    'id': id,
    'make': make,
    'model': model,
    'year': year,
    'engine': engine,
    if (includeVin) 'vin': vin,
    'nickname': nickname,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as String,
    make: j['make'] as String? ?? '',
    model: j['model'] as String? ?? '',
    year: (j['year'] as num?)?.toInt(),
    engine: j['engine'] as String? ?? '',
    vin: j['vin'] as String?,
    nickname: j['nickname'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  static final RegExp vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
}
