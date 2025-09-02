import 'package:flutter/material.dart';

class InstructionsDialog extends StatefulWidget {
  const InstructionsDialog({super.key});

  @override
  State<InstructionsDialog> createState() => _InstructionsDialogState();
}

class _InstructionsDialogState extends State<InstructionsDialog> {
  int _currentStep = 0;

  final List<Map<String, String>> _steps = [
    {
      "title": "Step 1: Prepare Your ID",
      "content": "• Make sure your PWD ID is clean and free from obstructions like stickers or covers.\n"
          "• Place the ID on a flat surface with good lighting.",
    },
    {
      "title": "Step 2: Scan the Front of the ID",
      "content": "• Align the front side of the ID within the frame on your screen.\n"
          "• Ensure all details (name, ID number, expiration date, etc.) are clearly visible.\n"
          "• Tap the Scan Front button.",
    },
    {
      "title": "Step 3: Scan the Back of the ID",
      "content": "• Flip your ID over and align the back side within the frame.\n"
          "• Ensure the text is clear and not blurry.\n"
          "• Tap the Scan Back button.",
    },
    {
      "title": "⚠ Important Note",
      "content": "The system will automatically extract information from your scanned ID using text recognition technology. However, due to possible variations in image quality or ID design, the data may not be 100% accurate.\n\n"
          "Please review and edit any incorrect information before submitting to ensure everything is correct.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color.fromARGB(255, 250, 250, 250),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _steps[_currentStep]["title"]!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color.fromARGB(255, 0, 48, 96),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _steps[_currentStep]["content"]!,
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Back"),
                  ),
                ElevatedButton(
                  onPressed: _currentStep < _steps.length - 1
                      ? () {
                    setState(() {
                      _currentStep++;
                    });
                  }
                      : () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 0, 48, 96),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_currentStep == _steps.length - 1 ? "Close" : "Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}