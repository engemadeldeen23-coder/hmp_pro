import 'package:flutter/material.dart';
import '../models/models.dart';

class JobSettingsPage extends StatefulWidget {
  final Site site;
  final String activeJobId;
  final Future<void> Function(Site, String) onChanged;

  const JobSettingsPage({
    super.key,
    required this.site,
    required this.activeJobId,
    required this.onChanged,
  });

  @override
  State<JobSettingsPage> createState() => _JobSettingsPageState();
}

class _JobSettingsPageState extends State<JobSettingsPage> {
  late Site _site;
  late String _activeJobId;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    _activeJobId = widget.activeJobId;
  }

  Future<void> _addJob() async {
    final name = await _prompt('New Job');
    if (name == null || name.isEmpty) return;
    final j = Job(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    setState(() {
      _site.jobs.add(j);
      _activeJobId = j.id;
    });
    await widget.onChanged(_site, _activeJobId);
  }

  Future<void> _editJob(Job j) async {
    final name = await _prompt('Edit Job', initial: j.name);
    if (name == null || name.isEmpty) return;
    setState(() => j.name = name);
    await widget.onChanged(_site, _activeJobId);
  }

  Future<void> _deleteJob(Job j) async {
    final ok = await _confirm(
        'Delete job "${j.name}"?\nAll locations and drops will be erased.');
    if (ok != true) return;
    setState(() {
      _site.jobs.removeWhere((x) => x.id == j.id);
      if (_activeJobId == j.id) {
        _activeJobId = _site.jobs.isEmpty ? '' : _site.jobs.first.id;
      }
    });
    await widget.onChanged(_site, _activeJobId);
  }

  Future<String?> _prompt(String t, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: Text(t),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String m) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF151B2E),
          title: const Text('Confirm'),
          content: Text(m),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: Text('Jobs (${_site.name})'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addJob,
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: const Color(0xFF0A0E1A),
        icon: const Icon(Icons.add),
        label: const Text('+ JOB'),
      ),
      body: _site.jobs.isEmpty
          ? Center(
              child: Text('No jobs yet — tap "+ JOB"',
                  style: TextStyle(color: Colors.grey.shade500)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _site.jobs.length,
              itemBuilder: (ctx, i) {
                final j = _site.jobs[i];
                final active = j.id == _activeJobId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF0F2535)
                        : const Color(0xFF151B2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF2A3654),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Radio<String>(
                      value: j.id,
                      groupValue: _activeJobId,
                      onChanged: (v) async {
                        setState(() => _activeJobId = v!);
                        await widget.onChanged(_site, _activeJobId);
                      },
                      activeColor: const Color(0xFF00E5FF),
                    ),
                    title: Text(j.name,
                        style: TextStyle(
                          color: active ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('${j.locations.length} locations',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: const Color(0xFF00E5FF),
                          onPressed: () => _editJob(j),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          color: Colors.redAccent,
                          onPressed: () => _deleteJob(j),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}