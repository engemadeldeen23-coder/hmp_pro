import 'package:flutter/material.dart';

// ============================================================
//  USER PROFILE
// ============================================================
class UserProfile {
  String companyName;
  String title;
  String engineerName;
  String city;
  String country;
  String phone;
  String email;
  String website;
  String? logoPath;
  bool useMetric;

  UserProfile({
    this.companyName = '',
    this.title = '',
    this.engineerName = '',
    this.city = '',
    this.country = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.logoPath,
    this.useMetric = true,
  });

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'title': title,
        'engineerName': engineerName,
        'city': city,
        'country': country,
        'phone': phone,
        'email': email,
        'website': website,
        'logoPath': logoPath,
        'useMetric': useMetric,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        companyName: j['companyName'] ?? '',
        title: j['title'] ?? '',
        engineerName: j['engineerName'] ?? '',
        city: j['city'] ?? '',
        country: j['country'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        website: j['website'] ?? '',
        logoPath: j['logoPath'],
        useMetric: j['useMetric'] ?? true,
      );
}

// ============================================================
//  DROP (single measurement)
// ============================================================
class Drop {
  final String id;
  final DateTime time;
  final int dropNumber;
  final bool isPreload;
  final double evd;          // MN/m²
  final double deflection;    // mm
  final double acceleration;  // g
  final double velocity;      // m/s
  final double latitude;
  final double longitude;
  final double accuracy;
  final String? photoPath;
  final double plateRadius;   // m (per drop - can be edited)
  final List<double> settlementCurve;
  final List<double> impactCurve;

  Drop({
    required this.id,
    required this.time,
    required this.dropNumber,
    required this.isPreload,
    required this.evd,
    required this.deflection,
    required this.acceleration,
    required this.velocity,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.photoPath,
    required this.plateRadius,
    this.settlementCurve = const [],
    this.impactCurve = const [],
  });

  bool get hasLocation => latitude != 0 || longitude != 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'dropNumber': dropNumber,
        'isPreload': isPreload,
        'evd': evd,
        'deflection': deflection,
        'acceleration': acceleration,
        'velocity': velocity,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'photoPath': photoPath,
        'plateRadius': plateRadius,
        'settlementCurve': settlementCurve,
        'impactCurve': impactCurve,
      };

  factory Drop.fromJson(Map<String, dynamic> j) => Drop(
        id: j['id'],
        time: DateTime.parse(j['time']),
        dropNumber: j['dropNumber'] ?? 0,
        isPreload: j['isPreload'] ?? false,
        evd: (j['evd'] ?? 0).toDouble(),
        deflection: (j['deflection'] ?? 0).toDouble(),
        acceleration: (j['acceleration'] ?? 0).toDouble(),
        velocity: (j['velocity'] ?? 0).toDouble(),
        latitude: (j['latitude'] ?? 0).toDouble(),
        longitude: (j['longitude'] ?? 0).toDouble(),
        accuracy: (j['accuracy'] ?? 0).toDouble(),
        photoPath: j['photoPath'],
        plateRadius: (j['plateRadius'] ?? 0.15).toDouble(),
        settlementCurve: List<double>.from(j['settlementCurve'] ?? []),
        impactCurve: List<double>.from(j['impactCurve'] ?? []),
      );
}

// ============================================================
//  LOCATION
// ============================================================
class Location {
  String id;
  String name;
  double latitude;
  double longitude;
  String? photoPath;
  List<Drop> drops;

  Location({
    required this.id,
    required this.name,
    this.latitude = 0,
    this.longitude = 0,
    this.photoPath,
    List<Drop>? drops,
  }) : drops = drops ?? [];

  int get testCount => drops.where((d) => !d.isPreload).length;

  double get avgEvd {
    final tests = drops.where((d) => !d.isPreload).toList();
    if (tests.isEmpty) return 0;
    return tests.map((d) => d.evd).reduce((a, b) => a + b) / tests.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'photoPath': photoPath,
        'drops': drops.map((d) => d.toJson()).toList(),
      };

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        id: j['id'],
        name: j['name'] ?? '',
        latitude: (j['latitude'] ?? 0).toDouble(),
        longitude: (j['longitude'] ?? 0).toDouble(),
        photoPath: j['photoPath'],
        drops: (j['drops'] as List? ?? [])
            .map((x) => Drop.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================================
//  JOB
// ============================================================
class Job {
  String id;
  String name;
  List<Location> locations;

  Job({
    required this.id,
    required this.name,
    List<Location>? locations,
  }) : locations = locations ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locations': locations.map((l) => l.toJson()).toList(),
      };

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id'],
        name: j['name'] ?? '',
        locations: (j['locations'] as List? ?? [])
            .map((x) => Location.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================================
//  SITE
// ============================================================
class Site {
  String id;
  String name;
  List<Job> jobs;

  Site({
    required this.id,
    required this.name,
    List<Job>? jobs,
  }) : jobs = jobs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'jobs': jobs.map((j) => j.toJson()).toList(),
      };

  factory Site.fromJson(Map<String, dynamic> j) => Site(
        id: j['id'],
        name: j['name'] ?? '',
        jobs: (j['jobs'] as List? ?? [])
            .map((x) => Job.fromJson(x as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================================
//  DROP SETTINGS (device settings)
// ============================================================
class DropSettings {
  double plateRadius;      // m
  double poissonRatio;     // default 0.5
  double distributionFactor; // default 2.0
  double geophoneDistance; // mm (0 = no external)
  double targetEvd;        // MN/m² (pass/fail)

  DropSettings({
    this.plateRadius = 0.15,
    this.poissonRatio = 0.5,
    this.distributionFactor = 2.0,
    this.geophoneDistance = 0,
    this.targetEvd = 40.0,
  });

  double get plateDiameterCm => plateRadius * 2 * 100;

  Map<String, dynamic> toJson() => {
        'plateRadius': plateRadius,
        'poissonRatio': poissonRatio,
        'distributionFactor': distributionFactor,
        'geophoneDistance': geophoneDistance,
        'targetEvd': targetEvd,
      };

  factory DropSettings.fromJson(Map<String, dynamic> j) => DropSettings(
        plateRadius: (j['plateRadius'] ?? 0.15).toDouble(),
        poissonRatio: (j['poissonRatio'] ?? 0.5).toDouble(),
        distributionFactor: (j['distributionFactor'] ?? 2.0).toDouble(),
        geophoneDistance: (j['geophoneDistance'] ?? 0).toDouble(),
        targetEvd: (j['targetEvd'] ?? 40.0).toDouble(),
      );
}

// ============================================================
//  CALIBRATION
// ============================================================
class Calibration {
  double factor;
  String date;

  Calibration({this.factor = 1.0, this.date = 'Never'});

  Map<String, dynamic> toJson() => {'factor': factor, 'date': date};

  factory Calibration.fromJson(Map<String, dynamic> j) => Calibration(
        factor: (j['factor'] ?? 1.0).toDouble(),
        date: j['date'] ?? 'Never',
      );
}