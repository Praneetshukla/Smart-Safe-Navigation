// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await initialize();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  Future<void> announceNavigation(String instruction) =>
      speak(instruction);

  Future<void> safetyAlert(String message, {double severity = 3.0}) {
    String prefix = severity >= 4.0 ? 'Urgent Alert' : 'Smart Alert';
    return speak('$prefix: $message');
  }

  Future<void> announceArrival(String destination) =>
      speak('You have arrived at $destination. Stay safe!');
}