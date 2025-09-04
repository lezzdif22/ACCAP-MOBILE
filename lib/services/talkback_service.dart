import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TalkBackService {
  static final TalkBackService _instance = TalkBackService._internal();
  factory TalkBackService() => _instance;
  TalkBackService._internal();

  static TalkBackService get instance => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isEnabled = false;
  bool _isInitialized = false;

  // Highlighted element tracking
  OverlayEntry? _overlayEntry;

  bool get isEnabled => _isEnabled;

  /// Initialize TalkBack service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Setup TTS
    await _flutterTts.setLanguage("fil-PH");
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.setPitch(1.0);
    
    // Load settings
    await _loadSettings();
    _isInitialized = true;
  }

  /// Load TalkBack enabled state from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('talkback_enabled') ?? false;
  }

  /// Enable or disable TalkBack
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('talkback_enabled', enabled);
    
    if (!enabled) {
      _removeHighlight();
    }
  }

  /// Speak text if TalkBack is enabled
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  /// Create highlight overlay for an element
  void _showHighlight(BuildContext context, Rect bounds, String text) {
    _removeHighlight();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: bounds.left - 4,
        top: bounds.top - 4,
        child: Container(
          width: bounds.width + 8,
          height: bounds.height + 8,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.green,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    
    // Auto-remove highlight after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _removeHighlight();
    });
  }

  /// Remove highlight overlay
  void _removeHighlight() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Handle element tap for TalkBack
  void handleElementTap(BuildContext context, String text, [Widget? widget]) {
    if (!_isEnabled) return;
    
    // Get widget bounds for highlighting
    if (widget != null && context.mounted) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final bounds = renderBox.localToGlobal(Offset.zero) & renderBox.size;
        _showHighlight(context, bounds, text);
      }
    }
    
    // Speak the text
    speak(text);
  }

  /// Dispose resources
  void dispose() {
    _flutterTts.stop();
    _removeHighlight();
  }
}

/// Widget wrapper that adds TalkBack functionality
class TalkBackWrapper extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  const TalkBackWrapper({
    Key? key,
    required this.child,
    required this.label,
    this.hint,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle TalkBack functionality
        final fullText = hint != null ? "$label. $hint" : label;
        TalkBackService.instance.handleElementTap(context, fullText, child);
        
        // Execute original onTap if provided
        onTap?.call();
      },
      child: child,
    );
  }
}
