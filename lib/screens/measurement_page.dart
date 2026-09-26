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

  // Current drop being captured
  double _currentEvd = 0;
  double _currentDef = 0;
  double _currentAcc = 0;
  double _currentVel = 0;
  bool _hasCurrentReading = false;

  // Collected
  final List<double> _testEvds = [];
  final List<double> _testDefs = [];
  final List<Drop> _pendingDrops = [];
  double _avgEvd = 0;

  StreamSubscription? _dataSub;
  bool _busy = false;

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

    // If we're in collecting state, register the drop
    if (_stage == MeasurementStage.collectingPreload) {
      _captureDrop(isPreload: true);
    } else if (_stage == MeasurementStage.collectingTest) {
      _captureDrop(isPreload: false);
    }
  }

  Future<void> _captureDrop({required bool isPreload}) async {
    if (_busy) return;
    _busy = true;

    final pos = widget.gpsRecordingEnabled ? widget.gps.current : null;
    final drop = Drop(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: DateTime.now(),
      dropNumber: _pendingDrops.length + 1,
      isPreload: isPreload,
      evd: _currentEvd,
      deflection: _currentDef,
      acceleration: _currentAcc,
      velocity: _currentVel,
      latitude: pos?.latitude ?? 0,
      longitude: pos?.longitude ?? 0,
      accuracy: pos?.accuracy ?? 0,
      photoPath: null,
      plateRadius: widget.dropSettings.plateRadius,
    );

    _pendingDrops.add(drop);

    HapticFeedback.mediumImpact();

    if (isPreload) {
      setState(() {
        _stage = MeasurementStage.idle;
      });
      widget.voice.say('Preload ${_preloadIndex} complete');
      _preloadIndex++;

      if (_preloadIndex >= _preloadCount) {
        widget.voice.say('Preloads complete. Ready for first test');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _beginTest();
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _beginPreload();
      }
    } else {
      _testEvds.add(_currentEvd);
      _testDefs.add(_currentDef);

      setState(() {
        _stage = MeasurementStage.idle;
      });

      widget.voice.say('Test ${_testIndex} complete, EVD ${_currentEvd.round()}');
      _testIndex++;

      if (_testIndex >= _testCount) {
        // Compute average
        _avgEvd = _testEvds.reduce((a, b) => a + b) / _testEvds.length;
        setState(() => _stage = MeasurementStage.complete);
        widget.voice.say(
            'Test finished. Average EVD ${_avgEvd.round()} megaNewton per square meter');
        await _saveAllDrops();
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
    setState(() => _stage = MeasurementStage.collectingPreload);
  }

  Future<void> _beginTest() async {
    setState(() => _stage = MeasurementStage.readyTest);
    widget.voice.say('Test ${_testIndex + 1}');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _stage = MeasurementStage.collectingTest);
  }

  Future<void> _saveAllDrops() async {
    _location.drops.addAll(_pendingDrops);
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
            // Status header
            _header(),
            const SizedBox(height: 12),

            // Magic eye + instruction
            _instructionCard(),
            const SizedBox(height: 12),

            // Live reading
            _liveCard(),
            const SizedBox(height: 12),

            // Progress / history
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
              style: const TextStyle(
                  color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Plate: ${(_dropSettings.plateRadius * 200).toStringAsFixed(0)} mm',
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  DropSettings get _dropSettings => widget.dropSettings;

  Widget _instructionCard() {
    final (text, color, voice) = _instruction();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          MagicEye(
            state: _stage == MeasurementStage.collectingPreload ||
                    _stage == MeasurementStage.collectingTest
                ? MagicEyeState.green
                : MagicEyeState.blue,
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
        return (
          'Drop the weight now...',
          Colors.greenAccent,
          'RECORDING...'
        );
      case MeasurementStage.readyTest:
        return (
          'Lift the drop weight. Release to perform Test ${_testIndex + 1} of $_testCount.',
          const Color(0xFF00E5FF),
          'TEST ${_testIndex + 1}'
        );
      case MeasurementStage.collectingTest:
        return (
          'Drop the weight now...',
          Colors.greenAccent,
          'RECORDING...'
        );
      case MeasurementStage.complete:
        return (
          'Test complete. Average EVD: ${_avgEvd.toStringAsFixed(1)} MN/m²',
          Colors.greenAccent,
          'TEST FINISHED'
        );
    }
  }

  Widget _liveCard() {
    final passed = _currentEvd >= _dropSettings.targetEvd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasCurrentReading
              ? (passed ? Colors.green.withOpacity(0.5)
                        : Colors.orange.withOpacity(0.5))
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
          // Preloads row
          _progressRow('Preloads', _preloadIndex, _preloadCount,
              Colors.orangeAccent),
          const SizedBox(height: 8),
          // Tests row
          _progressRow('Tests', _testIndex, _testCount, const Color(0xFF00E5FF)),

          if (_testEvds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A3654)),
            const SizedBox(height: 8),
            Text(
              'Test EVDs: ${_testEvds.map((e) => e.toStringAsFixed(1)).join(" | ")}',
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
                    Colors.green.shade900.withOpacity(0.4),
                    Colors.green.shade900.withOpacity(0.1),
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
                  Text('AVERAGE EVD: ${_avgEvd.toStringAsFixed(2)} MN/m²',
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
                  color:
                      filled ? color : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                              color: color.withOpacity(0.4), blurRadius: 6),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}