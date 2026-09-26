import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'models/models.dart';
import 'services/storage_service.dart';
import 'services/ble_service.dart';
import 'services/gps_service.dart';
import 'services/voice_service.dart';
import 'services/export_service.dart';
import 'widgets/magic_eye.dart';
import 'screens/user_profile_page.dart';
import 'screens/project_settings_page.dart';
import 'screens/drop_settings_page.dart';
import 'screens/measurement_page.dart';

// ============================================================
//  MAIN
// ============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0A0E1A),
    statusBarIconBrightness: Brightness.light,
  ));
  FlutterError.onError = (d) => print('Flutter error: ${d.exception}');
  runApp(const HmpProApp());
}

class HmpProApp extends StatelessWidget {
  const HmpProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HMP PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF1E88E5),
          surface: Color(0xFF151B2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E1A),
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
//  HOME PAGE
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _storage = StorageService();
  final _ble = BleService();
  final _gps = GpsService();
  final _voice = VoiceService();
  final _battery = Battery();

  // Data
  UserProfile _profile = UserProfile();
  List<Site> _sites = [];
  String _activeSiteId = '';
  String _activeJobId = '';
  String _activeLocationId = '';
  DropSettings _dropSettings = DropSettings();
  Calibration _calibration = Calibration();

  // State
  bool _gpsRecordingEnabled = true;
  bool _voiceEnabled = true;
  MagicEyeState _eyeState = MagicEyeState.off;
  int _batteryLevel = -1;
  bool _batteryCharging = false;
  DateTime _now = DateTime.now();
  String _weather = '';

  // Subscriptions
  StreamSubscription? _bleDataSub;
  StreamSubscription? _bleConnSub;
  StreamSubscription? _gpsSub;

  // Live reading
  double _lastEvd = 0;
  double _lastDef = 0;
  double _lastAcc = 0;
  double _lastVel = 0;

  Timer? _clockTimer;
  Timer? _batteryTimer;

  // Diagnostics
  String? _errorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshBattery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _batteryTimer?.cancel();
    _bleDataSub?.cancel();
    _bleConnSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  // ============================================================
  //  INIT (with full error catching)
  // ============================================================
  Future<void> _init() async {
    try {
      print('=== HMP PRO starting ===');

      // Permissions
      try {
        print('Requesting permissions...');
        await [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.camera,
        ].request();
        print('Permissions OK');
      } catch (e) {
        print('Permission error: $e');
      }

      // Voice
      try {
        print('Initializing voice...');
        await _voice.init();
        print('Voice OK');
      } catch (e) {
        print('Voice init failed: $e');
      }

      // Storage
      try {
        print('Loading storage...');
        _profile = await _storage.loadProfile();
        _sites = await _storage.loadSites();
        final active = await _storage.loadActive();
        _activeSiteId = active['siteId'] ?? '';
        _activeJobId = active['jobId'] ?? '';
        _activeLocationId = active['locationId'] ?? '';
        _dropSettings = await _storage.loadDropSettings();
        _calibration = await _storage.loadCalibration();
        _gpsRecordingEnabled = await _storage.loadGpsRecordingEnabled();
        _voiceEnabled = await _storage.loadVoiceEnabled();
        _voice.setEnabled(_voiceEnabled);
        print('Storage OK');
      } catch (e, st) {
        print('Storage error: $e\n$st');
        if (mounted) {
          setState(() => _errorMessage = 'Storage error: $e');
        }
      }

      // GPS
      try {
        print('Starting GPS...');
        if (_gpsRecordingEnabled) _gps.start();
        _gpsSub = _gps.positionStream.listen((_) {
          if (mounted) setState(() {});
        });
        print('GPS OK');
      } catch (e) {
        print('GPS start failed: $e');
      }

      // Battery
      try {
        print('Refreshing battery...');
        _refreshBattery();
        print('Battery OK');
      } catch (e) {
        print('Battery failed: $e');
      }

      // Weather (non-blocking)
      _fetchWeather();

      // BLE listeners
      try {
        print('Setting up BLE listeners...');
        _bleConnSub = _ble.connectionStream.listen((connected) {
          if (!mounted) return;
          setState(() {
            _eyeState = connected
                ? (_eyeState == MagicEyeState.green
                    ? MagicEyeState.green
                    : MagicEyeState.blue)
                : MagicEyeState.red;
          });
        });
        _bleDataSub = _ble.dataStream.listen(_onBleData);
        print('BLE OK');
      } catch (e) {
        print('BLE listener failed: $e');
      }

      if (mounted) {
        setState(() {
          _initialized = true;
          _eyeState = MagicEyeState.red;
        });
      }
      print('=== HMP PRO ready ===');
    } catch (e, st) {
      print('FATAL: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = 'Fatal error: $e');
      }
    }
  }

  Future<void> _refreshBattery() async {
    try {
      final l = await _battery.batteryLevel;
      final s = await _battery.batteryState;
      if (!mounted) return;
      setState(() {
        _batteryLevel = l;
        _batteryCharging = s == BatteryState.charging ||
            s == BatteryState.full;
      });
    } catch (_) {}
  }

  Future<void> _fetchWeather() async {
    try {
      final pos = _gps.current;
      if (pos == null) return;
      final url = Uri.parse(
          'https://wttr.in/${pos.latitude},${pos.longitude}?format=%C+%t');
      final res =
          await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        setState(() => _weather = res.body.trim());
      }
    } catch (_) {}
  }

  void _onBleData(Map<String, dynamic> m) {
    if (!mounted) return;
    final type = m['type'] as String?;
    if (type == 'hb') return;

    final evd = (m['evd'] ?? 0).toDouble() * _calibration.factor;
    final def = (m['def'] ?? 0).toDouble();
    final acc = (m['acc'] ?? 0).toDouble();
    final vel = (m['vel'] ?? 0).toDouble();

    setState(() {
      _lastEvd = evd;
      _lastDef = def;
      _lastAcc = acc;
      _lastVel = vel;
    });
  }

  // ------- Active references -------
  Site? get _activeSite =>
      _sites.firstWhereOrNull((s) => s.id == _activeSiteId);
  Job? get _activeJob =>
      _activeSite?.jobs.firstWhereOrNull((j) => j.id == _activeJobId);
  Location? get _activeLocation =>
      _activeJob?.locations.firstWhereOrNull((l) => l.id == _activeLocationId);

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // Show error if any
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.redAccent, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'STARTUP ERROR',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: SelectableText(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00E5FF)),
              SizedBox(height: 20),
              Text(
                'Starting HMP PRO...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Normal UI
    return Scaffold(
      drawer: _buildSettingsDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildUpperZone(),
            Expanded(child: _buildCentralZone()),
            _buildLowerZone(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  UPPER ZONE
  // ============================================================
  Widget _buildUpperZone() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        border: Border(bottom: BorderSide(color: Color(0xFF1A2540))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF00E5FF)),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_now),
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(_now),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              if (_ble.isConnected && _batteryLevel >= 0)
                _buildBatteryIndicator(),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF151B2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A3654)),
            ),
            child: Row(
              children: [
                Icon(
                  _ble.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _ble.isConnected
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _ble.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 10,
                    color: _ble.isConnected
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                    width: 1, height: 12, color: const Color(0xFF2A3654)),
                const SizedBox(width: 12),
                Icon(Icons.wifi,
                    size: 12,
                    color: _weather.isNotEmpty
                        ? Colors.greenAccent
                        : Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _weather.isNotEmpty ? _weather : 'No internet',
                    style: TextStyle(
                      fontSize: 10,
                      color: _weather.isNotEmpty
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    final color = _batteryLevel > 60
        ? Colors.greenAccent
        : _batteryLevel > 20
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            _batteryCharging
                ? Icons.battery_charging_full
                : Icons.battery_full,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  CENTRAL ZONE
  // ============================================================
  Widget _buildCentralZone() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildProjectStatusCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.business,
                  label: 'Project\nSettings',
                  color: const Color(0xFF1E88E5),
                  onTap: _openProjectSettings,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.tune,
                  label: 'Test\nSettings',
                  color: Colors.amber.shade700,
                  onTap: _openDropSettings,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.location_on,
                  label: 'GPS\nCoordinates',
                  color: Colors.purpleAccent.shade700,
                  onTap: _showGpsInfo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: _gpsRecordingEnabled
                      ? Icons.gps_fixed
                      : Icons.gps_off,
                  label: _gpsRecordingEnabled
                      ? 'GPS\nRecord ON'
                      : 'GPS\nRecord OFF',
                  color: _gpsRecordingEnabled
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                  onTap: _toggleGpsRecording,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLiveCard(),
          const SizedBox(height: 12),
          _buildEyeCard(),
        ],
      ),
    );
  }

  Widget _buildProjectStatusCard() {
    final site = _activeSite;
    final job = _activeJob;
    final loc = _activeLocation;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151B2E), Color(0xFF1E2740)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment, color: Color(0xFF00E5FF), size: 14),
              SizedBox(width: 6),
              Text('ACTIVE PROJECT',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          _statusRow('Site', site?.name ?? 'None selected'),
          _statusRow('Job', job?.name ?? 'None selected'),
          _statusRow('Location', loc?.name ?? 'None selected'),
          _statusRow('Groups',
              loc == null ? '—' : '${loc.testGroups.length}'),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCard() {
    final passed = _lastEvd >= _dropSettings.targetEvd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151B2E), Color(0xFF1E2740)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed
              ? Colors.green.withOpacity(0.4)
              : const Color(0xFF2A3654),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bigMetric('EVD', _lastEvd.toStringAsFixed(1), 'MN/m²',
                  const Color(0xFF00E5FF)),
              _bigMetric('DEFL', _lastDef.toStringAsFixed(3), 'mm',
                  Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _smallMetric('ACC',
                    '${_lastAcc.toStringAsFixed(2)} g',
                    Colors.purpleAccent),
              ),
              Expanded(
                child: _smallMetric('VEL',
                    '${_lastVel.toStringAsFixed(3)} m/s',
                    Colors.greenAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigMetric(String label, String value, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                letterSpacing: 1.5)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Text(unit,
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _smallMetric(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildEyeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Row(
        children: [
          MagicEye(state: _eyeState, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MAGIC EYE',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  _eyeStateText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _eyeStateHint(),
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eyeStateText() {
    switch (_eyeState) {
      case MagicEyeState.off:
        return 'System Off';
      case MagicEyeState.selfTest:
        return 'Running Self-Test...';
      case MagicEyeState.red:
        return 'Not Connected';
      case MagicEyeState.blue:
        return 'Connected - Ready';
      case MagicEyeState.green:
        return 'Recording...';
    }
  }

  String _eyeStateHint() {
    switch (_eyeState) {
      case MagicEyeState.off:
        return 'Tap CONNECT to begin';
      case MagicEyeState.selfTest:
        return 'Please wait...';
      case MagicEyeState.red:
        return 'Tap CONNECT to link device';
      case MagicEyeState.blue:
        return 'Tap START TEST to begin';
      case MagicEyeState.green:
        return 'Drop the weight now';
    }
  }

  // ============================================================
  //  LOWER ZONE
  // ============================================================
  Widget _buildLowerZone() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        border: Border(top: BorderSide(color: Color(0xFF1A2540))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ble.isConnected ? null : _connectDevice,
                  icon: Icon(
                    _ble.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                    size: 18,
                  ),
                  label:
                      Text(_ble.isConnected ? 'CONNECTED' : 'CONNECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ble.isConnected
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _voiceEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _voiceEnabled
                      ? const Color(0xFF00E5FF)
                      : Colors.grey,
                ),
                onPressed: _toggleVoice,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF151B2E),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.visibility,
                    color: Color(0xFF00E5FF)),
                onPressed: _runMagicEyeCheck,
                tooltip: 'Magic Eye self-test',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF151B2E),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ble.isConnected ? _startMeasurement : null,
              icon: const Icon(Icons.play_arrow, size: 22),
              label: const Text('START TEST',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  SETTINGS DRAWER
  // ============================================================
  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0A0E1A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF00E5FF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.speed, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text('HMP PRO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  Text(
                      _profile.companyName.isEmpty
                          ? 'Settings Menu'
                          : _profile.companyName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _drawerItem(Icons.home, 'Home', () {
                    Navigator.pop(context);
                  }),
                  _drawerItem(Icons.person, 'User Profile', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserProfilePage(
                                profile: _profile,
                                onSave: _saveProfile,
                                onDelete: _deleteProfile,
                              )),
                    );
                  }),
                  _drawerItem(Icons.business, 'Project Settings', () {
                    Navigator.pop(context);
                    _openProjectSettings();
                  }),
                  _drawerItem(Icons.tune, 'Drop Settings', () {
                    Navigator.pop(context);
                    _openDropSettings();
                  }),
                  const Divider(color: Color(0xFF2A3654)),
                  _drawerItem(Icons.phone, 'Contact & Email', () {
                    Navigator.pop(context);
                    _showContactDialog();
                  }),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A3654)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'HMP PRO v3.0\nIndustrial LWD System',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00E5FF)),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: onTap,
    );
  }

  // ============================================================
  //  ACTIONS
  // ============================================================
  Future<void> _saveProfile(UserProfile p) async {
    await _storage.saveProfile(p);
    setState(() => _profile = p);
    _snack('User profile saved successfully');
  }

  Future<void> _deleteProfile() async {
    await _storage.deleteProfile();
    setState(() => _profile = UserProfile());
    _snack('Profile deleted');
  }

  Future<void> _toggleGpsRecording() async {
    final newVal = !_gpsRecordingEnabled;
    setState(() => _gpsRecordingEnabled = newVal);
    await _storage.saveGpsRecordingEnabled(newVal);
    if (newVal) {
      _gps.start();
    } else {
      _gps.stop();
    }
    _snack(newVal ? 'GPS recording ON' : 'GPS recording OFF');
  }

  Future<void> _toggleVoice() async {
    final newVal = !_voiceEnabled;
    setState(() => _voiceEnabled = newVal);
    _voice.setEnabled(newVal);
    await _storage.saveVoiceEnabled(newVal);
  }

  Future<void> _runMagicEyeCheck() async {
    _voice.say('Running self-test');
    setState(() => _eyeState = MagicEyeState.selfTest);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _eyeState =
        _ble.isConnected ? MagicEyeState.blue : MagicEyeState.red);
    _voice.say(_ble.isConnected ? 'Ready' : 'Not connected');
  }

  Future<void> _connectDevice() async {
    _voice.say('Connecting');
    setState(() => _eyeState = MagicEyeState.selfTest);
    final ok = await _ble.scanAndConnect();
    if (!mounted) return;
    setState(() =>
        _eyeState = ok ? MagicEyeState.blue : MagicEyeState.red);
    _voice.say(ok ? 'Connected' : 'Connection failed');
  }

  Future<void> _startMeasurement() async {
    final loc = _activeLocation;
    if (loc == null) {
      _snack('Please select a Location first');
      return;
    }

    _voice.say('First preload');
    setState(() => _eyeState = MagicEyeState.green);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementPage(
          ble: _ble,
          gps: _gps,
          voice: _voice,
          storage: _storage,
          dropSettings: _dropSettings,
          calibration: _calibration,
          site: _activeSite!,
          job: _activeJob!,
          location: loc,
          profile: _profile,
          gpsRecordingEnabled: _gpsRecordingEnabled,
          onComplete: _saveSitesAndActive,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _eyeState = MagicEyeState.blue);
  }

  Future<void> _saveSitesAndActive() async {
    await _storage.saveSites(_sites);
    await _storage
        .saveActive(_activeSiteId, _activeJobId, _activeLocationId);
    if (mounted) setState(() {});
  }

  void _openProjectSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectSettingsPage(
          sites: _sites,
          activeSiteId: _activeSiteId,
          activeJobId: _activeJobId,
          activeLocationId: _activeLocationId,
          profile: _profile,
          onChanged: (sites, sId, jId, lId) async {
            setState(() {
              _sites = sites;
              _activeSiteId = sId;
              _activeJobId = jId;
              _activeLocationId = lId;
            });
            await _saveSitesAndActive();
          },
        ),
      ),
    );
  }

  void _openDropSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DropSettingsPage(
          settings: _dropSettings,
          calibration: _calibration,
          password: '2841998',
          onSave: (s, c) async {
            setState(() {
              _dropSettings = s;
              _calibration = c;
            });
            await _storage.saveDropSettings(s);
            await _storage.saveCalibration(c);
          },
        ),
      ),
    );
  }

  void _showGpsInfo() {
    final pos = _gps.current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('GPS Coordinates'),
          ],
        ),
        content: pos == null
            ? const Text('GPS not ready. Move outdoors.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _gpsRow('Latitude', pos.latitude.toStringAsFixed(6)),
                  _gpsRow('Longitude', pos.longitude.toStringAsFixed(6)),
                  _gpsRow(
                      'Accuracy', '±${pos.accuracy.toStringAsFixed(1)} m'),
                  _gpsRow(
                      'Altitude', '${pos.altitude.toStringAsFixed(1)} m'),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _gpsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Contact & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _contactRow(Icons.phone, '01148221872'),
            const SizedBox(height: 10),
            _contactRow(Icons.email, 'eng.emadeldeen23@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 18),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================
//  EXTENSIONS
// ============================================================
extension FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}