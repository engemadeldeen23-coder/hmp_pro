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
            tooltip: 'Export PDF report',
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
            tooltip: 'Export CSV',
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
            _buildSettlementChart(),
            const SizedBox(height: 16),
            _buildVelocityChart(),
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

  // ---- Settlement chart (INVERTED: plotted as negative going down) ----
  Widget _buildSettlementChart() {
    return _chartCard(
      title: 'SETTLEMENT vs IMPACT TIME',
      unit: UnitsService.deflectionUnit(),
      isSettlement: true,
    );
  }

  Widget _buildVelocityChart() {
    return _chartCard(
      title: 'VELOCITY vs IMPACT TIME',
      unit: UnitsService.velocityUnit(),
      isSettlement: false,
    );
  }

  Widget _chartCard({
    required String title,
    required String unit,
    required bool isSettlement,
  }) {
    double maxY = 0.01;
    double minY = 0;
    double maxX = 1;
    bool hasData = false;

    for (final d in group.drops) {
      final data = isSettlement
          ? d.settlementCurve.map((v) => -v).toList()  // INVERT settlement
          : d.velocityCurve;
      if (data.isEmpty) continue;
      hasData = true;
      for (final v in data) {
        if (v > maxY) maxY = v;
        if (v < minY) minY = v;
      }
      if (d.impactTimeCurve.isNotEmpty) {
        final tmax =
            d.impactTimeCurve.reduce((a, b) => a > b ? a : b);
        if (tmax > maxX) maxX = tmax;
      } else if (data.length > maxX) {
        maxX = data.length.toDouble();
      }
    }

    final pad = (maxY - minY) * 0.15;
    maxY += pad;
    minY -= pad;

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
          Text(title,
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
                    child: Text('No curve data',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            ((maxY - minY) / 4).clamp(0.01, 100),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.grey.shade900,
                          strokeWidth: 1,
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
                            interval:
                                (maxX / 4).clamp(1, 1000).toDouble(),
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
                            reservedSize: 48,
                            interval:
                                ((maxY - minY) / 4).clamp(0.01, 100),
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
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: group.drops
                          .asMap()
                          .entries
                          .where((e) {
                            final data = isSettlement
                                ? e.value.settlementCurve
                                : e.value.velocityCurve;
                            return data.isNotEmpty;
                          })
                          .map((e) {
                        final d = e.value;
                        final idx = e.key;
                        final rawData = isSettlement
                            ? d.settlementCurve
                            : d.velocityCurve;
                        // INVERT settlement
                        final data = isSettlement
                            ? rawData.map((v) => -v).toList()
                            : rawData;
                        final timeData = d.impactTimeCurve;

                        final spots = <FlSpot>[];
                        for (int i = 0; i < data.length; i++) {
                          final x = (timeData.length > i)
                              ? timeData[i]
                              : i.toDouble();
                          spots.add(FlSpot(x, data[i]));
                        }

                        return LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: _colorForIndex(idx),
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
            child: Text('Impact time (ms)  /  $unit',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 9)),
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
                1: FixedColumnWidth(90),
                2: FixedColumnWidth(90),
                3: FixedColumnWidth(90),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(90),
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
                    UnitsService.velocity(d.velocity)
                        .toStringAsFixed(3),
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
                      color: passed
                          ? Colors.greenAccent
                          : Colors.redAccent,
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