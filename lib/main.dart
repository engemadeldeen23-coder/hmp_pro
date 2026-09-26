import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF151B2E),
          title: const Text('HMP PRO TEST',
              style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
              SizedBox(height: 20),
              Text(
                'HMP PRO',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'MINIMAL TEST BUILD',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 30),
              Text(
                'If you see this screen,\nthe base app works!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}