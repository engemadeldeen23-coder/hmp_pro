import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class ExportService {
  // ============================================================
  //  SIMPLE CSV (list of drops)
  // ============================================================
  static Future<File> buildCsv(
    List<Drop> drops,
    String title, {
    UserProfile? profile,
  }) async {
    final rows = <List<dynamic>>[];

    if (profile != null && profile.companyName.isNotEmpty) {
      rows.add([profile.companyName]);
      if (profile.engineerName.isNotEmpty) {
        rows.add(['Engineer: ${profile.engineerName}']);
      }
      rows.add([]);
    }

    rows.add([title]);
    rows.add([]);
    rows.add([
      'Drop #',
      'Date',
      'Time',
      'EVD (MN/m²)',
      'Deflection (mm)',
      'Acceleration (g)',
      'Velocity (m/s)',
      'S/V (mm·s/m)',
    ]);

    for (final d in drops) {
      rows.add([
        d.dropNumber,
        DateFormat('yyyy-MM-dd').format(d.time),
        DateFormat('HH:mm:ss').format(d.time),
        d.evd.toStringAsFixed(2),
        d.deflection.toStringAsFixed(4),
        d.acceleration.toStringAsFixed(4),
        d.velocity.toStringAsFixed(4),
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
  //  GROUP CSV - includes full curve data
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
      if (profile.engineerName.isNotEmpty) {
        rows.add(['Engineer: ${profile.engineerName}']);
      }
      rows.add([]);
    }

    rows.add(['HMP PRO - TEST GROUP REPORT']);
    rows.add([]);
    rows.add(['Site', siteName]);
    rows.add(['Job', jobName]);
    rows.add(['Location', locationName]);
    rows.add([
      'Date',
      DateFormat('yyyy-MM-dd HH:mm:ss').format(group.time)
    ]);
    rows.add([
      'Plate Diameter',
      '${group.plateDiameterMm.toStringAsFixed(0)} mm'
    ]);
    if (group.hasLocation) {
      rows.add([
        'GPS',
        '${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}'
      ]);
    }
    rows.add([]);

    // Summary table
    rows.add(['TEST DATA']);
    rows.add([
      'Test #',
      'Time',
      'Settlement (mm)',
      'Velocity (m/s)',
      'EVD (MN/m²)',
      'Acceleration (g)',
      'S/V (mm·s/m)',
    ]);
    for (final d in group.drops) {
      rows.add([
        d.dropNumber,
        DateFormat('HH:mm:ss').format(d.time),
        d.deflection.toStringAsFixed(4),
        d.velocity.toStringAsFixed(4),
        d.evd.toStringAsFixed(2),
        d.acceleration.toStringAsFixed(4),
        d.sOverV.toStringAsFixed(4),
      ]);
    }

    rows.add([]);
    rows.add(['GROUP AVERAGES']);
    rows.add(['Avg Settlement (mm)', group.avgDeflection.toStringAsFixed(4)]);
    rows.add(['Avg Velocity (m/s)', group.avgVelocity.toStringAsFixed(4)]);
    rows.add(['Avg EVD (MN/m²)', group.avgEvd.toStringAsFixed(2)]);
    rows.add(['Avg Acceleration (g)', group.avgAcceleration.toStringAsFixed(4)]);
    rows.add(['S/V Max (mm·s/m)', group.maxSOverV.toStringAsFixed(4)]);
    rows.add(['S/V Mean (mm·s/m)', group.avgSOverV.toStringAsFixed(4)]);

    // ============================================================
    //  CURVE DATA - Settlement vs Impact Time
    // ============================================================
    rows.add([]);
    rows.add([]);
    rows.add(['CURVE DATA - SETTLEMENT vs IMPACT TIME (mm)']);
    rows.add([]);

    // Header row: Impact Time | Drop 1 | Drop 2 | Drop 3
    final curveHeader = <dynamic>['Impact Time (ms)'];
    for (int i = 0; i < group.drops.length; i++) {
      curveHeader.add('Drop ${i + 1} (mm)');
    }
    rows.add(curveHeader);

    // Find max curve length
    int maxLen = 0;
    for (final d in group.drops) {
      if (d.settlementCurve.length > maxLen) maxLen = d.settlementCurve.length;
    }

    // Emit curve data row by row using impactTimeCurve
    for (int i = 0; i < maxLen; i++) {
      final row = <dynamic>[];
      // Get time from first drop that has this index
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
          row.add(d.settlementCurve[i].toStringAsFixed(4));
        } else {
          row.add('');
        }
      }
      rows.add(row);
    }

    // ============================================================
    //  CURVE DATA - Velocity vs Impact Time
    // ============================================================
    rows.add([]);
    rows.add([]);
    rows.add(['CURVE DATA - VELOCITY vs IMPACT TIME (m/s)']);
    rows.add([]);

    final velHeader = <dynamic>['Impact Time (ms)'];
    for (int i = 0; i < group.drops.length; i++) {
      velHeader.add('Drop ${i + 1} (m/s)');
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
          row.add(d.velocityCurve[i].toStringAsFixed(4));
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
                      d.evd.toStringAsFixed(1),
                      d.deflection.toStringAsFixed(3),
                      d.acceleration.toStringAsFixed(3),
                      d.velocity.toStringAsFixed(3),
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
  //  GROUP PDF - with curve data tables + charts
  // ============================================================
  static Future<File> buildGroupPdf(
    TestGroup group, {
    required String siteName,
    required String jobName,
    required String locationName,
    UserProfile? profile,
  }) async {
    final pdf = pw.Document();

    // Precompute curve data for PDF tables
    int maxSettleLen = 0;
    for (final d in group.drops) {
      if (d.settlementCurve.length > maxSettleLen) {
        maxSettleLen = d.settlementCurve.length;
      }
    }
    int maxVelLen = 0;
    for (final d in group.drops) {
      if (d.velocityCurve.length > maxVelLen) {
        maxVelLen = d.velocityCurve.length;
      }
    }

    // Settlement curve table data
    final settleTableData = <List<String>>[];
    for (int i = 0; i < maxSettleLen; i++) {
      final row = <String>[];
      double timeMs = 0;
      for (final d in group.drops) {
        if (d.impactTimeCurve.length > i) {
          timeMs = d.impactTimeCurve[i];
          break;
        }
      }
      row.add(timeMs.toStringAsFixed(0));
      for (final d in group.drops) {
        row.add(d.settlementCurve.length > i
            ? d.settlementCurve[i].toStringAsFixed(4)
            : '');
      }
      settleTableData.add(row);
    }

    // Velocity curve table data
    final velTableData = <List<String>>[];
    for (int i = 0; i < maxVelLen; i++) {
      final row = <String>[];
      double timeMs = 0;
      for (final d in group.drops) {
        if (d.impactTimeCurve.length > i) {
          timeMs = d.impactTimeCurve[i];
          break;
        }
      }
      row.add(timeMs.toStringAsFixed(0));
      for (final d in group.drops) {
        row.add(d.velocityCurve.length > i
            ? d.velocityCurve[i].toStringAsFixed(4)
            : '');
      }
      velTableData.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final w = <pw.Widget>[];

          // ---- Header ----
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

          // ---- Project Info ----
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
          if (group.hasLocation) {
            w.add(pw.Text(
                'GPS: ${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}',
                style: const pw.TextStyle(fontSize: 10)));
          }
          w.add(pw.SizedBox(height: 14));

          // ---- Test Data Table ----
          w.add(pw.Text('TEST DATA',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(pw.Table.fromTextArray(
            headers: [
              'Test',
              'Settle (mm)',
              'Velocity (m/s)',
              'EVD (MN/m²)',
              'Acc (g)',
              'S/V (mm·s/m)',
            ],
            data: group.drops
                .map((d) => [
                      'Test ${d.dropNumber}',
                      d.deflection.toStringAsFixed(4),
                      d.velocity.toStringAsFixed(4),
                      d.evd.toStringAsFixed(2),
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

          // ---- Averages ----
          w.add(pw.Text('GROUP AVERAGES',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          w.add(pw.SizedBox(height: 6));
          w.add(pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Settlement Mean (mm)',
                  group.avgDeflection.toStringAsFixed(4)],
              ['Velocity Mean (m/s)',
                  group.avgVelocity.toStringAsFixed(4)],
              ['EVD Mean (MN/m²)', group.avgEvd.toStringAsFixed(2)],
              ['Acceleration Mean (g)',
                  group.avgAcceleration.toStringAsFixed(4)],
              ['S/V Max (mm·s/m)', group.maxSOverV.toStringAsFixed(4)],
              ['S/V Mean (mm·s/m)', group.avgSOverV.toStringAsFixed(4)],
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green100),
            cellAlignment: pw.Alignment.centerLeft,
          ));

          return w;
        },
      ),
    );

    // ---- Second page: Settlement curve data ----
    if (settleTableData.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Text('SETTLEMENT vs IMPACT TIME (mm)',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: [
                'Time (ms)',
                for (int i = 0; i < group.drops.length; i++)
                  'Drop ${i + 1} (mm)',
              ],
              data: settleTableData,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue100),
              cellAlignment: pw.Alignment.center,
            ),
          ],
        ),
      );
    }

    // ---- Third page: Velocity curve data ----
    if (velTableData.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Text('VELOCITY vs IMPACT TIME (m/s)',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: [
                'Time (ms)',
                for (int i = 0; i < group.drops.length; i++)
                  'Drop ${i + 1} (m/s)',
              ],
              data: velTableData,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.orange100),
              cellAlignment: pw.Alignment.center,
            ),
          ],
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_GROUP_${DateFormat('yyyyMMdd_HHmmss').format(group.time)}.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }
}