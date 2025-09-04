import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/text_size.dart';

class TTSPage extends StatefulWidget {
  const TTSPage({super.key});

  @override
  _TTSPageState createState() => _TTSPageState();
}

class _TTSPageState extends State<TTSPage> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  static const int _maxPhrases = 5;
  static const int _maxWords = 10;
  List<String> savedPhrases = [];
  String? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _loadSavedPhrases();
  }

  Future<void> _setupTTS() async {
    await flutterTts.setLanguage("fil-PH");

    List<dynamic>? voices = await flutterTts.getVoices;
   if (voices!.isNotEmpty) {
  setState(() {
    _selectedVoice = voices.first['name'] ?? '';
    flutterTts.setVoice({"name": _selectedVoice!});
  });
}
  }

  Future<void> _speak() async {
    String text = _textController.text.trim();
    if (text.isNotEmpty) {
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(text);
    }
  }

  void _setText(String text) {
    setState(() {
      _textController.text = text;
    });
  }

  Future<void> _savePhrase() async {
    String text = _textController.text.trim();
    int wordCount = text.split(' ').where((word) => word.isNotEmpty).length;

    if (text.isEmpty) return;

    if (wordCount > _maxWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 10 words allowed!")),
      );
      return;
    }

    setState(() {
      if (savedPhrases.length >= _maxPhrases) {
        savedPhrases.removeAt(0); // Remove the oldest phrase (FIFO)
      }
      savedPhrases.add(text);
      _textController.clear();
    });

    await _storeSavedPhrases();
  }

  Future<void> _storeSavedPhrases() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedPhrases', savedPhrases);
  }

  Future<void> _loadSavedPhrases() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedPhrases = prefs.getStringList('savedPhrases') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 250, 250, 250),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Type text or select a phrase to read aloud.",
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  style: TextStyle(fontSize: fontSize),
                  controller: _textController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Type text here (max 10 words)",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Sound Button (Below Text Box)
             Center(
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 220, 230, 250),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: IconButton(
          icon: const Icon(Icons.volume_up, size: 32),
          onPressed: _speak,
          color: const Color.fromARGB(254, 15, 48, 96),
        ),
      ),
    ),
              const SizedBox(height: 10),
             ElevatedButton(
      onPressed: _savePhrase,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(254, 15, 48, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: Text(
        "Save Phrase",
        style: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    ),
              const SizedBox(height: 10),
            Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: savedPhrases.map((phrase) {
        return ElevatedButton(
          onPressed: () => _setText(phrase),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            phrase,
            style: TextStyle(fontSize: fontSize),
          ),
        );
      }).toList(),
    ),
            ],
          ),
        ),
      ),
    );
  }
}
