import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  /// Announce text for TalkBack users
  static void announce(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Announce page changes
  static void announcePage(String pageName) {
    announce("Navigated to $pageName");
  }

  /// Announce button actions
  static void announceAction(String action) {
    announce(action);
  }

  /// Check if TalkBack or other accessibility services are enabled
  static bool get isAccessibilityEnabled {
    return WidgetsBinding.instance.accessibilityFeatures.accessibleNavigation;
  }
}
