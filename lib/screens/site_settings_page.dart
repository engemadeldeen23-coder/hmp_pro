import 'package:flutter/material.dart';
import '../models/models.dart';
import 'dart:math';

class SiteSettingsPage extends StatefulWidget {
  final List<Site> sites;
  final String activeSiteId;
  final Future<void> Function(List<Site>, String) onChanged;

  const SiteSettingsPage({
    super.key,
    required this.sites,
    required this.activeSiteId,
    required this.onChanged,
  });

  @override
  State<SiteSettingsPage> createState() => _SiteSettingsPageState();
}

class _SiteSettingsPageState extends State<SiteSettingsPage> {
  late List<Site> _sites;
  late String _activeId;

  @override
  void initState() {
    super.initState();
    _sites = List.from(widget.sites);
    _activeId = widget.activeSiteId;
  }

  Future<void> _addSite() async {
    final name = await _promptName('New Site');
    if (name == null || name.isEmpty) return;
    final s = Site(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    setState(() {
      _sites.add(s);
      _activeId = s.id;
    });
    await widget.onChanged(_sites, _activeId);
  }

  Future<void> _editSite(Site s) async {
    final name = await _promptName('Edit Site', initial: s.name);
    if (name == null || name.isEmpty) return;
    setState(() => s.name = name);
    await widget.onChanged(_sites, _activeId);
  }

  Future<void> _deleteSite(Site s) async {
    final ok = await _confirm('Delete site "${s.name}"?\nAll jobs, locations and drops will be erased.');
    if (ok != true) return;
    setState(() {
      _sites.removeWhere((x) => x.id == s.id);
      if (_activeId == s.id) _activeId = _sites.isEmpty ? '' : _sites.first.id;
    });
    await widget.onChanged(_sites, _activeId);
  }

  Future<String?> _promptName(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Confirm'),
        content: Text(msg),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Site Settings'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSite,
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: const Color(0xFF0A0E1A),
        icon: const Icon(Icons.add),
        label: const Text('+ SITE'),
      ),
      body: _sites.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sites.length,
              itemBuilder: (ctx, i) {
                final s = _sites[i];
                final active = s.id == _activeId;
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
                      value: s.id,
                      groupValue: _activeId,
                      onChanged: (v) async {
                        setState(() => _activeId = v!);
                        await widget.onChanged(_sites, _activeId);
                      },
                      activeColor: const Color(0xFF00E5FF),
                    ),
                    title: Text(s.name,
                        style: TextStyle(
                          color: active ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('${s.jobs.length} jobs',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          color: const Color(0xFF00E5FF),
                          onPressed: () => _editSite(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          color: Colors.redAccent,
                          onPressed: () => _deleteSite(s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 60, color: Colors.grey.shade800),
          const SizedBox(height: 12),
          Text('No sites yet',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Tap "+ SITE" to create one',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}