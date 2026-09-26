import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class DropSettingsPage extends StatefulWidget {
  final DropSettings settings;
  final Calibration calibration;
  final String password;
  final Future<void> Function(DropSettings, Calibration) onSave;

  const DropSettingsPage({
    super.key,
    required this.settings,
    required this.calibration,
    required this.password,
    required this.onSave,
  });

  @override
  State<DropSettingsPage> createState() => _DropSettingsPageState();
}

class _DropSettingsPageState extends State<DropSettingsPage> {
  late TextEditingController _poisson, _factor, _geo, _target;
  late double _plateRadius;
  double _calFactor = 1.0;
  String _calDate = 'Never';

  final List<double> _plateOptions = [0.05, 0.075, 0.10, 0.15];

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _plateRadius = s.plateRadius;
    _poisson = TextEditingController(text: s.poissonRatio.toString());
    _factor = TextEditingController(text: s.distributionFactor.toString());
    _geo = TextEditingController(text: s.geophoneDistance.toString());
    _target = TextEditingController(text: s.targetEvd.toString());
    _calFactor = widget.calibration.factor;
    _calDate = widget.calibration.date;
  }

  @override
  void dispose() {
    for (final c in [_poisson, _factor, _geo, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = DropSettings(
      plateRadius: _plateRadius,
      poissonRatio: double.tryParse(_poisson.text) ?? 0.5,
      distributionFactor: double.tryParse(_factor.text) ?? 2.0,
      geophoneDistance: double.tryParse(_geo.text) ?? 0,
      targetEvd: double.tryParse(_target.text) ?? 40.0,
    );
    final c = Calibration(
      factor: _calFactor,
      date: _calDate,
    );
    await widget.onSave(s, c);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showCalDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Calibration Password'),
        content: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Password', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx, c.text == widget.password),
              child: const Text('Unlock')),
        ],
      ),
    );
    if (ok == true) _showCalEditor();
  }

  Future<void> _showCalEditor() async {
    final f = TextEditingController(text: _calFactor.toStringAsFixed(3));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('Calibration Factor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: f,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'EVD Multiplier',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Text('Last calibration: $_calDate',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(f.text);
              if (v != null && v > 0) {
                setState(() {
                  _calFactor = v;
                  _calDate =
                      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Drop Settings'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PLATE DIAMETER',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plateOptions.map((r) {
                final selected = (r - _plateRadius).abs() < 0.001;
                return GestureDetector(
                  onTap: () => setState(() => _plateRadius = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.red.shade900
                          : const Color(0xFF151B2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Colors.redAccent
                            : const Color(0xFF2A3654),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${(r * 200).toStringAsFixed(0)} mm',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _numField('Poisson\'s Ratio (Standard 0.5)', _poisson),
            _numField('Distribution Factor (Standard 2.0)', _factor),
            _numField('External Geophone Distance (mm, 0 = none)', _geo),
            _numField('Target EVD (MN/m²)', _target),

            const SizedBox(height: 16),

            // Calibration section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151B2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3654)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      const Text('CALIBRATION',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Factor: ${_calFactor.toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Last: $_calDate',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showCalDialog,
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('ADJUST CALIBRATION'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('SAVE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.grey.shade500, fontSize: 11),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: const Color(0xFF151B2E),
        ),
      ),
    );
  }
}