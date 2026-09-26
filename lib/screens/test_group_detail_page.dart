import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/export_service.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              const Icon(Icons.folder_special,
                  color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'TEST GROUP',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
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

  Widget _buildSettlementChart() {
    return _chartCard(
      title: 'SETTLEMENT CURVES (3 DROPS OVERLAID)',
      unit: 'mm',
      curves: group.drops
          .asMap()
          .entries
          .map((e) => (e.value.settlementCurve, _colorForIndex(e.key)))
          .toList(),
    );
  }

  Widget _buildVelocityChart() {
    return _chartCard(
      title: 'VELOCITY CURVES (3 DROPS OVERLAID)',
      unit: 'm/s',
      curves: group.drops
          .asMap()
          .entries
          .map((e) => (e.value.velocityCurve, _colorForIndex(e.key)))
          .toList(),
    );
  }

  Widget _chartCard({
    required String title,
    required String unit,
    required List<(List<double>, Color)> curves,
  }) {
    double maxY = 0.01;
    double minY = 0;
    int maxX = 1;
    for (final (data, _) in curves) {
      if (data.isEmpty) continue;
      final localMax = data.reduce((a, b) => a > b ? a : b);
      final localMin = data.reduce((a, b) => a < b ? a : b);
      if (localMax > maxY) maxY = localMax;
      if (localMin < minY) minY = localMin;
      if (data.length > maxX) maxX = data.length;
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
            height: 180,
            child: curves.every((c) => c.$1.isEmpty)
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
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval:
                                ((maxY - minY) / 4).clamp(0.01, 100),
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(2),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: maxX.toDouble(),
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: curves
                          .asMap()
                          .entries
                          .where((e) => e.value.$1.isNotEmpty)
                          .map((e) {
                        final (data, color) = e.value;
                        return LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map((x) => FlSpot(x.key.toDouble(), x.value))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: color,
                          barWidth: 2,
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
                        width: 12, height: 3, color: _colorForIndex(i)),
                    const SizedBox(width: 4),
                    Text('Test ${i + 1}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          Center(
            child: Text(unit,
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
          Table(
            border:
                TableBorder.all(color: const Color(0xFF2A3654), width: 1),
            columnWidths: const {
              0: FlexColumnWidth(0.7),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.3),
              5: FlexColumnWidth(1.3),
            },
            children: [
              _tableHeader([
                'Test',
                'Settle (mm)',
                'Velocity',
                'EVD',
                'Acc (g)',
                'S/V',
              ]),
              ...group.drops.asMap().entries.map((e) {
                final d = e.value;
                return _tableRow([
                  '${e.key + 1}',
                  d.deflection.toStringAsFixed(3),
                  d.velocity.toStringAsFixed(3),
                  d.evd.toStringAsFixed(1),
                  d.acceleration.toStringAsFixed(3),
                  d.sOverV.toStringAsFixed(3),
                ]);
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAverageTable() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withValues(alpha: 0.4),
            Colors.green.shade900.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.greenAccent, size: 16),
              SizedBox(width: 8),
              Text('GROUP AVERAGE',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _avgRow(
              'Settlement', '${group.avgDeflection.toStringAsFixed(3)} mm'),
          _avgRow(
              'Velocity', '${group.avgVelocity.toStringAsFixed(3)} m/s'),
          _avgRow('Young\'s Modulus (EVD)',
              '${group.avgEvd.toStringAsFixed(2)} MN/m²'),
          _avgRow('Acceleration',
              '${group.avgAcceleration.toStringAsFixed(3)} g'),
          _avgRow('S/V Ratio',
              '${group.avgSOverV.toStringAsFixed(3)} mm·s/m'),
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
                  color: Colors.greenAccent,
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