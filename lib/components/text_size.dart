import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum TextSizeOption { normal, large, larger }

class TextSizeProvider with ChangeNotifier {
  TextSizeOption _textSize = TextSizeOption.normal;
  bool _isInitialized = false;

  TextSizeOption get textSize => _textSize;

  double get sliderValue => _textSize.index.toDouble();

  void updateFromSlider(double value) {
    _textSize = TextSizeOption.values[value.round()];
    notifyListeners();
  }

  void setTextSize(TextSizeOption option) {
    _textSize = option;
    notifyListeners();
  }

  double get fontSize {
    switch (_textSize) {
      case TextSizeOption.normal:
        return 18.0;
      case TextSizeOption.large:
        return 22.0;
      case TextSizeOption.larger:
        return 24.0;
    }
  }

  Future<void> loadUserTextSize() async {
    if (_isInitialized) return; // Avoid reloading
    _isInitialized = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc['textSize'] != null) {
        final textSizeString = doc['textSize'] as String;
        switch (textSizeString) {
          case 'normal':
            _textSize = TextSizeOption.normal;
            break;
          case 'large':
            _textSize = TextSizeOption.large;
            break;
          case 'larger':
            _textSize = TextSizeOption.larger;
            break;
        }
        notifyListeners(); // Only notify after loading
      }
    }
  }

  double getButtonHeight(double fontSize) {
    if (fontSize >= 24) return 36;
    if (fontSize >= 20) return 28;
    return 22;
  }

  EdgeInsets getButtonPadding(double fontSize) {
    if (fontSize >= 24) return EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    if (fontSize >= 20) return EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    return EdgeInsets.symmetric(horizontal: 14, vertical: 8);
  }

  String get label => _textSize.toString().split('.').last.toUpperCase();
}