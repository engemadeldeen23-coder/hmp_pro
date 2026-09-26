// ============================================================
//  MODELS
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
//  DROP (single test drop - no preload stored)
// ============================================================
class Drop {
  final String id;
  final DateTime time;
  final int dropNumber;
  final double evd;
  final double deflection;
  final double acceleration;
  final double velocity;
  final List<double> settlementCurve;
  final List<double> velocityCurve;

  Drop({
    required this.id,
    required this.time,
    required this.dropNumber,
    required this.evd,
    required this.deflection,
    required this.acceleration,
    required this.velocity,
    this.settlementCurve = const [],
    this.velocityCurve = const [],
  });

  /// Settlement / Velocity ratio (s/v) in mm / (m/s)
  double get sOverV => velocity.abs() > 0.0001 ? deflection / velocity : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'dropNumber': dropNumber,
        'evd': evd,
        'deflection': deflection,
        'acceleration': acceleration,
        'velocity': velocity,
        'settlementCurve': settlementCurve,
        'velocityCurve': velocityCurve,
      };

  factory Drop.fromJson(Map<String, dynamic> j) => Drop(
        id: j['id'],
        time: DateTime.parse(j['time']),
        dropNumber: j['dropNumber'] ?? 0,
        evd: (j['evd'] ?? 0).toDouble(),
        deflection: (j['deflection'] ?? 0).toDouble(),
        acceleration: (j['acceleration'] ?? 0).toDouble(),
        velocity: (j['velocity'] ?? 0).toDouble(),
        settlementCurve: List<double>.from(j['settlementCurve'] ?? []),
        velocityCurve: List<double>.from(j['velocityCurve'] ?? []),
      );
}

// ============================================================
//  TEST GROUP (exactly 3 test drops)
// ============================================================
class TestGroup {
  final String id;
  final DateTime time;
  final List<Drop> drops;      // exactly 3 drops
  final double plateRadius;    // m
  final double latitude;
  final double longitude;
  final double accuracy;
  String? reportNote;

  TestGroup({
    required this.id,
    required this.time,
    required this.drops,
    required this.plateRadius,
    this.latitude = 0,
    this.longitude = 0,
    this.accuracy = 0,
    this.reportNote,
  });

  bool get hasLocation => latitude != 0 || longitude != 0;
  bool get isComplete => drops.length >= 3;
  double get plateDiameterMm => plateRadius * 2000;

  // Averages
  double get avgEvd => drops.isEmpty
      ? 0
      : drops.map((d) => d.evd).reduce((a, b) => a + b) / drops.length;

  double get avgDeflection => drops.isEmpty
      ? 0
      : drops.map((d) => d.deflection).reduce((a, b) => a + b) / drops.length;

  double get avgAcceleration => drops.isEmpty
      ? 0
      : drops.map((d) => d.acceleration).reduce((a, b) => a + b) /
          drops.length;

  double get avgVelocity => drops.isEmpty
      ? 0
      : drops.map((d) => d.velocity).reduce((a, b) => a + b) / drops.length;

  double get avgSOverV => drops.isEmpty
      ? 0
      : drops.map((d) => d.sOverV).reduce((a, b) => a + b) / drops.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'drops': drops.map((d) => d.toJson()).toList(),
        'plateRadius': plateRadius,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'reportNote': reportNote,
      };

  factory TestGroup.fromJson(Map<String, dynamic> j) => TestGroup(
        id: j['id'],
        time: DateTime.parse(j['time']),
        drops: (j['drops'] as List? ?? [])
            .map((x) => Drop.fromJson(x as Map<String, dynamic>))
            .toList(),
        plateRadius: (j['plateRadius'] ?? 0.15).toDouble(),
        latitude: (j['latitude'] ?? 0).toDouble(),
        longitude: (j['longitude'] ?? 0).toDouble(),
        accuracy: (j['accuracy'] ?? 0).toDouble(),
        reportNote: j['reportNote'],
      );
}

// ============================================================
//  LOCATION (contains test groups)
// ============================================================
class Location {
  String id;
  String name;
  double latitude;
  double longitude;
  String? photoPath;
  List<TestGroup> testGroups;

  Location({
    required this.id,
    required this.name,
    this.latitude = 0,
    this.longitude = 0,
    this.photoPath,
    List<TestGroup>? testGroups,
  }) : testGroups = testGroups ?? [];

  int get totalTests =>
      testGroups.fold(0, (sum, g) => sum + g.drops.length);

  double get avgEvd {
    if (testGroups.isEmpty) return 0;
    final all = testGroups.expand((g) => g.drops).toList();
    if (all.isEmpty) return 0;
    return all.map((d) => d.evd).reduce((a, b) => a + b) / all.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'photoPath': photoPath,
        'testGroups': testGroups.map((g) => g.toJson()).toList(),
      };

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        id: j['id'],
        name: j['name'] ?? '',
        latitude: (j['latitude'] ?? 0).toDouble(),
        longitude: (j['longitude'] ?? 0).toDouble(),
        photoPath: j['photoPath'],
        testGroups: (j['testGroups'] as List? ?? [])
            .map((x) => TestGroup.fromJson(x as Map<String, dynamic>))
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

  Job({required this.id, required this.name, List<Location>? locations})
      : locations = locations ?? [];

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

  Site({required this.id, required this.name, List<Job>? jobs})
      : jobs = jobs ?? [];

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
//  DROP SETTINGS
// ============================================================
class DropSettings {
  double plateRadius;
  double poissonRatio;
  double distributionFactor;
  double geophoneDistance;
  double targetEvd;

  DropSettings({
    this.plateRadius = 0.15,
    this.poissonRatio = 0.5,
    this.distributionFactor = 2.0,
    this.geophoneDistance = 0,
    this.targetEvd = 40.0,
  });

  double get plateDiameterMm => plateRadius * 2000;

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