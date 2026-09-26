import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void setEnabled(bool v) {
    _enabled = v;
  }

  Future<void> say(String text) async {
    if (!_enabled) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> beep() async {
    if (!_enabled) return;
    try {
      await _tts.stop();
      await _tts.speak("Ready");
    } catch (_) {}
  }

  void dispose() {
    _tts.stop();
  }
}