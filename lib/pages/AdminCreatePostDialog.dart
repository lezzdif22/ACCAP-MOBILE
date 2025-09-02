import 'dart:io';
import 'package:flutter/foundation.dart'; // Import this for kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // Import for ImageSource
import 'package:image_picker_web/image_picker_web.dart'; // Import for Web support
import 'package:firebase_storage/firebase_storage.dart';

class AdminPostDialogContent extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;

  const AdminPostDialogContent({super.key, this.postId, this.initialData});

  @override
  State<AdminPostDialogContent> createState() => _AdminPostDialogContent();
  
}


class _AdminPostDialogContent extends State<AdminPostDialogContent> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedType = 'General';
  List<String> _selectedFilters = [];
  
  final List<String> _filters = [
    'All',
    'Hearing Impairment',
    'Speech Impairment',
    'Visual Impairment',
    "Mobility Impairment"
  ];

  bool _isPosting = false;
  final List<Uint8List> _selectedImageBytes = []; // Changed to list for multiple images
  final List<File> _selectedImages = []; // Changed to list for multiple images

  final ImagePicker _picker = ImagePicker(); // Initialize ImagePicker
  
@override
void initState() {
  super.initState();
  if (widget.initialData != null) {
    _titleController.text = widget.initialData!['title'] ?? '';
    _contentController.text = widget.initialData!['content'] ?? '';
    _selectedType = widget.initialData!['type'] ?? 'General';
    _selectedFilters = List<String>.from(widget.initialData!['filters'] ?? []);
  }
}

  Future<void> _pickImage() async {
    if (kIsWeb) {
      List<Uint8List>? pickedBytes = await ImagePickerWeb.getMultiImagesAsBytes();
      setState(() {
        _selectedImageBytes.addAll(pickedBytes!);
      });
        } else {
      final pickedFiles = await _picker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
      });
        }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];
    try {
      for (var i = 0; i < (kIsWeb ? _selectedImageBytes.length : _selectedImages.length); i++) {
        String fileName = "announcements/${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
        Reference ref = FirebaseStorage.instance.ref(fileName);

        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = ref.putData(_selectedImageBytes[i]);
        } else {
          uploadTask = ref.putFile(_selectedImages[i]);
        }

        TaskSnapshot snapshot = await uploadTask;
        uploadedUrls.add(await snapshot.ref.getDownloadURL());
      }
      return uploadedUrls;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload images: $e")),
      );
      return [];
    }
  }

 Future<void> _postAnnouncement() async {
  if (_titleController.text.isEmpty || _contentController.text.isEmpty) return;
  if (_isPosting) return;

  setState(() {
    _isPosting = true;
  });

  List<String> imageUrls = [];
  if (widget.initialData != null && widget.initialData!.containsKey('imageUrls')) {
    imageUrls = List<String>.from(widget.initialData!['imageUrls'] ?? []);
  }

  if (_selectedImages.isNotEmpty || _selectedImageBytes.isNotEmpty) {
    imageUrls = await _uploadImages();
  }

  final data = {
    'title': _titleController.text,
    'content': _contentController.text,
    'type': _selectedType,
    'filters': _selectedFilters,
    'timestamp': FieldValue.serverTimestamp(),
    'adminEmail': FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? 'unknown@domain.com',
    'imageUrls': imageUrls,
  };

  if (widget.postId != null) {
    await FirebaseFirestore.instance.collection('announcements').doc(widget.postId).update(data);
  } else {
    await FirebaseFirestore.instance.collection('announcements').add(data);
  }

  if (mounted) {
    Navigator.of(context).pop(); // close dialog after submit
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Announcement saved successfully!")),
    );
  }

  setState(() {
    _isPosting = false;
  });
}

  void _updateFilters(String filter, bool selected) {
    setState(() {
      if (filter == 'All') {
        _selectedFilters = selected ? ['All'] : [];
      } else {
        if (selected) {
          _selectedFilters.add(filter);
          _selectedFilters.remove('All');
        } else {
          _selectedFilters.remove(filter);
        }

        List<String> specificFilters = _filters.where((f) => f != 'All').toList();
        if (_selectedFilters.toSet().containsAll(specificFilters)) {
          _selectedFilters = ['All'];
        }
      }
    });
  }
  

  @override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16), // Dialog already provides padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.campaign, color: Color.fromARGB(255, 4, 57, 138), size: 32),
              SizedBox(width: 12),
              Text(
                "Create Post",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text("Post Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Wrap(
            spacing: 10,
            children: [
              for (var type in ['General', 'Seminar', 'Job Offering'])
                ChoiceChip(
                  label: Text(type),
                  selected: _selectedType == type,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),
          const Text("Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _filters.map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: _selectedFilters.contains(filter),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                selectedColor: const Color(0xFF0F3060),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: _selectedFilters.contains(filter) ? const Color.fromARGB(255, 4, 57, 138) : Colors.black,
                ),
                onSelected: (selected) => _updateFilters(filter, selected),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          const Text("Title", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Enter post title",
            ),
          ),

          const SizedBox(height: 16),

          const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Description for Ticket",
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: _pickImage,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: const BorderSide(color: Colors.black12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text("Select Images"),
          ),

          const SizedBox(height: 16),

          if (_selectedImages.isNotEmpty || _selectedImageBytes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Preview:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kIsWeb ? _selectedImageBytes.length : _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.memory(_selectedImageBytes[index], height: 150, fit: BoxFit.cover)
                                  : Image.file(_selectedImages[index], height: 150, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  if (kIsWeb) {
                                    _selectedImageBytes.removeAt(index);
                                  } else {
                                    _selectedImages.removeAt(index);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _postAnnouncement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3060),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Post Announcement", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    ),
  );
}
}