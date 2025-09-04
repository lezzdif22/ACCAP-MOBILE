import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  static const String _prefsKey = 'haptics_enabled';
  bool _enabled = true;
  int _lastVibration = 0;
  static const int _minIntervalMs = 40; // avoid spamming tiny vibrations

  HapticService._internal();

  static HapticService get instance => _instance;

  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  debugPrint('HapticService: setEnabled -> $_enabled');
  }

  void selection() {
    if (!_enabled) return;
    debugPrint('HapticService: selection() called');
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('HapticService: selection HapticFeedback error: $e');
    }
  // Some devices have very weak/light haptic for selection; add a stronger vibration pulse
  _maybeVibrate(60);
  }

  void lightImpact() {
    if (!_enabled) return;
    debugPrint('HapticService: lightImpact() called');
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('HapticService: lightImpact HapticFeedback error: $e');
    }
  // Add a stronger short pulse for visibility
  _maybeVibrate(80);
  }

  /// Button press feedback with 300ms vibration
  void buttonPress() {
    if (!_enabled) return;
    debugPrint('HapticService: buttonPress() called');
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('HapticService: buttonPress HapticFeedback error: $e');
    }
    // Add 300ms vibration for button feedback
    _maybeVibrate(300);
  }

  void heavyImpactWithVibration() async {
    if (!_enabled) return;
    debugPrint('HapticService: heavyImpactWithVibration() called');
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('HapticService: HapticFeedback.heavyImpact error: $e');
    }
    try {
      final has = await Vibration.hasVibrator();
      debugPrint('HapticService: hasVibrator -> $has');
      if (has) {
        await Vibration.vibrate(duration: 200);
        debugPrint('HapticService: Vibration.vibrate(200) called');
      }
    } catch (e) {
      debugPrint('HapticService: Vibration error: $e');
    }
  }

  Future<void> _maybeVibrate(int ms) async {
    try {
      final has = await Vibration.hasVibrator();
      debugPrint('HapticService: _maybeVibrate hasVibrator -> $has');
      if (!has) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastVibration < _minIntervalMs) {
        debugPrint('HapticService: skipping vibrate (rate limit)');
        return;
      }
      _lastVibration = now;
      await Vibration.vibrate(duration: ms);
      debugPrint('HapticService: _maybeVibrate called duration=$ms');
    } catch (e) {
      debugPrint('HapticService: _maybeVibrate error: $e');
    }
  }

  /// General vibrate helper
  Future<void> vibrate(int ms, {int? repeat}) async {
    if (!_enabled) return;
    try {
      final has = await Vibration.hasVibrator();
      debugPrint('HapticService: vibrate hasVibrator -> $has');
      if (!has) return;
      if (repeat != null) {
        await Vibration.vibrate(duration: ms, repeat: repeat);
      } else {
        await Vibration.vibrate(duration: ms);
      }
      debugPrint('HapticService: vibrate called duration=$ms repeat=${repeat ?? 0}');
    } catch (e) {
      debugPrint('HapticService: vibrate error: $e');
    }
  }

  /// Vibrate using a pattern (ms gaps)
  Future<void> vibratePattern(List<int> pattern) async {
    if (!_enabled) return;
    try {
      final has = await Vibration.hasVibrator();
      debugPrint('HapticService: vibratePattern hasVibrator -> $has');
      if (!has) return;
      await Vibration.vibrate(pattern: pattern);
      debugPrint('HapticService: vibratePattern called pattern=$pattern');
    } catch (e) {
      debugPrint('HapticService: vibratePattern error: $e');
    }
  }

  /// Cancel any ongoing vibration
  void cancel() {
    if (!_enabled) return;
    try {
      Vibration.cancel();
      debugPrint('HapticService: cancel called');
    } catch (e) {
      debugPrint('HapticService: cancel error: $e');
    }
  }
}
