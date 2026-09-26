import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/export_service.dart';

class DropListPage extends StatefulWidget {
  final Location location;
  final UserProfile profile;
  final Future<void> Function(Location) onChanged;

  const DropListPage({
    super.key,
    required this.location,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<DropListPage> createState() => _DropListPageState();
}

class _DropListPageState extends State<DropListPage> {
  late Location _loc;

  @override
  void initState() {
    super.initState();
    _loc = widget.location;
  }

  Future<void> _deleteDrop(Drop d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Delete drop?'),
        content: Text(
            'Drop #${d.dropNumber} at ${DateFormat('HH:mm:ss').format(d.time)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loc.drops.removeWhere((x) => x.id == d.id));
    await widget.onChanged(_loc);
  }

  Future<void> _viewDrop(Drop d) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151B2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DROP #${d.dropNumber}',
                style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(
              '${d.isPreload ? "Preload" : "Test"} • '
              '${DateFormat('yyyy-MM-dd HH:mm:ss').format(d.time)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            const Divider(color: Color(0xFF2A3654), height: 24),
            _row('EVD', '${d.evd.toStringAsFixed(2)} MN/m²'),
            _row('Deflection', '${d.deflection.toStringAsFixed(4)} mm'),
            _row('Acceleration', '${d.acceleration.toStringAsFixed(4)} g'),
            _row('Velocity', '${d.velocity.toStringAsFixed(4)} m/s'),
            _row('Plate radius', '${(d.plateRadius * 100).toStringAsFixed(0)} cm'),
            if (d.hasLocation)
              _row('GPS',
                  '${d.latitude.toStringAsFixed(6)}, ${d.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAll() async {
    try {
      final file = await ExportService.buildCsv(
        _loc.drops,
        'Location: ${_loc.name}',
        profile: widget.profile,
      );
      await Share.shareXFiles([XFile(file.path)],
          subject: 'HMP PRO - ${_loc.name}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final file = await ExportService.buildPdf(
        _loc.drops,
        'Location: ${_loc.name}',
        profile: widget.profile,
      );
      await Share.shareXFiles([XFile(file.path)],
          subject: 'HMP PRO PDF - ${_loc.name}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = _loc.drops.where((d) => !d.isPreload).toList();
    final preloads = _loc.drops.where((d) => d.isPreload).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Text('Drop List (${_loc.name})'),
        backgroundColor: const Color(0xFF0A0E1A),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _loc.drops.isEmpty ? null : _exportAll,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _loc.drops.isEmpty ? null : _exportPdf,
          ),
        ],
      ),
      body: _loc.drops.isEmpty
          ? Center(
              child: Text('No drops yet',
                  style: TextStyle(color: Colors.grey.shade500)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2535), Color(0xFF0A1929)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('PRELOAD', '${preloads.length}', Colors.orangeAccent),
                      _stat('TEST', '${tests.length}', Colors.greenAccent),
                      _stat('AVG EVD',
                          _loc.avgEvd.toStringAsFixed(1), const Color(0xFF00E5FF)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._loc.drops.reversed.map((d) => _dropTile(d)).toList(),
              ],
            ),
    );
  }

  Widget _stat(String l, String v, Color c) {
    return Column(
      children: [
        Text(v,
            style: TextStyle(
                color: c, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(l,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }

  Widget _dropTile(Drop d) {
    final passed = d.evd >= 40; // uses default target; can be improved
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3654)),
      ),
      child: ListTile(
        onTap: () => _viewDrop(d),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: d.isPreload
                ? Colors.orange.shade900
                : (passed ? Colors.green.shade800 : Colors.red.shade800),
          ),
          child: Center(
            child: Text(
              '${d.dropNumber}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        ),
        title: Text(
            '${d.isPreload ? "Preload" : "Test"} • EVD ${d.evd.toStringAsFixed(1)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        subtitle: Text(
          DateFormat('HH:mm:ss').format(d.time) +
              (d.hasLocation
                  ? '  •  ${d.latitude.toStringAsFixed(4)}, ${d.longitude.toStringAsFixed(4)}'
                  : ''),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 18),
              color: const Color(0xFF00E5FF),
              onPressed: () => _viewDrop(d),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              color: Colors.redAccent,
              onPressed: () => _deleteDrop(d),
            ),
          ],
        ),
      ),
    );
  }
}