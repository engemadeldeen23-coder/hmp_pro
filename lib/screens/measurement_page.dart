import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/ble_service.dart';
import '../services/gps_service.dart';
import '../services/voice_service.dart';
import '../services/storage_service.dart';
import '../widgets/magic_eye.dart';

enum MeasurementStage {
  idle,
  readyPreload,
  collectingPreload,
  readyTest,
  collectingTest,
  complete,
}

class MeasurementPage extends StatefulWidget {
  final BleService ble;
  final GpsService gps;
  final VoiceService voice;
  final StorageService storage;
  final DropSettings dropSettings;
  final Calibration calibration;
  final Site site;
  final Job job;
  final Location location;
  final UserProfile profile;
  final bool gpsRecordingEnabled;
  final Future<void> Function() onComplete;

  const MeasurementPage({
    super.key,
    required this.ble,
    required this.gps,
    required this.voice,
    required this.storage,
    required this.dropSettings,
    required this.calibration,
    required this.site,
    required this.job,
    required this.location,
    required this.profile,
    required this.gpsRecordingEnabled,
    required this.onComplete,
  });

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage> {
  static const int _preloadCount = 3;
  static const int _testCount = 3;

  late Location _location;

  MeasurementStage _stage = MeasurementStage.idle;
  int _preloadIndex = 0;
  int _testIndex = 0;

  // Live values
  double _currentEvd = 0;
  double _currentDef = 0;
  double _currentAcc = 0;
  double _currentVel = 0;
  bool _hasCurrentReading = false;

  // Curves (live, cleared on each new drop)
  final List<double> _liveSettlement = [];
  final List<double> _liveVelocity = [];
  bool _collecting = false;

  // Collected TEST drops only (preloads discarded)
  final List<Drop> _testDrops = [];
  double _avgEvd = 0;

  StreamSubscription? _dataSub;
  bool _busy = false;

  // Curve capture helper
  DateTime? _curveStart;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    _dataSub = widget.ble.dataStream.listen(_onData);
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginPreload());
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  void _onData(Map<String, dynamic> m) {
    if (!mounted) return;
    final type = m['type'] as String?;
    if (type == 'hb') return;

    final evd = (m['evd'] ?? 0).toDouble() * widget.calibration.factor;
    final def = (m['def'] ?? 0).toDouble();
    final acc = (m['acc'] ?? 0).toDouble();
    final vel = (m['vel'] ?? 0).toDouble();

    setState(() {
      _currentEvd = evd;
      _currentDef = def;
      _currentAcc = acc;
      _currentVel = vel;
      _hasCurrentReading = true;
    });

    // Capture curves during collection window
    if (_collecting) {
      _liveSettlement.add(def);
      _liveVelocity.add(vel);
      if (_liveSettlement.length > 200) {
        _liveSettlement.removeAt(0);
        _liveVelocity.removeAt(0);
      }
    }

    // Detect drop during collection
    if ((_stage == MeasurementStage.collectingPreload ||
            _stage == MeasurementStage.collectingTest) &&
        def > 0.01) {
      _captureDrop(isPreload: _stage == MeasurementStage.collectingPreload);
    }
  }

  Future<void> _captureDrop({required bool isPreload}) async {
    if (_busy) return;
    _busy = true;
    _collecting = false;

    // Only keep test drops (drop preloads per requirements)
    if (!isPreload) {
      final drop = Drop(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        time: DateTime.now(),
        dropNumber: _testDrops.length + 1,
        evd: _currentEvd,
        deflection: _currentDef,
        acceleration: _currentAcc,
        velocity: _currentVel,
        settlementCurve: List<double>.from(_liveSettlement),
        velocityCurve: List<double>.from(_liveVelocity),
      );
      _testDrops.add(drop);
    }

    HapticFeedback.mediumImpact();

    if (isPreload) {
      setState(() => _stage = MeasurementStage.idle);
      widget.voice.say('Preload ${_preloadIndex + 1} complete');
      _preloadIndex++;
      _liveSettlement.clear();
      _liveVelocity.clear();

      if (_preloadIndex >= _preloadCount) {
        widget.voice.say('Preloads complete. Ready for first test');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _beginTest();
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _beginPreload();
      }
    } else {
      setState(() => _stage = MeasurementStage.idle);
      widget.voice
          .say('Test ${_testIndex + 1} complete, EVD ${_currentEvd.round()}');
      _testIndex++;
      _liveSettlement.clear();
      _liveVelocity.clear();

      if (_testIndex >= _testCount) {
        _avgEvd =
            _testDrops.map((d) => d.evd).reduce((a, b) => a + b) /
                _testDrops.length;
        setState(() => _stage = MeasurementStage.complete);
        widget.voice.say(
            'Test finished. Average EVD ${_avgEvd.round()} megaNewton per square meter');
        await _saveGroup();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _beginTest();
      }
    }
    _busy = false;
  }

  Future<void> _beginPreload() async {
    setState(() => _stage = MeasurementStage.readyPreload);
    widget.voice.say('Preload ${_preloadIndex + 1}');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _liveSettlement.clear();
    _liveVelocity.clear();
    _collecting = true;
    setState(() => _stage = MeasurementStage.collectingPreload);
  }

  Future<void> _beginTest() async {
    setState(() => _stage = MeasurementStage.readyTest);
    widget.voice.say('Test ${_testIndex + 1}');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _liveSettlement.clear();
    _liveVelocity.clear();
    _collecting = true;
    setState(() => _stage = MeasurementStage.collectingTest);
  }

  Future<void> _saveGroup() async {
    final pos = widget.gpsRecordingEnabled ? widget.gps.current : null;
    final group = TestGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now(),
      drops: List.from(_testDrops),
      plateRadius: widget.dropSettings.plateRadius,
      latitude: pos?.latitude ?? 0,
      longitude: pos?.longitude ?? 0,
      accuracy: pos?.accuracy ?? 0,
    );
    _location.testGroups.add(group);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Text('Measurement (${_location.name})'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 12),
            _instructionCard(),
            const SizedBox(height: 12),
            _liveCard(),
            const SizedBox(height: 12),
            Expanded(child: _progressCard()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.site.name} / ${widget.job.name} / ${_location.name}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Plate: ${widget.dropSettings.plateDiameterMm.toStringAsFixed(0)} mm',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _instructionCard() {
    final (text, color, voice) = _instruction();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          MagicEye(
            state: _collecting ? MagicEyeState.green : MagicEyeState.blue,
            size: 60,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, String) _instruction() {
    switch (_stage) {
      case MeasurementStage.idle:
        return ('Please wait...', Colors.grey, 'WAIT');
      case MeasurementStage.readyPreload:
        return (
          'Lift the drop weight. Release to perform Preload ${_preloadIndex + 1} of $_preloadCount.',
          Colors.orangeAccent,
          'PRELOAD ${_preloadIndex + 1}'
        );
      case MeasurementStage.collectingPreload:
        return ('Drop the weight now...', Colors.greenAccent, 'RECORDING...');
      case MeasurementStage.readyTest:
        return (
          'Lift the drop weight. Release to perform Test ${_testIndex + 1} of $_testCount.',
          const Color(0xFF00E5FF),
          'TEST ${_testIndex + 1}'
        );
      case MeasurementStage.collectingTest:
        return ('Drop the weight now...', Colors.greenAccent, 'RECORDING...');
      case MeasurementStage.complete:
        return (
          'Test complete. Average EVD: ${_avgEvd.toStringAsFixed(1)} MN/m²',
          Colors.greenAccent,
          'TEST FINISHED'
        );
    }
  }

  Widget _liveCard() {
    final passed = _currentEvd >= widget.dropSettings.targetEvd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasCurrentReading
              ? (passed
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.orange.withValues(alpha: 0.5))
              : const Color(0xFF2A3654),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('EVD', _currentEvd.toStringAsFixed(1), 'MN/m²',
                  const Color(0xFF00E5FF), 38),
              _metric('DEFL', _currentDef.toStringAsFixed(3), 'mm',
                  Colors.orangeAccent, 22),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _smallMetric('Acc', '${_currentAcc.toStringAsFixed(3)} g',
                  Colors.purpleAccent),
              _smallMetric('Vel', '${_currentVel.toStringAsFixed(3)} m/s',
                  Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String l, String v, String u, Color c, double s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                letterSpacing: 1.5)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(v,
                style: TextStyle(
                    color: c,
                    fontSize: s,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
            const SizedBox(width: 4),
            Text(u,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _smallMetric(String l, String v, Color c) {
    return Row(
      children: [
        Text('$l: ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _progressCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SESSION PROGRESS',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _progressRow('Preloads', _preloadIndex, _preloadCount,
              Colors.orangeAccent),
          const SizedBox(height: 8),
          _progressRow(
              'Tests', _testIndex, _testCount, const Color(0xFF00E5FF)),
          if (_testDrops.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3654)),
            const SizedBox(height: 8),
            Text(
              'Test EVDs: ${_testDrops.map((e) => e.evd.toStringAsFixed(1)).join(" | ")}',
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ],
          if (_stage == MeasurementStage.complete) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade900.withValues(alpha: 0.4),
                    Colors.green.shade900.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                      'AVERAGE EVD: ${_avgEvd.toStringAsFixed(2)} MN/m²',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progressRow(String label, int current, int total, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$current / $total',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(total, (i) {
            final filled = i < current;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}