import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class ExportService {
  // ============================================================
  //  CSV - Simple drop list
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

    if (drops.isNotEmpty) {
      rows.add([]);
      rows.add(['SUMMARY']);
      final avg =
          drops.map((d) => d.evd).reduce((a, b) => a + b) / drops.length;
      final avgDef =
          drops.map((d) => d.deflection).reduce((a, b) => a + b) /
              drops.length;
      final avgAcc =
          drops.map((d) => d.acceleration).reduce((a, b) => a + b) /
              drops.length;
      final avgVel =
          drops.map((d) => d.velocity).reduce((a, b) => a + b) /
              drops.length;
      final avgSov =
          drops.map((d) => d.sOverV).reduce((a, b) => a + b) / drops.length;

      rows.add(['Average EVD', avg.toStringAsFixed(2)]);
      rows.add(['Average Deflection', avgDef.toStringAsFixed(4)]);
      rows.add(['Average Acceleration', avgAcc.toStringAsFixed(4)]);
      rows.add(['Average Velocity', avgVel.toStringAsFixed(4)]);
      rows.add(['Average S/V', avgSov.toStringAsFixed(4)]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_PRO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await f.writeAsString(csv);
    return f;
  }

  // ============================================================
  //  PDF - Simple drop list
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
            if (profile.engineerName.isNotEmpty) {
              widgets.add(pw.Text('Engineer: ${profile.engineerName}',
                  style: const pw.TextStyle(fontSize: 10)));
            }
            widgets.add(pw.SizedBox(height: 8));
          }

          widgets.add(pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 12));

          widgets.add(pw.Table.fromTextArray(
            headers: [
              'Drop',
              'Time',
              'EVD',
              'Defl',
              'Acc',
              'Vel',
              'S/V',
            ],
            data: drops.map((d) {
              return [
                d.dropNumber.toString(),
                DateFormat('HH:mm:ss').format(d.time),
                d.evd.toStringAsFixed(1),
                d.deflection.toStringAsFixed(3),
                d.acceleration.toStringAsFixed(3),
                d.velocity.toStringAsFixed(3),
                d.sOverV.toStringAsFixed(3),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
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
  //  GROUP CSV EXPORT
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
      rows.add([
        'GPS Accuracy',
        '±${group.accuracy.toStringAsFixed(1)} m'
      ]);
    }
    rows.add([]);

    rows.add(['TEST DROPS']);
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
    rows.add([
      'Avg Acceleration (g)',
      group.avgAcceleration.toStringAsFixed(4)
    ]);
    rows.add(['Avg S/V (mm·s/m)', group.avgSOverV.toStringAsFixed(4)]);

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_GROUP_${DateFormat('yyyyMMdd_HHmmss').format(group.time)}.csv');
    await f.writeAsString(csv);
    return f;
  }

  // ============================================================
  //  GROUP PDF EXPORT
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
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Header
          if (profile != null && profile.companyName.isNotEmpty) {
            widgets.add(pw.Text(profile.companyName,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)));
            if (profile.engineerName.isNotEmpty) {
              widgets.add(pw.Text('Engineer: ${profile.engineerName}',
                  style: const pw.TextStyle(fontSize: 10)));
            }
            if (profile.phone.isNotEmpty || profile.email.isNotEmpty) {
              widgets.add(pw.Text(
                  '${profile.phone}  ${profile.email}',
                  style: const pw.TextStyle(fontSize: 9)));
            }
            widgets.add(pw.SizedBox(height: 8));
          }

          widgets.add(pw.Divider());
          widgets.add(pw.Text('HMP PRO - TEST GROUP REPORT',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 10));

          // Info
          widgets.add(pw.Text('Site: $siteName',
              style: const pw.TextStyle(fontSize: 10)));
          widgets.add(pw.Text('Job: $jobName',
              style: const pw.TextStyle(fontSize: 10)));
          widgets.add(pw.Text('Location: $locationName',
              style: const pw.TextStyle(fontSize: 10)));
          widgets.add(pw.Text(
              'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(group.time)}',
              style: const pw.TextStyle(fontSize: 10)));
          widgets.add(pw.Text(
              'Plate Diameter: ${group.plateDiameterMm.toStringAsFixed(0)} mm',
              style: const pw.TextStyle(fontSize: 10)));
          if (group.hasLocation) {
            widgets.add(pw.Text(
                'GPS: ${group.latitude.toStringAsFixed(6)}, ${group.longitude.toStringAsFixed(6)}',
                style: const pw.TextStyle(fontSize: 10)));
          }
          widgets.add(pw.SizedBox(height: 14));

          // Test data table
          widgets.add(pw.Text('TEST DATA',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Table.fromTextArray(
            headers: [
              'Test',
              'Settle (mm)',
              'Velocity (m/s)',
              'EVD (MN/m²)',
              'Acc (g)',
              'S/V (mm·s/m)',
            ],
            data: group.drops.map((d) {
              return [
                '${d.dropNumber}',
                d.deflection.toStringAsFixed(4),
                d.velocity.toStringAsFixed(4),
                d.evd.toStringAsFixed(2),
                d.acceleration.toStringAsFixed(4),
                d.sOverV.toStringAsFixed(4),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ));

          widgets.add(pw.SizedBox(height: 14));

          // Averages
          widgets.add(pw.Text('GROUP AVERAGES',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Settlement (mm)', group.avgDeflection.toStringAsFixed(4)],
              ['Velocity (m/s)', group.avgVelocity.toStringAsFixed(4)],
              [
                'Young\'s Modulus - EVD (MN/m²)',
                group.avgEvd.toStringAsFixed(2)
              ],
              [
                'Acceleration (g)',
                group.avgAcceleration.toStringAsFixed(4)
              ],
              ['S/V Ratio (mm·s/m)', group.avgSOverV.toStringAsFixed(4)],
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green100),
            cellAlignment: pw.Alignment.centerLeft,
          ));

          return widgets;
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_GROUP_${DateFormat('yyyyMMdd_HHmmss').format(group.time)}.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }
}