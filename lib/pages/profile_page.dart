import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase/pages/resume_viewer.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase/pages/login_page.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/text_size.dart';
import 'full_image_viewer.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userDetails;

  const ProfilePage({super.key, required this.userDetails});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? profileImageUrl;
  String? coverImageUrl;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool isEditing = false;
  late TextEditingController firstNameController;
  late TextEditingController middleNameController;
  late TextEditingController lastNameController;
  late TextEditingController birthdateController;
  late TextEditingController contactNumberController;
  late TextEditingController addressController;
  late TextEditingController disabilityTypeController;


  @override
  void initState() {
    super.initState();
    profileImageUrl = widget.userDetails['profileImageUrl'];
    coverImageUrl = widget.userDetails['coverImageUrl'];
    firstNameController = TextEditingController(text: widget.userDetails['firstName'] ?? '');
    middleNameController = TextEditingController(text: widget.userDetails['middleName'] ?? '');
    lastNameController = TextEditingController(text: widget.userDetails['lastName'] ?? '');
    birthdateController = TextEditingController(text: widget.userDetails['birthdate'] ?? '');
    contactNumberController = TextEditingController(text: widget.userDetails['contactNumber'] ?? '');
    addressController = TextEditingController(text: widget.userDetails['address'] ?? '');
    disabilityTypeController = TextEditingController(text: widget.userDetails['disabilityType'] ?? '');
    fetchUserImages();
  }
  List<String> disabilityTypes = [
    'Visual Impairment',
    'Hearing Impairment',
    'Mobility Impairment',
    'Speech Impairement',
  ];

  String? selectedDisabilityType;

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    birthdateController.dispose();
    contactNumberController.dispose();
    addressController.dispose();
    disabilityTypeController.dispose();
    super.dispose();
  }

  Future<void> deleteProfileOrCoverImage({required bool isCover}) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    String? imageUrl = isCover ? coverImageUrl : profileImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        isCover ? 'coverImageUrl' : 'profileImageUrl': FieldValue.delete(),
      });

      setState(() {
        if (isCover) {
          coverImageUrl = null;
        } else {
          profileImageUrl = null;
        }
      });
    } catch (e) {

    }
  }

  Future<void> fetchUserImages() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        profileImageUrl = userDoc['profileImageUrl'] ?? '';
        coverImageUrl = userDoc['coverImageUrl'] ?? '';
        print("Fetched profile image URL: $profileImageUrl");
        print("Fetched cover image URL: $coverImageUrl");
      });
    } else {
      print("User document does not exist!");
    }
  }


  Future<void> uploadResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);

      if (file.lengthSync() > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File too large! Please select a file under 5MB.')),
        );
        return;
      }

      try {
        String userId = FirebaseAuth.instance.currentUser!.uid;
        String fileName = "resume.pdf";
        Reference ref = _storage.ref().child('user_resumes/$userId/$fileName');

        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

        if (snapshot.state == TaskState.success) {
          String resumeUrl = await ref.getDownloadURL();
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'resumeUrl': resumeUrl,
          });

          setState(() {
            widget.userDetails['resumeUrl'] = resumeUrl;
          });
        } else {
          throw Exception("Upload failed");
        }
      } catch (e) {
        print("Upload error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void openResume(String url) async {
    Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open resume!')),
      );
    }
  }

  int calculateAge(String birthdate) {
    DateTime birthDate = DateTime.parse(birthdate);
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;

    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month && currentDate.day < birthDate.day)) {
      age--;
    }

    return age;
  }


  Future<void> saveProfileChanges() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'birthdate': birthdateController.text.trim(),
        'contactNumber': contactNumberController.text.trim(),
        'address': addressController.text.trim(),
        'disabilityType': disabilityTypeController.text.trim(),
      });

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          Future.delayed(Duration(seconds: 1, milliseconds: 500), () {
            Navigator.of(context).pop();
          });
          return AlertDialog(
            title: Text('Success'),
            content: Text('Profile updated successfully!'),
            actions: <Widget>[
            ],
          );
        },
      );


      setState(() {
        widget.userDetails['firstName'] = firstNameController.text;
        widget.userDetails['middleName'] = middleNameController.text;
        widget.userDetails['lastName'] = lastNameController.text;
        widget.userDetails['birthdate'] = birthdateController.text;
        widget.userDetails['contactNumber'] = contactNumberController.text;
        widget.userDetails['address'] = addressController.text;
        widget.userDetails['disabilityType'] = disabilityTypeController.text;
      });
    } catch (e) {
      print("Error saving profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }


  Future<void> uploadImage(bool isCover) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    File file = File(pickedFile.path);

    // Check if the file is too large
    if (file.lengthSync() > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large! Please select an image under 5MB.')),
      );
      return;
    }

    try {
      String fileName = path.basename(file.path);
      String userId = FirebaseAuth.instance.currentUser!.uid;
      Reference ref = _storage.ref().child('user_images/$userId/$fileName');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        String imageUrl = await ref.getDownloadURL();
        print("Image uploaded successfully: $imageUrl");

        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          isCover ? 'coverImageUrl' : 'profileImageUrl': imageUrl,
        });

        setState(() {
          if (isCover) {
            coverImageUrl = imageUrl;
          } else {
            profileImageUrl = imageUrl;
          }
        });

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            Future.delayed(Duration(seconds: 1, milliseconds: 500), () {
              Navigator.of(context).pop();
            });
            return AlertDialog(
              title: Text('Success'),
              content: Text('Image Uploaded Successfully'),
              actions: <Widget>[],
            );
          },
        );

      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    String fullName =
    "${widget.userDetails['firstName']} "
        "${(widget.userDetails['middleName'] != null && widget.userDetails['middleName'].isNotEmpty) ? widget.userDetails['middleName'] + ' ' : ''}"
        "${widget.userDetails['lastName']}".trim();

    String birthdate = widget.userDetails['birthdate'] ?? '';
    int age = calculateAge(birthdate);
    return Scaffold(
      backgroundColor: Color.fromARGB(255,250, 250, 250),
      appBar: AppBar(
        title: const Text(
          "PROFILE",
          style: TextStyle(
            color: Color.fromARGB(255, 250, 250, 250),
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
          onPressed: () { HapticService.instance.selection(); Navigator.pop(context); },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                GestureDetector(
                  onTap: () {
                    if (isEditing || coverImageUrl == null || coverImageUrl!.isEmpty) {
                      HapticService.instance.selection();
                      uploadImage(true);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullImageViewer(
                            imageUrl: coverImageUrl!,
                            onDelete: () async {
                              await deleteProfileOrCoverImage(isCover: true);
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            onChange: () async {
                              await uploadImage(true);
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.grey[300],
                    child: coverImageUrl != null
                        ? Image.network(
                      coverImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                        : const Icon(Icons.add_a_photo, size: 50),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: GestureDetector(
                    onTap: () {
                      HapticService.instance.selection();
                      if (isEditing || profileImageUrl == null || profileImageUrl!.isEmpty) {
                        uploadImage(false);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullImageViewer(
                              imageUrl: profileImageUrl!,
                              onDelete: () async {
                                await deleteProfileOrCoverImage(isCover: false);
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              onChange: () async {
                                await uploadImage(false);
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: profileImageUrl != null
                          ? ClipOval(
                        child: Image.network(
                          profileImageUrl!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error, size: 40, color: Colors.red);
                          },
                        ),
                      )
                          : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Text(
              fullName,
              style: TextStyle(fontSize: fontSize + 8, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 250, 250, 250),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEditing) ...[
                      buildEditableTextField("First Name", firstNameController, context),
                      buildEditableTextField("Middle Name", middleNameController, context),
                      buildEditableTextField("Last Name", lastNameController, context),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildEditableTextField("Birthdate", birthdateController, context),
                        ),
                        const SizedBox(width: 8),
                        if (!isEditing)
                          Expanded(
                            child: buildEditableTextField("Age", TextEditingController(text: age.toString()), context),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: buildEditableTextField("Contact Number", contactNumberController, context),
                        ),
                        const SizedBox(height: 8),
                        if (isEditing)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedDisabilityType,
                              hint: Text(
                                "Select Disability",
                                style: const TextStyle(fontSize: 12),
                              ),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedDisabilityType = newValue;
                                  disabilityTypeController.text = newValue ?? '';
                                });
                              },
                              items: disabilityTypes.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              decoration: InputDecoration(
                                labelText: "Disability Type",
                                labelStyle: const TextStyle(fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              isExpanded: true,
                            ),
                          )
                        else
                          Expanded(
                            child: buildEditableTextField("Disability Type", disabilityTypeController, context),
                          ),
                      ],
                    ),
                    buildEditableTextField("Address", addressController, context),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isEditing) {
                            saveProfileChanges();
                          }
                          setState(() {
                            isEditing = !isEditing;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEditing
                              ? Colors.green
                              : const Color.fromARGB(255, 5, 92, 157),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(
                          isEditing ? 'SAVE' : 'EDIT',
                          style: TextStyle(color: Colors.white, fontSize: fontSize - 5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
            widget.userDetails['resumeUrl'] != null
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResumeViewer(pdfUrl: widget.userDetails['resumeUrl']!),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 5, 92, 157),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      "View Resume",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize - 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: uploadResume,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(254, 15, 48, 96),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      "Reupload Resume",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize - 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            ): Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
              onPressed: uploadResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(254, 15, 48, 96),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                "Upload Resume",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize + 2, // Slightly larger for emphasis
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            )
          ],
        ),
      ),
    );
  }

  Widget buildReadOnlyDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDetailText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget buildEditableTextField(String label, TextEditingController controller, BuildContext context) {
    final fontSize = Provider.of<TextSizeProvider>(context).fontSize;
    final isBirthdate = label.toLowerCase() == 'birthdate';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: isEditing
          ? TextFormField(
        controller: controller,
        readOnly: isBirthdate,
        onTap: isBirthdate
            ? () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime(2007),
          );
          if (pickedDate != null) {
            controller.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          }
        }
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: fontSize - 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          suffixIcon: isBirthdate ? const Icon(Icons.calendar_today) : null,
        ),
        style: TextStyle(fontSize: fontSize - 4),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: fontSize - 4, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              controller.text.isNotEmpty ? controller.text : '-',
              style: TextStyle(fontSize: fontSize - 4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void signOut(BuildContext context) async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
                      (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage(onTap: () {})),
              (route) => false,
        );
      }
    }
  }
}