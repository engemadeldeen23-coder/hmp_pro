import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String _status = 'Testing plugins...';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    final results = <String>[];

    // Test shared_preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test', 'ok');
      final v = prefs.getString('test');
      results.add('shared_preferences: $v');
    } catch (e) {
      results.add('shared_preferences: FAIL - $e');
    }

    // Test path_provider
    try {
      // ignore: unused_local_variable
      final dir = await getApplicationDocumentsDirectory();
      results.add('path_provider: OK');
    } catch (e) {
      results.add('path_provider: FAIL - $e');
    }

    // Test intl
    try {
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      results.add('intl: $date');
    } catch (e) {
      results.add('intl: FAIL - $e');
    }

    if (!mounted) return;
    setState(() {
      _status = results.join('\n');
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151B2E),
        title: const Text('BATCH 1 TEST', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _done ? Icons.check_circle : Icons.hourglass_empty,
                color: _done ? Colors.greenAccent : Colors.orangeAccent,
                size: 80,
              ),
              const SizedBox(height: 20),
              const Text(
                'BATCH 1: Core Utilities',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 30),
              if (_done)
                const Text(
                  'If app shows this screen, Batch 1 OK',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}