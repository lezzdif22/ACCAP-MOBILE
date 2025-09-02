import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class ResumeViewer extends StatefulWidget {
  final String pdfUrl;

  const ResumeViewer({super.key, required this.pdfUrl});

  @override
  _ResumeViewerState createState() => _ResumeViewerState();
}

class _ResumeViewerState extends State<ResumeViewer> {
  String? filePath;

  @override
  void initState() {
    super.initState();
    loadPdf();
  }

  Future<void> loadPdf() async {
    final response = await http.get(Uri.parse(widget.pdfUrl));
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/resume.pdf");
    await file.writeAsBytes(response.bodyBytes);
    setState(() {
      filePath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "RESUME",
          style: TextStyle(
            color: Color.fromARGB(255, 255, 255, 255),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 5.0,
          ),
        ),
        toolbarHeight: 70,
        flexibleSpace: Container(
          width: double.infinity,
          height: 70,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color.fromARGB(255, 0, 48, 96),
                width: 60.0,
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromARGB(255, 0, 48, 96),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
        backgroundColor : Color.fromARGB(255, 250, 250, 250),
      body: filePath == null
          ? const Center(child: CircularProgressIndicator())
          : PDFView(filePath: filePath!),
    );
  }
}