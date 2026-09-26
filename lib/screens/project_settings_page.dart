import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/utils_extensions.dart';
import 'site_settings_page.dart';
import 'job_settings_page.dart';
import 'location_settings_page.dart';
import 'drop_list_page.dart';

class ProjectSettingsPage extends StatefulWidget {
  final List<Site> sites;
  final String activeSiteId;
  final String activeJobId;
  final String activeLocationId;
  final UserProfile profile;
  final Future<void> Function(List<Site>, String, String, String) onChanged;

  const ProjectSettingsPage({
    super.key,
    required this.sites,
    required this.activeSiteId,
    required this.activeJobId,
    required this.activeLocationId,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<ProjectSettingsPage> createState() => _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends State<ProjectSettingsPage> {
  late List<Site> _sites;
  late String _activeSiteId;
  late String _activeJobId;
  late String _activeLocationId;

  @override
  void initState() {
    super.initState();
    _sites = widget.sites;
    _activeSiteId = widget.activeSiteId;
    _activeJobId = widget.activeJobId;
    _activeLocationId = widget.activeLocationId;
  }

  Site? get _activeSite =>
      _sites.firstWhereOrNull((s) => s.id == _activeSiteId);
  Job? get _activeJob =>
      _activeSite?.jobs.firstWhereOrNull((j) => j.id == _activeJobId);
  Location? get _activeLocation =>
      _activeJob?.locations.firstWhereOrNull((l) => l.id == _activeLocationId);

  Future<void> _save() async {
    await widget.onChanged(
        _sites, _activeSiteId, _activeJobId, _activeLocationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Project Settings'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151B2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3654)),
              ),
              child: Column(
                children: [
                  _infoRow('Active Site', _activeSite?.name ?? 'None'),
                  _infoRow('Active Job', _activeJob?.name ?? 'None'),
                  _infoRow(
                      'Active Location', _activeLocation?.name ?? 'None'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _menuButton(
              icon: Icons.business,
              title: 'Site Settings',
              subtitle:
                  '${_sites.length} site${_sites.length == 1 ? '' : 's'}',
              color: const Color(0xFF1E88E5),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteSettingsPage(
                      sites: _sites,
                      activeSiteId: _activeSiteId,
                      onChanged: (newSites, newId) async {
                        setState(() {
                          _sites = newSites;
                          _activeSiteId = newId;
                          _activeJobId = '';
                          _activeLocationId = '';
                        });
                        await _save();
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),

            _menuButton(
              icon: Icons.work,
              title: 'Job Settings',
              subtitle: _activeSite == null
                  ? 'Select a site first'
                  : '${_activeSite!.jobs.length} job${_activeSite!.jobs.length == 1 ? '' : 's'}',
              color: const Color(0xFF00E5FF),
              disabled: _activeSite == null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobSettingsPage(
                      site: _activeSite!,
                      activeJobId: _activeJobId,
                      onChanged: (updatedSite, newJobId) async {
                        setState(() {
                          final i = _sites
                              .indexWhere((s) => s.id == updatedSite.id);
                          if (i >= 0) _sites[i] = updatedSite;
                          _activeJobId = newJobId;
                          _activeLocationId = '';
                        });
                        await _save();
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),

            _menuButton(
              icon: Icons.location_on,
              title: 'Location Settings',
              subtitle: _activeJob == null
                  ? 'Select a job first'
                  : '${_activeJob!.locations.length} location${_activeJob!.locations.length == 1 ? '' : 's'}',
              color: Colors.purpleAccent,
              disabled: _activeJob == null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationSettingsPage(
                      job: _activeJob!,
                      activeLocationId: _activeLocationId,
                      onChanged: (updatedJob, newLocId) async {
                        setState(() {
                          final si =
                              _sites.indexWhere((s) => s.id == _activeSiteId);
                          if (si >= 0) {
                            final ji = _sites[si]
                                .jobs
                                .indexWhere((j) => j.id == updatedJob.id);
                            if (ji >= 0) {
                              _sites[si].jobs[ji] = updatedJob;
                            }
                          }
                          _activeLocationId = newLocId;
                        });
                        await _save();
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),

            if (_activeLocation != null &&
                _activeLocation!.testGroups.isNotEmpty)
              _menuButton(
                icon: Icons.list,
                title: 'Drop List',
                subtitle:
                    '${_activeLocation!.testGroups.length} test group(s)',
                color: Colors.orangeAccent,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DropListPage(
                        location: _activeLocation!,
                        profile: widget.profile,
                        siteName: _activeSite?.name ?? '',
                        jobName: _activeJob?.name ?? '',
                        onChanged: (updated) async {
                          setState(() {
                            final si = _sites
                                .indexWhere((s) => s.id == _activeSiteId);
                            if (si >= 0) {
                              final ji = _sites[si]
                                  .jobs
                                  .indexWhere((j) => j.id == _activeJobId);
                              if (ji >= 0) {
                                final li = _sites[si]
                                    .jobs[ji]
                                    .locations
                                    .indexWhere(
                                        (l) => l.id == _activeLocationId);
                                if (li >= 0) {
                                  _sites[si].jobs[ji].locations[li] = updated;
                                }
                              }
                            }
                          });
                          await _save();
                        },
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),

            const SizedBox(height: 20),
            const Text(
              'Hierarchy:\nSite → Job → Location → Test Group',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151B2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}