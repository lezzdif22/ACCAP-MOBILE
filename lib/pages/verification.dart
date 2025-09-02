import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../widget/instructions_dialog.dart';
import 'login_page.dart';
import 'personalDetails_page.dart';

class VerificationPage extends StatefulWidget {
  final Function()? onTap;
  const VerificationPage({super.key, required this.onTap});

  @override
  State<VerificationPage> createState() => _VerificationPage();
}

class _VerificationPage extends State<VerificationPage> {
  File? frontIdImage;
  File? backIdImage;
  String frontIdText = '';
  String backIdText = '';
  final ImagePicker picker = ImagePicker();
  Map<String, dynamic> parseIdText(String text) {
    List<String> lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String fullName = '';
    String address = '';
    String birthdate = '';

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toUpperCase();
      if (line.contains("NAME") && i - 1 >= 0) {
        fullName = lines[i - 1];
      }
      if (line.contains("ADDRESS") && i + 1 < lines.length) {
        final match = RegExp(r'ADDRESS[:\s]*(.+)', caseSensitive: false).firstMatch(lines[i]);
        if (match != null) {
          address = match.group(1)?.trim() ?? '';
        } else if (i + 1 < lines.length) {
          address = lines[i + 1];
        }
      }
      if (line.startsWith("DATE OF BIRTH:")) {
        final match = RegExp(r'DATE OF BIRTH:\s*(.+)', caseSensitive: false).firstMatch(lines[i]);
        if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
          birthdate = match.group(1)!.trim();
        }
      }
    }

    List<String> nameParts = fullName.split(" ");
    String firstName = '';
    String middleInitial = '';
    String lastName = '';

    if (nameParts.isNotEmpty) {
      firstName = nameParts[0];

      if (nameParts.length > 1) {
        String secondPart = nameParts[1];

        if (secondPart.length == 2 && secondPart[1] == '.') {
          middleInitial = secondPart; // Middle initial
          lastName = nameParts.sublist(2).join(" ");
        } else {
          lastName = nameParts.sublist(1).join(" ");
        }
      }
    }
    return {
      "fullName": fullName,
      "firstName": firstName,
      "middleInitial": middleInitial,
      "lastName": lastName,
      "address": address,
      "birthdate": birthdate,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const InstructionsDialog(),
      );
    });
  }

  Future<void> pickImage({required bool isFront, required bool fromCamera}) async {
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      final extractedText = await extractTextFromImage(imageFile);

      setState(() {
        if (isFront) {
          frontIdImage = imageFile;
          frontIdText = extractedText;
        } else {
          backIdImage = imageFile;
          backIdText = extractedText;
        }
      });
    }
  }

  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    return recognizedText.text;
  }

  void goToNextPage() {
    final parsedFront = parseIdText(frontIdText);
    final parsedBack = parseIdText(backIdText);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalDetailsPage(
          frontData: parsedFront,
          backData: parsedBack,
        ),
      ),
    );
  }

  void _handleNext() async {
    if (frontIdImage == null || backIdImage == null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          title: const Text(
            "Continue without ID?",
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            "Are you sure you don't want to use ID to verify your details?",
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Continue", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    goToNextPage();
  }

  void showImageSourcePicker({required bool isFront}) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  pickImage(isFront: isFront, fromCamera: true);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  pickImage(isFront: isFront, fromCamera: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
                  (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Instructions',
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const InstructionsDialog(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height - kToolbarHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Changed from spaceBetween to start
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Image(
                    image: AssetImage('assets/ACCAP_LOGO.png'),
                    width: 100,
                    height: 100,
                  ),
                  Stack(
                    children: [
                      Text("ACCAP",
                        style: TextStyle(
                          letterSpacing: 3.0,
                          fontFamily: "Inter",
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3
                            ..color = Color.fromARGB(255, 28, 113, 166),
                        ),
                      ),
                      Text("ACCAP",
                        style: TextStyle(
                          letterSpacing: 3.0,
                          fontFamily: "Inter",
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Color.fromARGB(255, 28, 113, 166),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    "Accessibility-Centered Community\nApplication for PWD",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => showImageSourcePicker(isFront: true),
                    icon: Icon(Icons.photo_camera),
                    label: Text("Upload Front of ID"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 0, 48, 96),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: frontIdImage != null
                        ? Image.file(frontIdImage!, height: 100)
                        : SizedBox(height: 100),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => showImageSourcePicker(isFront: false),
                    icon: Icon(Icons.photo_camera_back),
                    label: Text("Upload Back of ID"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 0, 48, 96),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: backIdImage != null
                        ? Image.file(backIdImage!, height: 100)
                        : SizedBox(height: 100),
                  ),
                ],
              ),
              const SizedBox(height: 30), // Add spacing above the NEXT button
              Center(
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 0, 48, 96),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      );
  }
}