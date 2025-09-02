import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRequestPage extends StatefulWidget {
  final String requestId;
  final String initialMessage;

  const EditRequestPage({super.key, required this.requestId, required this.initialMessage});

  @override
  State<EditRequestPage> createState() => _EditRequestPageState();
}

class _EditRequestPageState extends State<EditRequestPage> {
  TextEditingController messageController = TextEditingController();
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    messageController.text = widget.initialMessage;
  }

  Future<void> updateRequestMessage() async {
    if (messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message cannot be empty.")),
      );
      return;
    }

    setState(() => isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('request_assistance_notifications')
          .doc(widget.requestId)
          .update({"message": messageController.text.trim()});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request updated successfully!")),
      );

      Navigator.pop(context, messageController.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating request.")),
      );
    } finally {
      setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Request")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Request Message:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isUpdating ? null : updateRequestMessage,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: isUpdating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}