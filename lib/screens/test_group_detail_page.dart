import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/export_service.dart';
import '../services/units_service.dart';

class TestGroupDetailPage extends StatelessWidget {
  final TestGroup group;
  final UserProfile profile;
  final String siteName;
  final String jobName;
  final String locationName;

  const TestGroupDetailPage({
    super.key,
    required this.group,
    required this.profile,
    required this.siteName,
    required this.jobName,
    required this.locationName,
  });

  Color _colorForIndex(int i) {
    const colors = [
      Color(0xFF00E5FF),
      Colors.orangeAccent,
      Colors.greenAccent,
    ];
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: Text('Group - ${DateFormat('MMM d, HH:mm').format(group.time)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final file = await ExportService.buildGroupPdf(
                group,
                siteName: siteName,
                jobName: jobName,
                locationName: locationName,
                profile: profile,
              );
              await Share.shareXFiles([XFile(file.path)],
                  subject: 'HMP PRO - Group Report');
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              final file = await ExportService.buildGroupCsv(
                group,
                siteName: siteName,
                jobName: jobName,
                locationName: locationName,
                profile: profile,
              );
              await Share.shareXFiles([XFile(file.path)],
                  subject: 'HMP PRO - Group CSV');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _settlementChartCard(),
            const SizedBox(height: 16),
            _velocityChartCard(),
            const SizedBox(height: 16),
            _buildDataTable(),
            const SizedBox(height: 16),
            _buildAverageTable(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final passed = group.avgEvd >= 40;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: passed
              ? [const Color(0xFF0F2A1A), const Color(0xFF153A22)]
              : [const Color(0xFF2A0F0F), const Color(0xFF3A1515)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: passed ? Colors.greenAccent : Colors.redAccent,
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(passed ? Icons.verified : Icons.cancel,
                  color: passed ? Colors.greenAccent : Colors.redAccent,
                  size: 20),
              const SizedBox(width: 8),
              Text(
                passed ? 'VALID TEST' : 'INVALID TEST',
                style: TextStyle(
                  color: passed ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
              'Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(group.time)),
          _infoRow('Site', siteName),
          _infoRow('Job', jobName),
          _infoRow('Location', locationName),
          _infoRow('Plate diameter',
              '${group.plateDiameterMm.toStringAsFixed(0)} mm'),
          _infoRow('Unit System', UnitsService.system),
          if (group.hasLocation)
            _infoRow('GPS',
                '${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  HMP GL4-STYLE CURVE BUILDER (trimmed to impact period)
  // ============================================================
  List<FlSpot> _buildHmpSpots(Drop d) {
    if (d.settlementCurve.isEmpty) return [];

    final n = d.settlementCurve.length;
    if (n < 2) return [];

    double maxSettle = 0;
    for (final v in d.settlementCurve) {
      if (v.abs() > maxSettle) maxSettle = v.abs();
    }
    if (maxSettle == 0) return [];

    final threshold = maxSettle * 0.05;
    int lastIdx = n - 1;
    for (int i = n - 1; i >= 0; i--) {
      if (d.settlementCurve[i].abs() > threshold) {
        lastIdx = i;
        break;
      }
    }
    if (lastIdx < 1) lastIdx = n - 1;

    final times = d.impactTimeCurve.isNotEmpty
        ? d.impactTimeCurve
        : List<double>.generate(n, (i) => i * 25.0);

    final first = d.settlementCurve.first;
    final last = d.settlementCurve[lastIdx];

    final spots = <FlSpot>[];
    spots.add(const FlSpot(0, 0));

    for (int i = 0; i <= lastIdx; i++) {
      final t = lastIdx > 0 ? i / lastIdx : 0.0;
      final correction = first * (1 - t) + last * t;
      final corrected = (d.settlementCurve[i] - correction).abs();
      final x = i < times.length ? times[i] : i * 25.0;
      spots.add(FlSpot(x, -corrected));
    }

    final lastTime =
        times.length > lastIdx ? times[lastIdx] : (lastIdx * 25.0);
    if (lastTime > 0) {
      spots.add(FlSpot(lastTime, 0));
    }

    return spots;
  }

  Widget _settlementChartCard() {
    double maxSettle = 0;
    double maxX = 1;
    bool hasData = false;

    for (final d in group.drops) {
      if (d.settlementCurve.isNotEmpty) hasData = true;

      double localMaxSettle = 0;
      for (final v in d.settlementCurve) {
        if (v.abs() > localMaxSettle) localMaxSettle = v.abs();
      }
      if (localMaxSettle > maxSettle) maxSettle = localMaxSettle;

      // Only consider impact-time up to last significant point
      final threshold = localMaxSettle * 0.05;
      final times = d.impactTimeCurve.isNotEmpty
          ? d.impactTimeCurve
          : List<double>.generate(
              d.settlementCurve.length, (i) => i * 25.0);

      for (int i = d.settlementCurve.length - 1; i >= 0; i--) {
        if (d.settlementCurve[i].abs() > threshold) {
          final t = i < times.length ? times[i] : i * 25.0;
          if (t > maxX) maxX = t;
          break;
        }
      }
    }

    if (maxSettle == 0) maxSettle = 0.1;
    if (maxX <= 0) maxX = 1;

    final double chartMaxY = maxSettle * 0.25;
    final double chartMinY = -maxSettle * 1.15;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'SETTLEMENT vs IMPACT TIME (${UnitsService.deflectionUnit()})',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: !hasData
                ? Center(
                    child: Text('No curve data',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxSettle / 3,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: value == 0
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade900,
                          strokeWidth: value == 0 ? 1.5 : 1,
                          dashArray: value == 0 ? [4, 4] : null,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: (maxX / 4).clamp(1, 1000).toDouble(),
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: maxSettle / 3,
                            getTitlesWidget: (v, _) => Text(
                              v.abs().toStringAsFixed(2),
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX,
                      minY: chartMinY,
                      maxY: chartMaxY,
                      lineBarsData: group.drops.asMap().entries.map((e) {
                        return LineChartBarData(
                          spots: _buildHmpSpots(e.value),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: _colorForIndex(e.key),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _colorForIndex(e.key).withOpacity(0.15),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(group.drops.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(
                        width: 14, height: 3, color: _colorForIndex(i)),
                    const SizedBox(width: 4),
                    Text('Drop ${i + 1}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          Center(
            child: Text(
                'Impact time (ms)  /  ${UnitsService.deflectionUnit()}',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _velocityChartCard() {
    double maxVel = 0;
    double maxX = 1;
    bool hasData = false;

    for (final d in group.drops) {
      if (d.velocityCurve.isNotEmpty) hasData = true;
      for (final v in d.velocityCurve) {
        if (v.abs() > maxVel) maxVel = v.abs();
      }
      for (final t in d.impactTimeCurve) {
        if (t > maxX) maxX = t;
      }
    }

    if (maxVel == 0) maxVel = 0.1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'VELOCITY vs IMPACT TIME (${UnitsService.velocityUnit()})',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: !hasData
                ? Center(
                    child: Text('No velocity curve data',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxVel / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: value == 0
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade900,
                          strokeWidth: value == 0 ? 1.5 : 1,
                          dashArray: value == 0 ? [4, 4] : null,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: (maxX / 4).clamp(1, 1000).toDouble(),
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: maxVel / 4,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(2),
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX,
                      minY: -maxVel * 1.15,
                      maxY: maxVel * 1.15,
                      lineBarsData: group.drops
                          .asMap()
                          .entries
                          .where((e) => e.value.velocityCurve.isNotEmpty)
                          .map((e) {
                        final d = e.value;
                        final spots = <FlSpot>[];
                        for (int i = 0; i < d.velocityCurve.length; i++) {
                          final x = (d.impactTimeCurve.length > i)
                              ? d.impactTimeCurve[i]
                              : i.toDouble();
                          spots.add(FlSpot(x, d.velocityCurve[i]));
                        }
                        return LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: _colorForIndex(e.key),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(group.drops.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(
                        width: 14, height: 3, color: _colorForIndex(i)),
                    const SizedBox(width: 4),
                    Text('Drop ${i + 1}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          Center(
            child: Text(
                'Impact time (ms)  /  ${UnitsService.velocityUnit()}',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TEST DATA',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(
                  color: const Color(0xFF2A3654), width: 1),
              columnWidths: const {
                0: FixedColumnWidth(70),
                1: FixedColumnWidth(95),
                2: FixedColumnWidth(95),
                3: FixedColumnWidth(95),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(85),
              },
              children: [
                _tableHeader([
                  'Test',
                  'Settle (${UnitsService.deflectionUnit()})',
                  'Velocity (${UnitsService.velocityUnit()})',
                  'EVD (${UnitsService.evdUnit()})',
                  'Acc (g)',
                  'S/V',
                ]),
                ...group.drops.asMap().entries.map((e) {
                  final d = e.value;
                  return _tableRow([
                    'Test ${e.key + 1}',
                    UnitsService.deflection(d.deflection)
                        .toStringAsFixed(3),
                    UnitsService.velocity(d.velocity).toStringAsFixed(3),
                    UnitsService.evd(d.evd).toStringAsFixed(2),
                    d.acceleration.toStringAsFixed(3),
                    d.sOverV.toStringAsFixed(3),
                  ]);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageTable() {
    final passed = group.avgEvd >= 40;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: passed
              ? [
                  Colors.green.shade900.withOpacity(0.4),
                  Colors.green.shade900.withOpacity(0.1),
                ]
              : [
                  Colors.red.shade900.withOpacity(0.4),
                  Colors.red.shade900.withOpacity(0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: passed ? Colors.greenAccent : Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(passed ? Icons.analytics : Icons.warning,
                  color: passed ? Colors.greenAccent : Colors.redAccent,
                  size: 16),
              const SizedBox(width: 8),
              Text(passed ? 'VALID TEST' : 'INVALID TEST',
                  style: TextStyle(
                      color:
                          passed ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _avgRow(
              'EVD Mean (${UnitsService.evdUnit()})',
              UnitsService.evd(group.avgEvd).toStringAsFixed(2)),
          _avgRow(
              'Settlement Mean (${UnitsService.deflectionUnit()})',
              UnitsService.deflection(group.avgDeflection)
                  .toStringAsFixed(4)),
          _avgRow(
              'Velocity Mean (${UnitsService.velocityUnit()})',
              UnitsService.velocity(group.avgVelocity).toStringAsFixed(4)),
          _avgRow('Acceleration Mean (g)',
              group.avgAcceleration.toStringAsFixed(4)),
          _avgRow('S/V Max', group.maxSOverV.toStringAsFixed(4)),
          _avgRow('S/V Mean', group.avgSOverV.toStringAsFixed(4)),
        ],
      ),
    );
  }

  Widget _avgRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> cells) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFF0F1729)),
      children: cells
          .map((c) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(c,
                    style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ))
          .toList(),
    );
  }

  TableRow _tableRow(List<String> cells) {
    return TableRow(
      children: cells
          .map((c) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(c,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.center),
              ))
          .toList(),
    );
  }
}