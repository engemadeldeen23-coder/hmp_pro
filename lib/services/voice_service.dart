import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool get enabled => _enabled;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
      print('Voice initialized');
    } catch (e) {
      print('Voice init failed: $e');
    }
  }

  void setEnabled(bool v) {
    _enabled = v;
  }

  Future<void> say(String text) async {
    if (!_enabled) return;
    try {
      if (!_initialized) await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      print('[VOICE] $text');
    }
  }

  Future<void> beep() async {
    if (!_enabled) return;
    try {
      if (!_initialized) await init();
      await _tts.speak("Ready");
    } catch (_) {}
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
  }
}