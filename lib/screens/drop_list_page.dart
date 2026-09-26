import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'test_group_detail_page.dart';

class DropListPage extends StatefulWidget {
  final Location location;
  final UserProfile profile;
  final String siteName;
  final String jobName;
  final Future<void> Function(Location) onChanged;

  const DropListPage({
    super.key,
    required this.location,
    required this.profile,
    required this.siteName,
    required this.jobName,
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

  Future<void> _deleteGroup(TestGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Delete group?'),
        content: Text(
            'Group from ${DateFormat('yyyy-MM-dd HH:mm').format(g.time)} with ${g.drops.length} drops.'),
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
    setState(() => _loc.testGroups.removeWhere((x) => x.id == g.id));
    await widget.onChanged(_loc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Text('Drop List (${_loc.name})'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: _loc.testGroups.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 60, color: Colors.grey.shade800),
                  const SizedBox(height: 12),
                  Text('No test groups yet',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Perform a test with 3 drops',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _loc.testGroups.length,
              itemBuilder: (ctx, i) {
                final g = _loc.testGroups.reversed.toList()[i];
                return _groupFolderTile(g);
              },
            ),
    );
  }

  Widget _groupFolderTile(TestGroup g) {
    final passed = g.avgEvd >= 40;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: passed
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : const Color(0xFF2A3654),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestGroupDetailPage(
                group: g,
                profile: widget.profile,
                siteName: widget.siteName,
                jobName: widget.jobName,
                locationName: _loc.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_special,
                        color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group • ${DateFormat('MMM d, yyyy').format(g.time)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('HH:mm:ss').format(g.time)} • ${g.drops.length} drops',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (passed)
                    const Icon(Icons.verified,
                        color: Colors.greenAccent, size: 20)
                  else
                    const Icon(Icons.cancel,
                        color: Colors.redAccent, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                        'Avg EVD',
                        '${g.avgEvd.toStringAsFixed(1)} MN/m²',
                        const Color(0xFF00E5FF)),
                  ),
                  Expanded(
                    child: _miniStat('Avg Settle',
                        '${g.avgDeflection.toStringAsFixed(3)} mm',
                        Colors.orangeAccent),
                  ),
                  Expanded(
                    child: _miniStat('Avg Vel',
                        '${g.avgVelocity.toStringAsFixed(3)} m/s',
                        Colors.greenAccent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'S/V: ${g.avgSOverV.toStringAsFixed(3)} mm·s/m',
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.redAccent,
                    onPressed: () => _deleteGroup(g),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 9,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ],
    );
  }
}