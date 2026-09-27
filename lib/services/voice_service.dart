import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._();
  factory VoiceService() => _instance;
  VoiceService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    try {
      await _player.setVolume(1.0);
    } catch (e) {
      print('Sound init: $e');
    }
  }

  void setEnabled(bool v) {
    _enabled = v;
  }

  // Single short beep - start of action
  Future<void> beepShort() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      HapticFeedback.lightImpact();
    }
  }

  // Double beep - ready
  Future<void> beepReady() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 150));
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  // Triple beep - go / drop
  Future<void> beepGo() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  // Success - two clicks then alert
  Future<void> beepSuccess() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 200));
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  // Fail - single long alert
  Future<void> beepFail() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 300));
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  // Keep the old 'say' API working - but now just plays a beep pattern based on keywords
  Future<void> say(String text) async {
    if (!_enabled) return;
    final lower = text.toLowerCase();
    if (lower.contains('success') || lower.contains('successful')) {
      await beepSuccess();
    } else if (lower.contains('fail')) {
      await beepFail();
    } else if (lower.contains('complete') || lower.contains('finished')) {
      await beepSuccess();
    } else if (lower.contains('ready')) {
      await beepReady();
    } else if (lower.contains('drop') || lower.contains('lift')) {
      await beepGo();
    } else {
      await beepShort();
    }
  }

  Future<void> beep() async {
    await beepReady();
  }

  void dispose() {
    try {
      _player.dispose();
    } catch (_) {}
  }
}