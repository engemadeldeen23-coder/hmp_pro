import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'units_service.dart';

class ExportService {
  // ============================================================
  //  SIMPLE CSV (drops)
  // ============================================================
  static Future<File> buildCsv(
    List<Drop> drops,
    String title, {
    UserProfile? profile,
  }) async {
    final rows = <List<dynamic>>[];
    if (profile != null && profile.companyName.isNotEmpty) {
      rows.add([profile.companyName]);
      rows.add([]);
    }
    rows.add([title]);
    rows.add([]);
    rows.add([
      'Drop #',
      'Date',
      'Time',
      'EVD (${UnitsService.evdUnit()})',
      'Deflection (${UnitsService.deflectionUnit()})',
      'Acceleration (g)',
      'Velocity (${UnitsService.velocityUnit()})',
      'S/V',
    ]);
    for (final d in drops) {
      rows.add([
        d.dropNumber,
        DateFormat('yyyy-MM-dd').format(d.time),
        DateFormat('HH:mm:ss').format(d.time),
        UnitsService.evd(d.evd).toStringAsFixed(2),
        UnitsService.deflection(d.deflection).toStringAsFixed(4),
        d.acceleration.toStringAsFixed(4),
        UnitsService.velocity(d.velocity).toStringAsFixed(4),
        d.sOverV.toStringAsFixed(4),
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_PRO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await f.writeAsString(csv);
    return f;
  }

  // ============================================================
  //  GROUP CSV - with curves
  // ============================================================
  static Future<File> buildGroupCsv(
    TestGroup group, {
    required String siteName,
    required String jobName,
    required String locationName,
    UserProfile? profile,
  }) async {
    final rows = <List<dynamic>>[];

    if (profile != null && profile.companyName.isNotEmpty) {
      rows.add([profile.companyName]);
      rows.add([]);
    }

    rows.add(['HMP PRO - TEST GROUP REPORT']);
    rows.add([]);
    rows.add(['Site', siteName]);
    rows.add(['Job', jobName]);
    rows.add(['Location', locationName]);
    rows.add(['Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(group.time)]);
    rows.add(['Plate Diameter', '${group.plateDiameterMm.toStringAsFixed(0)} mm']);
    rows.add(['Unit System', UnitsService.system]);
    if (group.hasLocation) {
      rows.add(['GPS', '${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}']);
    }
    rows.add([]);

    // Test summary
    rows.add(['TEST DATA']);
    rows.add([
      'Test #',
      'Time',
      'Settlement (${UnitsService.deflectionUnit()})',
      'Velocity (${UnitsService.velocityUnit()})',
      'EVD (${UnitsService.evdUnit()})',
      'Acceleration (g)',
      'S/V',
    ]);
    for (final d in group.drops) {
      rows.add([
        d.dropNumber,
        DateFormat('HH:mm:ss').format(d.time),
        UnitsService.deflection(d.deflection).toStringAsFixed(4),
        UnitsService.velocity(d.velocity).toStringAsFixed(4),
        UnitsService.evd(d.evd).toStringAsFixed(2),
        d.acceleration.toStringAsFixed(4),
        d.sOverV.toStringAsFixed(4),
      ]);
    }

    // Averages
    rows.add([]);
    rows.add(['GROUP AVERAGES']);
    rows.add(['Avg Settlement (${UnitsService.deflectionUnit()})',
        UnitsService.deflection(group.avgDeflection).toStringAsFixed(4)]);
    rows.add(['Avg Velocity (${UnitsService.velocityUnit()})',
        UnitsService.velocity(group.avgVelocity).toStringAsFixed(4)]);
    rows.add(['Avg EVD (${UnitsService.evdUnit()})',
        UnitsService.evd(group.avgEvd).toStringAsFixed(2)]);
    rows.add(['Avg Acceleration (g)', group.avgAcceleration.toStringAsFixed(4)]);
    rows.add(['S/V Max', group.maxSOverV.toStringAsFixed(4)]);
    rows.add(['S/V Mean', group.avgSOverV.toStringAsFixed(4)]);

    // ============================================================
    //  SETTLEMENT CURVE TABLE
    // ============================================================
    rows.add([]);
    rows.add([]);
    rows.add(['CURVE DATA - SETTLEMENT vs IMPACT TIME (${UnitsService.deflectionUnit()})']);
    rows.add([]);

    final settleHeader = <dynamic>['Impact Time (ms)'];
    for (int i = 0; i < group.drops.length; i++) {
      settleHeader.add('Drop ${i + 1}');
    }
    rows.add(settleHeader);

    int maxSettleLen = 0;
    for (final d in group.drops) {
      if (d.settlementCurve.length > maxSettleLen) maxSettleLen = d.settlementCurve.length;
    }
    for (int i = 0; i < maxSettleLen; i++) {
      final row = <dynamic>[];
      double timeMs = 0;
      for (final d in group.drops) {
        if (d.impactTimeCurve.length > i) {
          timeMs = d.impactTimeCurve[i];
          break;
        }
      }
      row.add(timeMs.toStringAsFixed(0));
      for (final d in group.drops) {
        if (d.settlementCurve.length > i) {
          row.add(UnitsService.deflection(d.settlementCurve[i]).toStringAsFixed(4));
        } else {
          row.add('');
        }
      }
      rows.add(row);
    }

    // ============================================================
    //  VELOCITY CURVE TABLE
    // ============================================================
    rows.add([]);
    rows.add([]);
    rows.add(['CURVE DATA - VELOCITY vs IMPACT TIME (${UnitsService.velocityUnit()})']);
    rows.add([]);

    final velHeader = <dynamic>['Impact Time (ms)'];
    for (int i = 0; i < group.drops.length; i++) {
      velHeader.add('Drop ${i + 1}');
    }
    rows.add(velHeader);

    int maxVelLen = 0;
    for (final d in group.drops) {
      if (d.velocityCurve.length > maxVelLen) maxVelLen = d.velocityCurve.length;
    }
    for (int i = 0; i < maxVelLen; i++) {
      final row = <dynamic>[];
      double timeMs = 0;
      for (final d in group.drops) {
        if (d.impactTimeCurve.length > i) {
          timeMs = d.impactTimeCurve[i];
          break;
        }
      }
      row.add(timeMs.toStringAsFixed(0));
      for (final d in group.drops) {
        if (d.velocityCurve.length > i) {
          row.add(UnitsService.velocity(d.velocityCurve[i]).toStringAsFixed(4));
        } else {
          row.add('');
        }
      }
      rows.add(row);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_GROUP_${DateFormat('yyyyMMdd_HHmmss').format(group.time)}.csv');
    await f.writeAsString(csv);
    return f;
  }

  // ============================================================
  //  SIMPLE PDF
  // ============================================================
  static Future<File> buildPdf(
    List<Drop> drops,
    String title, {
    UserProfile? profile,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final widgets = <pw.Widget>[];
          if (profile != null && profile.companyName.isNotEmpty) {
            widgets.add(pw.Text(profile.companyName,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 8));
          }
          widgets.add(pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 12));
          widgets.add(pw.Table.fromTextArray(
            headers: ['Drop', 'Time', 'EVD', 'Defl', 'Acc', 'Vel', 'S/V'],
            data: drops
                .map((d) => [
                      d.dropNumber.toString(),
                      DateFormat('HH:mm:ss').format(d.time),
                      UnitsService.evd(d.evd).toStringAsFixed(1),
                      UnitsService.deflection(d.deflection).toStringAsFixed(3),
                      d.acceleration.toStringAsFixed(3),
                      UnitsService.velocity(d.velocity).toStringAsFixed(3),
                      d.sOverV.toStringAsFixed(3),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ));
          return widgets;
        },
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_PRO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  // ============================================================
  //  GROUP PDF (with curves drawn as line charts)
  // ============================================================
  static Future<File> buildGroupPdf(
    TestGroup group, {
    required String siteName,
    required String jobName,
    required String locationName,
    UserProfile? profile,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final w = <pw.Widget>[];

          // Header
          if (profile != null && profile.companyName.isNotEmpty) {
            w.add(pw.Text(profile.companyName,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)));
            if (profile.engineerName.isNotEmpty) {
              w.add(pw.Text('Engineer: ${profile.engineerName}',
                  style: const pw.TextStyle(fontSize: 10)));
            }
            w.add(pw.SizedBox(height: 6));
          }
          w.add(pw.Divider());
          w.add(pw.Text('HMP PRO - TEST GROUP REPORT',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 10));

          // Info
          w.add(pw.Text('Site: $siteName',
              style: const pw.TextStyle(fontSize: 10)));
          w.add(pw.Text('Job: $jobName',
              style: const pw.TextStyle(fontSize: 10)));
          w.add(pw.Text('Location: $locationName',
              style: const pw.TextStyle(fontSize: 10)));
          w.add(pw.Text(
              'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(group.time)}',
              style: const pw.TextStyle(fontSize: 10)));
          w.add(pw.Text(
              'Plate Diameter: ${group.plateDiameterMm.toStringAsFixed(0)} mm',
              style: const pw.TextStyle(fontSize: 10)));
          w.add(pw.Text('Unit System: ${UnitsService.system}',
              style: const pw.TextStyle(fontSize: 10)));
          if (group.hasLocation) {
            w.add(pw.Text(
                'GPS: ${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}',
                style: const pw.TextStyle(fontSize: 10)));
          }
          w.add(pw.SizedBox(height: 14));

          // Test data table
          w.add(pw.Text('TEST DATA',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(pw.Table.fromTextArray(
            headers: [
              'Test',
              'Settle (${UnitsService.deflectionUnit()})',
              'Velocity (${UnitsService.velocityUnit()})',
              'EVD (${UnitsService.evdUnit()})',
              'Acc (g)',
              'S/V',
            ],
            data: group.drops
                .map((d) => [
                      'Test ${d.dropNumber}',
                      UnitsService.deflection(d.deflection)
                          .toStringAsFixed(4),
                      UnitsService.velocity(d.velocity)
                          .toStringAsFixed(4),
                      UnitsService.evd(d.evd).toStringAsFixed(2),
                      d.acceleration.toStringAsFixed(4),
                      d.sOverV.toStringAsFixed(4),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ));

          w.add(pw.SizedBox(height: 14));

          // Averages
          w.add(pw.Text('GROUP AVERAGES',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              [
                'Settlement Mean (${UnitsService.deflectionUnit()})',
                UnitsService.deflection(group.avgDeflection)
                    .toStringAsFixed(4)
              ],
              [
                'Velocity Mean (${UnitsService.velocityUnit()})',
                UnitsService.velocity(group.avgVelocity).toStringAsFixed(4)
              ],
              [
                'EVD Mean (${UnitsService.evdUnit()})',
                UnitsService.evd(group.avgEvd).toStringAsFixed(2)
              ],
              [
                'Acceleration Mean (g)',
                group.avgAcceleration.toStringAsFixed(4)
              ],
              ['S/V Max', group.maxSOverV.toStringAsFixed(4)],
              ['S/V Mean', group.avgSOverV.toStringAsFixed(4)],
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green100),
            cellAlignment: pw.Alignment.centerLeft,
          ));

          // ============================================================
          //  CHARTS DRAWN AS LINE PLOTS
          // ============================================================
          w.add(pw.SizedBox(height: 20));
          w.add(pw.Text('SETTLEMENT vs IMPACT TIME (INVERTED)',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(_buildPdfCurveChart(
            drops: group.drops,
            isSettlement: true,
            unit: UnitsService.deflectionUnit(),
          ));

          w.add(pw.SizedBox(height: 16));
          w.add(pw.Text('VELOCITY vs IMPACT TIME',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(_buildPdfCurveChart(
            drops: group.drops,
            isSettlement: false,
            unit: UnitsService.velocityUnit(),
          ));

          return w;
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_GROUP_${DateFormat('yyyyMMdd_HHmmss').format(group.time)}.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  // ============================================================
  //  PDF CURVE CHART BUILDER (custom painter)
  // ============================================================
  static pw.Widget _buildPdfCurveChart({
    required List<Drop> drops,
    required bool isSettlement,
    required String unit,
  }) {
    const double width = 500;
    const double height = 200;

    // Compute range
    double maxY = 0.01;
    double minY = 0;
    double maxX = 1;
    for (final d in drops) {
      final data = isSettlement
          ? d.settlementCurve.map((v) => -v).toList()
          : d.velocityCurve;
      for (final v in data) {
        if (v > maxY) maxY = v;
        if (v < minY) minY = v;
      }
      for (final t in d.impactTimeCurve) {
        if (t > maxX) maxX = t;
      }
    }
    final pad = (maxY - minY) * 0.15;
    maxY += pad;
    minY -= pad;
    if (maxY == minY) maxY = minY + 1;

    const colors = [PdfColors.cyan700, PdfColors.orange700, PdfColors.green700];

    return pw.Container(
      height: height,
      width: width,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(width, height),
        painter: (PdfGraphics canvas, PdfPoint size) {
          // Draw axes
          canvas
            ..setColor(PdfColors.black)
            ..setLineWidth(0.5)
            ..moveTo(30, 10)
            ..lineTo(30, size.y - 20)
            ..moveTo(30, size.y - 20)
            ..lineTo(size.x - 10, size.y - 20)
            ..strokePath();

          // Draw each drop curve
          for (int di = 0; di < drops.length; di++) {
            final d = drops[di];
            final rawData = isSettlement ? d.settlementCurve : d.velocityCurve;
            if (rawData.isEmpty) continue;

            final data = isSettlement
                ? rawData.map((v) => -v).toList()
                : rawData;
            final times = d.impactTimeCurve.isNotEmpty
                ? d.impactTimeCurve
                : List.generate(data.length, (i) => i.toDouble());

            final color = colors[di % colors.length];
            canvas
              ..setColor(color)
              ..setLineWidth(1.2);

            bool firstPoint = true;
            for (int i = 0; i < data.length && i < times.length; i++) {
              final nx = (times[i] / maxX);
              final ny = (data[i] - minY) / (maxY - minY);
              // Map to canvas coords
              final px = 30 + nx * (size.x - 40);
              final py = 10 + (1 - ny) * (size.y - 30);

              if (firstPoint) {
                canvas.moveTo(px, py);
                firstPoint = false;
              } else {
                canvas.lineTo(px, py);
              }
            }
            canvas.strokePath();
          }
        },
      ),
    );
  }
}