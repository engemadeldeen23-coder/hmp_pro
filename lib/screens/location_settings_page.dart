import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/gps_service.dart';
import 'dart:io';

class LocationSettingsPage extends StatefulWidget {
  final Job job;
  final String activeLocationId;
  final Future<void> Function(Job, String) onChanged;

  const LocationSettingsPage({
    super.key,
    required this.job,
    required this.activeLocationId,
    required this.onChanged,
  });

  @override
  State<LocationSettingsPage> createState() => _LocationSettingsPageState();
}

class _LocationSettingsPageState extends State<LocationSettingsPage> {
  late Job _job;
  late String _activeLocationId;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _activeLocationId = widget.activeLocationId;
  }

  Future<void> _addLocation() async {
    final name = await _promptName('New Location');
    if (name == null || name.isEmpty) return;

    final gps = GpsService();
    final pos = gps.current;
    final l = Location(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: pos?.latitude ?? 0,
      longitude: pos?.longitude ?? 0,
    );
    setState(() {
      _job.locations.add(l);
      _activeLocationId = l.id;
    });
    await widget.onChanged(_job, _activeLocationId);
  }

  Future<void> _editLocation(Location loc) async {
    final name = await _promptName('Edit Location', initial: loc.name);
    if (name == null || name.isEmpty) return;
    setState(() => loc.name = name);
    await widget.onChanged(_job, _activeLocationId);
  }

  Future<void> _updateGps(Location loc) async {
    final gps = GpsService();
    final pos = gps.current;
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS not ready')),
        );
      }
      return;
    }
    setState(() {
      loc.latitude = pos.latitude;
      loc.longitude = pos.longitude;
    });
    await widget.onChanged(_job, _activeLocationId);
  }

  Future<void> _pickPhoto(Location loc) async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (img != null) {
        setState(() => loc.photoPath = img.path);
        await widget.onChanged(_job, _activeLocationId);
      }
    } catch (_) {}
  }

  Future<void> _deleteLocation(Location loc) async {
    final ok = await _confirm(
        'Delete location "${loc.name}"?\nAll drops will be erased.');
    if (ok != true) return;
    setState(() {
      _job.locations.removeWhere((l) => l.id == loc.id);
      if (_activeLocationId == loc.id) {
        _activeLocationId =
            _job.locations.isEmpty ? '' : _job.locations.first.id;
      }
    });
    await widget.onChanged(_job, _activeLocationId);
  }

  Future<String?> _promptName(String t, {String initial = ''}) async {
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
        title: Text('Locations (${_job.name})'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: const Color(0xFF0A0E1A),
        icon: const Icon(Icons.add),
        label: const Text('+ LOCATION'),
      ),
      body: _job.locations.isEmpty
          ? Center(
              child: Text('No locations yet — tap "+ LOCATION"',
                  style: TextStyle(color: Colors.grey.shade500)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _job.locations.length,
              itemBuilder: (ctx, i) {
                final loc = _job.locations[i];
                final active = loc.id == _activeLocationId;
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: loc.id,
                              groupValue: _activeLocationId,
                              onChanged: (v) async {
                                setState(() => _activeLocationId = v!);
                                await widget
                                    .onChanged(_job, _activeLocationId);
                              },
                              activeColor: const Color(0xFF00E5FF),
                            ),
                            Expanded(
                              child: Text(loc.name,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.redAccent
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  )),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: const Color(0xFF00E5FF),
                              onPressed: () => _editLocation(loc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.redAccent,
                              onPressed: () => _deleteLocation(loc),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14,
                                color: loc.latitude != 0
                                    ? Colors.greenAccent
                                    : Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                loc.latitude != 0
                                    ? '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
                                    : 'No GPS',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _updateGps(loc),
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Update',
                                  style: TextStyle(fontSize: 10)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00E5FF),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.camera_alt,
                                  size: 18,
                                  color: loc.photoPath != null
                                      ? Colors.greenAccent
                                      : Colors.grey),
                              onPressed: () => _pickPhoto(loc),
                              tooltip: 'Location photo',
                            ),
                          ],
                        ),
                        if (loc.photoPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(loc.photoPath!),
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${loc.drops.length} drops • ${loc.testCount} tests',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 10),
                          ),
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