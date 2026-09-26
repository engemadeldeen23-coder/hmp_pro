import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

// ============================================================
//  PERSISTENT STORAGE SERVICE
//  All data saved as JSON files in app documents directory
// ============================================================
class StorageService {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  Directory? _dir;

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    _dir = await getApplicationDocumentsDirectory();
    return _dir!;
  }

  // ------- Generic JSON file read/write -------
  Future<Map<String, dynamic>?> _readJson(String filename) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/$filename');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Storage read error ($filename): $e');
      return null;
    }
  }

  Future<void> _writeJson(String filename, Map<String, dynamic> data) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Storage write error ($filename): $e');
    }
  }

  // ------- User Profile -------
  Future<UserProfile> loadProfile() async {
    final j = await _readJson('user_profile.json');
    if (j == null) return UserProfile();
    return UserProfile.fromJson(j);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _writeJson('user_profile.json', profile.toJson());
  }

  Future<void> deleteProfile() async {
    final dir = await _getDir();
    final file = File('${dir.path}/user_profile.json');
    if (await file.exists()) await file.delete();
  }

  // ------- Sites (with hierarchical jobs/locations/drops) -------
  Future<List<Site>> loadSites() async {
    final j = await _readJson('sites.json');
    if (j == null) return [];
    final list = j['sites'] as List? ?? [];
    return list
        .map((x) => Site.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSites(List<Site> sites) async {
    await _writeJson('sites.json', {
      'sites': sites.map((s) => s.toJson()).toList(),
    });
  }

  // ------- Active selections -------
  Future<Map<String, String>> loadActive() async {
    final j = await _readJson('active.json');
    if (j == null) {
      return {'siteId': '', 'jobId': '', 'locationId': ''};
    }
    return {
      'siteId': j['siteId'] ?? '',
      'jobId': j['jobId'] ?? '',
      'locationId': j['locationId'] ?? '',
    };
  }

  Future<void> saveActive(String siteId, String jobId, String locationId) async {
    await _writeJson('active.json', {
      'siteId': siteId,
      'jobId': jobId,
      'locationId': locationId,
    });
  }

  // ------- Drop Settings -------
  Future<DropSettings> loadDropSettings() async {
    final j = await _readJson('drop_settings.json');
    if (j == null) return DropSettings();
    return DropSettings.fromJson(j);
  }

  Future<void> saveDropSettings(DropSettings s) async {
    await _writeJson('drop_settings.json', s.toJson());
  }

  // ------- Calibration -------
  Future<Calibration> loadCalibration() async {
    final j = await _readJson('calibration.json');
    if (j == null) return Calibration();
    return Calibration.fromJson(j);
  }

  Future<void> saveCalibration(Calibration c) async {
    await _writeJson('calibration.json', c.toJson());
  }

  // ------- GPS recording toggle -------
  Future<bool> loadGpsRecordingEnabled() async {
    final j = await _readJson('gps_toggle.json');
    return j?['enabled'] ?? true;
  }

  Future<void> saveGpsRecordingEnabled(bool enabled) async {
    await _writeJson('gps_toggle.json', {'enabled': enabled});
  }

  // ------- Voice enabled -------
  Future<bool> loadVoiceEnabled() async {
    final j = await _readJson('voice_toggle.json');
    return j?['enabled'] ?? true;
  }

  Future<void> saveVoiceEnabled(bool enabled) async {
    await _writeJson('voice_toggle.json', {'enabled': enabled});
  }
}