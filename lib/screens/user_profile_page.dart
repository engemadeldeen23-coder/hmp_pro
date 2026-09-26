import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/models.dart';

class UserProfilePage extends StatefulWidget {
  final UserProfile profile;
  final Future<void> Function(UserProfile) onSave;
  final Future<void> Function() onDelete;

  const UserProfilePage({
    super.key,
    required this.profile,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late TextEditingController _company;
  late TextEditingController _title;
  late TextEditingController _engineer;
  late TextEditingController _city;
  late TextEditingController _country;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _website;
  String? _logoPath;
  bool _useMetric = true;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _company = TextEditingController(text: p.companyName);
    _title = TextEditingController(text: p.title);
    _engineer = TextEditingController(text: p.engineerName);
    _city = TextEditingController(text: p.city);
    _country = TextEditingController(text: p.country);
    _phone = TextEditingController(text: p.phone);
    _email = TextEditingController(text: p.email);
    _website = TextEditingController(text: p.website);
    _logoPath = p.logoPath;
    _useMetric = p.useMetric;
  }

  @override
  void dispose() {
    for (final c in [
      _company, _title, _engineer, _city, _country, _phone, _email, _website
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (img != null) setState(() => _logoPath = img.path);
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = UserProfile(
      companyName: _company.text.trim(),
      title: _title.text.trim(),
      engineerName: _engineer.text.trim(),
      city: _city.text.trim(),
      country: _country.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      website: _website.text.trim(),
      logoPath: _logoPath,
      useMetric: _useMetric,
    );
    await widget.onSave(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('User Profile'),
        backgroundColor: const Color(0xFF0A0E1A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3654)),
                  ),
                  child: _logoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(File(_logoPath!),
                              fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business,
                                color: Color(0xFF00E5FF), size: 32),
                            SizedBox(height: 4),
                            Text('Tap to add logo',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 9)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _field('Company Name', _company),
            _field('Title', _title),
            _field('Engineer Name', _engineer),
            _field('City', _city),
            _field('Country', _country),
            _field('Phone', _phone, keyboard: TextInputType.phone),
            _field('Email', _email, keyboard: TextInputType.emailAddress),
            _field('Website', _website),

            const SizedBox(height: 16),
            // Unit selection
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151B2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3654)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten,
                      color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 10),
                  const Text('Units:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('Metric'),
                    selected: _useMetric,
                    onSelected: (_) => setState(() => _useMetric = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Imperial'),
                    selected: !_useMetric,
                    onSelected: (_) => setState(() => _useMetric = false),
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

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF151B2E),
                    title: const Text('Delete Profile?'),
                    content: const Text(
                        'This will erase all user data entered beforehand.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.onDelete();
                  if (mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete),
              label: const Text('DELETE PROFILE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: const Color(0xFF151B2E),
        ),
      ),
    );
  }
}