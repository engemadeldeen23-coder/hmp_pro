import 'dart:async';
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

  double _currentEvd = 0;
  double _currentDef = 0;
  double _currentAcc = 0;
  double _currentVel = 0;
  bool _hasCurrentReading = false;

  // Live curves
  final List<double> _liveSettlement = [];
  final List<double> _liveVelocity = [];
  bool _collecting = false;

  // Collected test drops only
  final List<Drop> _testDrops = [];
  double _avgEvd = 0;

  StreamSubscription? _dataSub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    _dataSub = widget.ble.dataStream.listen(_onData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.voice.say('Ready for preload 1');
      _beginPreload();
    });
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

    // Capture live curve while collecting
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

    // Only keep test drops
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
      widget.voice.say(
          'Test ${_testIndex + 1} complete, EVD ${_currentEvd.round()}');
      _testIndex++;
      _liveSettlement.clear();
      _liveVelocity.clear();

      if (_testIndex >= _testCount) {
        _avgEvd = _testDrops.map((d) => d.evd).reduce((a, b) => a + b) /
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
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 10),
            _instructionCard(),
            const SizedBox(height: 10),
            _liveCard(),
            const SizedBox(height: 10),
            Expanded(child: _progressAndChartCard()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        children: [
          MagicEye(
            state: _collecting ? MagicEyeState.green : MagicEyeState.blue,
            size: 50,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voice,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
          'Lift weight, release for Preload ${_preloadIndex + 1} of $_preloadCount.',
          Colors.orangeAccent,
          'PRELOAD ${_preloadIndex + 1}'
        );
      case MeasurementStage.collectingPreload:
        return ('Drop the weight now...', Colors.greenAccent, 'RECORDING...');
      case MeasurementStage.readyTest:
        return (
          'Lift weight, release for Test ${_testIndex + 1} of $_testCount.',
          const Color(0xFF00E5FF),
          'TEST ${_testIndex + 1}'
        );
      case MeasurementStage.collectingTest:
        return ('Drop the weight now...', Colors.greenAccent, 'RECORDING...');
      case MeasurementStage.complete:
        return (
          'Test complete. Avg EVD: ${_avgEvd.toStringAsFixed(1)} MN/m²',
          Colors.greenAccent,
          'TEST FINISHED'
        );
    }
  }

  Widget _liveCard() {
    final passed = _currentEvd >= widget.dropSettings.targetEvd;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasCurrentReading
              ? (passed
                  ? Colors.green.withOpacity(0.5)
                  : Colors.orange.withOpacity(0.5))
              : const Color(0xFF2A3654),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metric('EVD', _currentEvd.toStringAsFixed(1), 'MN/m²',
              const Color(0xFF00E5FF), 28),
          _metric('DEFL', _currentDef.toStringAsFixed(3), 'mm',
              Colors.orangeAccent, 18),
          _metric('VEL', _currentVel.toStringAsFixed(3), 'm/s',
              Colors.greenAccent, 14),
          _metric('ACC', _currentAcc.toStringAsFixed(2), 'g',
              Colors.purpleAccent, 14),
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
                fontSize: 9,
                letterSpacing: 1)),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: s,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
        Text(u,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
      ],
    );
  }

  // ============================================================
  //  PROGRESS + LIVE SETTLEMENT CHART
  // ============================================================
  Widget _progressAndChartCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preloads row
          _progressRow('Preloads', _preloadIndex, _preloadCount,
              Colors.orangeAccent),
          const SizedBox(height: 6),

          // Tests row
          _progressRow(
              'Tests', _testIndex, _testCount, const Color(0xFF00E5FF)),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFF2A3654), height: 1),
          const SizedBox(height: 6),

          // Live settlement curve header
          Row(
            children: [
              const Icon(Icons.show_chart,
                  color: Color(0xFF00E5FF), size: 14),
              const SizedBox(width: 6),
              const Text('LIVE SETTLEMENT CURVE',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_liveSettlement.isNotEmpty)
                Text('${_liveSettlement.length} pts',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 6),

          // Live settlement chart
          Expanded(child: _buildLiveChart()),
        ],
      ),
    );
  }

  Widget _buildLiveChart() {
    // If no data yet, show placeholder
    if (_liveSettlement.isEmpty) {
      return Center(
        child: Text(
          _collecting ? 'Waiting for drop...' : 'Ready for next drop',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    // Compute Y range
    double maxY = 0.01;
    double minY = 0;
    for (final v in _liveSettlement) {
      if (v > maxY) maxY = v;
      if (v < minY) minY = v;
    }
    final pad = (maxY - minY) * 0.15;
    maxY += pad;
    minY -= pad;

    final spots = <FlSpot>[];
    for (int i = 0; i < _liveSettlement.length; i++) {
      spots.add(FlSpot(i.toDouble(), _liveSettlement[i]));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.005, 100),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade900,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: ((maxY - minY) / 4).clamp(0.005, 100),
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(2),
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 9),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (_liveSettlement.length - 1).toDouble().clamp(10, 500),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: const Color(0xFF00E5FF),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5FF).withOpacity(0.35),
                  const Color(0xFF00E5FF).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
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
        const SizedBox(height: 4),
        Row(
          children: List.generate(total, (i) {
            final filled = i < current;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}