import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackState {
  stopped,
  playing,
  paused,
}

/// 100% On-Device Neural Text-to-Speech Engine
/// Allows continuous listening to PDFs, Word files, and scanned texts with speed and language controls.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  TtsPlaybackState _playbackState = TtsPlaybackState.stopped;
  double _speechRate = 0.5; // 0.0 to 1.0 (0.5 is 1.0x normal speed)
  double _volume = 1.0;
  double _pitch = 1.0;
  String _currentLanguage = "en-US";
  VoidCallback? onStateChanged;

  TtsPlaybackState get playbackState => _playbackState;
  double get speechRate => _speechRate;
  String get currentLanguage => _currentLanguage;

  TtsService._internal() {
    _initTts();
  }

  void _initTts() {
    _tts.setStartHandler(() {
      _playbackState = TtsPlaybackState.playing;
      onStateChanged?.call();
    });

    _tts.setCompletionHandler(() {
      _playbackState = TtsPlaybackState.stopped;
      onStateChanged?.call();
    });

    _tts.setPauseHandler(() {
      _playbackState = TtsPlaybackState.paused;
      onStateChanged?.call();
    });

    _tts.setContinueHandler(() {
      _playbackState = TtsPlaybackState.playing;
      onStateChanged?.call();
    });

    _tts.setErrorHandler((msg) {
      debugPrint("TTS error notice: $msg");
      _playbackState = TtsPlaybackState.stopped;
      onStateChanged?.call();
    });

    // Default configuration
    _tts.setLanguage(_currentLanguage);
    _tts.setSpeechRate(_speechRate);
    _tts.setVolume(_volume);
    _tts.setPitch(_pitch);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.speak(text);
      _playbackState = TtsPlaybackState.playing;
      onStateChanged?.call();
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
      _playbackState = TtsPlaybackState.paused;
      onStateChanged?.call();
    } catch (e) {
      debugPrint("TTS pause error: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _playbackState = TtsPlaybackState.stopped;
      onStateChanged?.call();
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _tts.setSpeechRate(_speechRate);
    onStateChanged?.call();
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    await _tts.setLanguage(langCode);
    onStateChanged?.call();
  }
}
