import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../components/text_size.dart';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  _STTPageState createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _text = "Hold the microphone to speak.";
  bool _isListening = false;

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Status: $status"),
      onError: (error) => print("Error: $error"),
    );
    if (available) {
      setState(() {
        _isListening = true;
      });

      _speech.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
          });
        },
        localeId: "fil-PH",
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Press and hold the mic to start speaking",
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _text,
                style: TextStyle(fontSize: fontSize),
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onLongPress: _startListening,
              onLongPressUp: _stopListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.redAccent
                      : const Color.fromARGB(254, 15, 48, 96),
                  boxShadow: _isListening
                      ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 6,
                    )
                  ]
                      : [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}