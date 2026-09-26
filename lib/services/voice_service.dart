// Voice service without flutter_tts (which crashes on some devices)
class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    // No-op - reserved for future TTS integration
  }

  void setEnabled(bool v) {
    _enabled = v;
  }

  Future<void> say(String text) async {
    if (!_enabled) return;
    print('[VOICE] $text');
  }

  Future<void> beep() async {
    if (!_enabled) return;
    print('[VOICE] beep');
  }

  void dispose() {}
}