import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class ExportService {
  // ------- CSV -------
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
      'Type',
      'Date',
      'Time',
      'EVD (MN/m²)',
      'Deflection (mm)',
      'Acceleration (g)',
      'Velocity (m/s)',
      'Latitude',
      'Longitude',
    ]);

    for (final d in drops) {
      rows.add([
        d.dropNumber,
        d.isPreload ? 'Preload' : 'Test',
        DateFormat('yyyy-MM-dd').format(d.time),
        DateFormat('HH:mm:ss').format(d.time),
        d.evd.toStringAsFixed(2),
        d.deflection.toStringAsFixed(4),
        d.acceleration.toStringAsFixed(4),
        d.velocity.toStringAsFixed(4),
        d.hasLocation ? d.latitude.toStringAsFixed(6) : 'N/A',
        d.hasLocation ? d.longitude.toStringAsFixed(6) : 'N/A',
      ]);
    }

    // Summary
    final tests = drops.where((d) => !d.isPreload).toList();
    if (tests.isNotEmpty) {
      rows.add([]);
      rows.add(['SUMMARY (only tests)']);
      final avg = tests.map((d) => d.evd).reduce((a, b) => a + b) /
          tests.length;
      final avgDef = tests.map((d) => d.deflection).reduce((a, b) => a + b) /
          tests.length;
      final avgAcc =
          tests.map((d) => d.acceleration).reduce((a, b) => a + b) /
              tests.length;
      final avgVel =
          tests.map((d) => d.velocity).reduce((a, b) => a + b) / tests.length;

      rows.add(['Average EVD', avg.toStringAsFixed(2)]);
      rows.add(['Average Deflection', avgDef.toStringAsFixed(4)]);
      rows.add(['Average Acceleration', avgAcc.toStringAsFixed(4)]);
      rows.add(['Average Velocity', avgVel.toStringAsFixed(4)]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
        '${dir.path}/HMP_PRO_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
    await f.writeAsString(csv);
    return f;
  }

  // ------- PDF -------
  static Future<File> buildPdf(
    List<Drop> drops,
    String title, {
    UserProfile? profile,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final widgets = <pw.Widget>[];

          // Header
          if (profile != null && profile.companyName.isNotEmpty) {
            widgets.add(pw.Text(profile.companyName,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)));
            if (profile.engineerName.isNotEmpty) {
              widgets.add(pw.Text('Engineer: ${profile.engineerName}'));
            }
            widgets.add(pw.SizedBox(height: 8));
          }

          widgets.add(pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 12));

          // Table
          widgets.add(pw.Table.fromTextArray(
            headers: [
              'Drop',
              'Type',
              'Time',
              'EVD',
              'Defl',
              'Acc',
              'Vel'
            ],
            data: drops.map((d) {
              return [
                d.dropNumber.toString(),
                d.isPreload ? 'P' : 'T',
                DateFormat('HH:mm:ss').format(d.time),
                d.evd.toStringAsFixed(1),
                d.deflection.toStringAsFixed(3),
                d.acceleration.toStringAsFixed(3),
                d.velocity.toStringAsFixed(3),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ));

          // Summary
          final tests = drops.where((d) => !d.isPreload).toList();
          if (tests.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Text('Summary (Tests Only)',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)));
            final avg =
                tests.map((d) => d.evd).reduce((a, b) => a + b) / tests.length;
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
                pw.Text('Average EVD: ${avg.toStringAsFixed(2)} MN/m²'));
          }

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
}