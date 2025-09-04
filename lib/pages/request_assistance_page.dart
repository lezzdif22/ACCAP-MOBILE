import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import '../services/sms_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../components/text_size.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _whereController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _deliverDateController = TextEditingController();
  final TextEditingController _pickupDateController = TextEditingController();
  final TextEditingController _whenDateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _pickupTimeController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  File? _selectedImage;
  String? _selectedCategory = "Medication";
  String? _pickupOrDelivery;
  String? _tripOption;
  bool _needsWheelchair = false;
  TimeOfDay? _selectedTime;
  bool _isButtonPressed = false;
  double _buttonScale = 1.0;
  double _buttonOpacity = 1.0;
  Color _buttonColor = Color.fromARGB(255, 30, 136, 229);
  double _pulseScale = 1.0;
  Timer? _pulseTimer;
  bool _showSosButton = false;
  bool _isProcessing = false;
  String _instructionText = "Press SOS for emergency";
  Color _instructionColor = Colors.white;
  double _holdProgress = 0.0;
  Timer? _holdProgressTimer;
  String? _selectedEmergencyType;
  Position? _currentPosition;
  final TextEditingController _emergencyDescriptionController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  String? _selectedDisabilityType;
  final bool _isEmergencyDescriptionSubmitted = false;

  @override
  void initState() {
    super.initState();
    _startPulseAnimation();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showSosButton = true;
        });
      }
    });
  }

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
      if (mounted && !_isProcessing) {
        setState(() {
          _pulseScale = _pulseScale == 1.0 ? 1.1 : 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _locationController.dispose();
    _whereController.dispose();
    _dateController.dispose();
    _deliverDateController.dispose();
    _pickupDateController.dispose();
    _whenDateController.dispose();
    _timeController.dispose();
    _pickupTimeController.dispose();
    _pulseTimer?.cancel();
    _holdProgressTimer?.cancel();
    _destinationController.dispose();
    _emergencyDescriptionController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  void _clearInputs() {
    _medicineNameController.clear();
    _addressController.clear();
    _destinationController.clear();
    _reasonController.clear();
    _locationController.clear();
    _whereController.clear();
    _whenDateController.clear();
    _deliverDateController.clear();
    _pickupDateController.clear();
    _dateController.clear();
    _timeController.clear();
    _pickupTimeController.clear();
    _pickupOrDelivery = null;
    _needsWheelchair = false;
    _tripOption = null;
    _selectedImage = null;
    setState(() {});
  }

  void _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          child: child!,
        );
      },
    );

    if (mounted) {
      setState(() {
        controller.text = "${pickedDate!.toLocal()}".split(' ')[0];
      });
    }
  }

  void _selectTime(BuildContext context, TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color.fromARGB(255, 255, 255, 250),
              dialBackgroundColor: Color.fromARGB(255, 0, 48, 96),
              dialHandColor: Colors.black,
              hourMinuteColor: Color.fromARGB(255, 250, 250, 250),
              hourMinuteTextColor: Color.fromARGB(255, 0, 48, 96),
              hourMinuteTextStyle: const TextStyle(
                color: Color.fromARGB(255, 0, 48, 96),
                fontSize: 24,
              ),
              dialTextColor: Colors.white,
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.white),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.black),
              entryModeIconColor: Colors.black,
              helpTextStyle: const TextStyle(color: Colors.black),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  HapticService.instance.buttonPress();
  _showPopUpDialog();
  }

  Future<Position?> _getCurrentLocation() async {
    // Request location permissions first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied, we cannot request permissions.'),
          ),
        );
      }
      return null;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
      return null;
    }
  }

  void _showPopUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            if (_isProcessing) {
              return false;
            }
            return true;
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 300,
              height: 400, // Increased height to prevent overflow
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Emergency Alert",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _instructionText,
                    style: TextStyle(
                      fontSize: 16,
                      color: _instructionColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  GestureDetector(
                    onTapDown: (_) => _startLongPressTimer(),
                    onTapUp: (_) => _cancelLongPressTimer(),
                    onTapCancel: () => _cancelLongPressTimer(),
                    child: Transform.scale(
                      scale: _buttonScale,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 200),
                        opacity: _buttonOpacity,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red, // Always red
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!_isProcessing) ...[
                                // Progress ring
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(
                                    value: _holdProgress,
                                    backgroundColor: Colors.white.withOpacity(0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                    strokeWidth: 4,
                                  ),
                                ),
                                // SOS text
                                Text(
                                  "SOS",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 30),
                    onPressed: () {
                      if (_isProcessing) {
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Timer? _longPressTimer;
  void _startLongPressTimer() {
    if (_isProcessing) return;
    
    setState(() {
      _isButtonPressed = true;
      _buttonScale = 0.95;
      _buttonOpacity = 0.8;
      _buttonColor = Colors.red;
      _pulseScale = 1.0;
      _instructionText = "Hold for 2 seconds to add emergency description...";
      _instructionColor = Colors.orange;
      _holdProgress = 0.0;
    });

    // Start progress timer with faster updates
    _holdProgressTimer = Timer.periodic(Duration(milliseconds: 20), (timer) {
      if (_isButtonPressed) {
        setState(() {
          _holdProgress = (_holdProgress + 0.01).clamp(0.0, 1.0);
          // Update text based on progress
          if (_holdProgress < 0.3) {
            _instructionText = "Hold for 2 seconds to add emergency description...";
          } else if (_holdProgress < 0.6) {
            _instructionText = "Almost there...";
          } else if (_holdProgress < 1.0) {
            _instructionText = "Get ready to add description...";
          }
        });
      } else {
        timer.cancel();
      }
    });
    
    _longPressTimer = Timer(Duration(seconds: 2), () async {
      if (!_isButtonPressed) return;
      
      try {
        HapticService.instance.heavyImpactWithVibration();
        try {
          await HapticService.instance.vibratePattern([0, 150, 50, 200]);
        } catch (e) {
          // ignore vibration errors
        }
    Navigator.pop(context);
    _showEmergencyDescriptionDialog();
      } catch (e) {
        print('Error in long press timer: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting emergency alert. Please try again.')),
          );
        }
        _cancelLongPressTimer();
      }
    });
  }

  void _cancelLongPressTimer() {
    _isButtonPressed = false;
    _longPressTimer?.cancel();
    _holdProgressTimer?.cancel();
    
    setState(() {
      _isProcessing = false;
      _buttonScale = 1.0;
      _buttonOpacity = 1.0;
      _buttonColor = Color.fromARGB(255, 30, 136, 229);
      _instructionText = "Press SOS for emergency";
      _instructionColor = Colors.white;
      _holdProgress = 0.0;
    });
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 250, 250, 250),
          title: const Text("Are you sure you want to exit?"),
          content: const Text("If you exit, you will cancel the emergency request."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel",style: TextStyle(color: Color.fromARGB(250, 0, 0, 0)),),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Exit", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<String> generateTicketNumber() async {
    DocumentReference counterRef = _firestore.collection("counters").doc("request_counter");

    return await _firestore.runTransaction((transaction) async {
      DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

      int newRequestNumber = 25000;

      if (counterSnapshot.exists) {
        newRequestNumber = (counterSnapshot.get("lastRequest") as int) + 1;
      }

      transaction.set(counterRef, {"lastRequest": newRequestNumber});

      return newRequestNumber.toString();
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  bool _isSendingRequest = false;

  Future<void> sendRequest() async {
    if (_isSendingRequest) return;

    setState(() {
      _isSendingRequest = true;
    });

    try {
      if (_selectedCategory == null) {
        setState(() => _isSendingRequest = false);
        return;
      }

      String? imageUrl;

      if (_selectedCategory == "Medication") {
        if (_selectedImage != null) {
          imageUrl = await _uploadImage(_selectedImage!);
          print("Received image URL: $imageUrl");
        }
      }

      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        String fullName = "Unknown User";
        if (userDoc.exists) {
          String firstName = userDoc['firstName'] ?? "Unknown";
          String lastName = userDoc['lastName'] ?? "User";
          fullName = "$firstName $lastName";
        }
        String RequestNumber = await generateTicketNumber();

        Map<String, dynamic> requestData = {
          "user": user.email,
          "name": fullName,
          "category": _selectedCategory,
          "status": "Open",
          "requestNumber": RequestNumber,
          "timestamp": FieldValue.serverTimestamp(),
        };

        String collectionName = "";
        if (_selectedCategory == "Medication") {
          collectionName = "medication_requests";
          requestData.addAll({
            "medicineName": _medicineNameController.text.trim(),
            "medicine_image": imageUrl,
            "date": _dateController.text.trim(),
            "requestedTime": _timeController.text.trim(),
            "pickupOrDelivery": _pickupOrDelivery,
            "address": _addressController.text.trim(),
          });
        } else if (_selectedCategory == "Wheelchair") {
          collectionName = "wheelchair_requests";
          requestData.addAll({
            "reason": _reasonController.text.trim(),
            "location": _locationController.text.trim(),
            "dateToDeliver": _deliverDateController.text.trim(),
            "deliveryTime": _timeController.text.trim(),
            "dateToPickUp": _pickupDateController.text.trim(),
            "pickupTime": _pickupTimeController.text.trim(),
          });
        } else if (_selectedCategory == "Transportation Service") {
          collectionName = "service_requests";
          requestData.addAll({
            "needsWheelchair": _needsWheelchair,
            "reason": _reasonController.text.trim(),
            "pickup_location": _whereController.text.trim(),
            "pickup_date": _whenDateController.text.trim(),
            "pickup_time": _timeController.text.trim(),
            "destination": _destinationController.text.trim(),
            "tripType": _tripOption,
          });
        }

        if (collectionName.isNotEmpty) {
          await _firestore.collection(collectionName).add(requestData);
        }

        _clearInputs();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            Future.delayed(Duration(seconds: 1, milliseconds: 500), () {
              Navigator.of(context).pop();
            });
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text('Success'),
              content: Text('Request sent successfully! Request Number: $RequestNumber'),
              actions: <Widget>[
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isProcessing) {
      print('Cannot start recording: Processing');
      return;
    }
  }

  Future<String?> _stopRecording() async {
    if (_isProcessing) {
      print('Cannot stop recording: Processing');
      return null;
    }
    return null;
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      Reference storageRef = FirebaseStorage.instance.ref().child("images/${DateTime.now().millisecondsSinceEpoch}.jpg");
      UploadTask uploadTask = storageRef.putFile(imageFile);

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      print("Image uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  void _showEmergencyTypeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            "Select Emergency Type",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEmergencyButton(
                icon: Icons.local_fire_department,
                label: "Fire",
                type: "fire",
              ),
              SizedBox(height: 10),
              _buildEmergencyButton(
                icon: Icons.medical_services,
                label: "Injured",
                type: "injured",
              ),
              SizedBox(height: 10),
              _buildEmergencyButton(
                icon: Icons.local_hospital,
                label: "Hospital",
                type: "hospital",
              ),
              SizedBox(height: 10),
              _buildEmergencyButton(
                icon: Icons.emergency,
                label: "Ambulance",
                type: "ambulance",
              ),
              SizedBox(height: 10),
              _buildEmergencyButton(
                icon: Icons.local_police,
                label: "Police",
                type: "police",
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyButton({
    required IconData icon,
    required String label,
    required String type,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        double holdProgress = 0.0;
        Timer? holdTimer;
        bool isHolding = false;

        void startHold() {
          isHolding = true;
          holdProgress = 0.0;
          holdTimer = Timer.periodic(Duration(milliseconds: 20), (timer) {
            if (!isHolding) {
              timer.cancel();
              setState(() => holdProgress = 0.0);
              return;
            }
            setState(() {
              holdProgress += 0.01;
              if (holdProgress >= 1.0) {
                holdProgress = 1.0;
                timer.cancel();
                isHolding = false;
                _selectedEmergencyType = type;
                Navigator.pop(context);
                _sendEmergencyNotification();
              }
            });
          });
        }

        void cancelHold() {
          isHolding = false;
          holdTimer?.cancel();
          setState(() => holdProgress = 0.0);
        }

        return GestureDetector(
          onTapDown: (_) => startHold(),
          onTapUp: (_) => cancelHold(),
          onTapCancel: () => cancelHold(),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
                if (isHolding)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: holdProgress,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendEmergencyNotification() async {
    try {
      setState(() {
        _isProcessing = true;
        _instructionText = "Getting location...";
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final firstName = data['firstName'] ?? '';
          final middleName = data['middleName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final fullName = "$firstName $middleName $lastName".trim();

          // Get contact number and disability type from Firestore
          final contactNumber = data['contactNumber'] ?? '';
          final disabilityType = data['disabilityType'] ?? 'None';

          // Get current location
          Position? position = await _getCurrentLocation();
          if (position == null) {
            throw Exception('Could not get location');
          }

          // Get location name from coordinates
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          String locationName = "Unknown Location";
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            locationName = [
              place.street,
              place.subLocality,
              place.locality,
              place.administrativeArea,
            ].where((s) => s != null && s.isNotEmpty).join(", ");
          }
          
          String locationString = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

          // Create location data JSON
          Map<String, dynamic> locationData = {
            'title': 'Emergency Alert',
            'message': '$fullName has triggered a $_selectedEmergencyType emergency.',
            'timestamp': DateTime.now().toIso8601String(),
            'userFullName': fullName,
            'type': 'sos',
            'emergencyType': _selectedEmergencyType,
            'userId': currentUser.uid,
            'location': locationString,
            'locationName': locationName,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'status': 'pending',
            'emergencyStatus': 'Pending',
            'adminViewed': false,
            'description': _emergencyDescriptionController.text.trim(),
            'contactNumber': contactNumber,
            'disabilityType': disabilityType,
          };

          // Convert to JSON string
          String jsonString = jsonEncode(locationData);

          // Create a unique filename using user's name and timestamp
          String safeName = fullName.replaceAll(' ', '_');
          String fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.json';

          // Upload to Firebase Storage
          Reference storageRef = FirebaseStorage.instance.ref().child('emergency_locations/$fileName');
          await storageRef.putString(jsonString);

          // Get the download URL
          String downloadUrl = await storageRef.getDownloadURL();

          // Store the reference in Firestore
          await FirebaseFirestore.instance.collection('notifications').add({
            'title': 'Emergency Alert',
            'message': '$fullName has triggered a $_selectedEmergencyType emergency.',
            'timestamp': FieldValue.serverTimestamp(),
            'userFullName': fullName,
            'type': 'sos',
            'emergencyType': _selectedEmergencyType,
            'userId': currentUser.uid,
            'locationDataUrl': downloadUrl,
            'locationName': locationName,
            'status': 'pending',
            'emergencyStatus': 'Sent',
            'adminViewed': false,
            'description': _emergencyDescriptionController.text.trim(),
            'contactNumber': contactNumber,
            'disabilityType': disabilityType,
          });

          // Send SMS to admin
          try {
            bool smsSent = await SmsService().sendEmergencySms(
              userName: fullName,

              emergencyType: _selectedEmergencyType ?? 'Unknown',
              locationName: locationName,
              mapLink: locationString,
              description: _emergencyDescriptionController.text.trim(),
              contactNumber: contactNumber,
              disabilityType: disabilityType,
            );
            
            if (smsSent) {
              print('Emergency SMS sent successfully to admin');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Emergency SMS sent to admin successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            } else {
              print('Failed to send emergency SMS to admin');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send SMS. Please check SMS permissions.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error sending SMS: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error sending SMS: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }

          if (mounted) {
            try {
              await HapticService.instance.vibrate(200);
            } catch (e) {}
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Emergency Alert Sent"),
                  backgroundColor: Color.fromARGB(255, 250, 250, 250),
                  content: const Text("Your emergency alert has been sent successfully!"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Clear the emergency form
                        _emergencyDescriptionController.clear();
                        _selectedEmergencyType = null;
                      },
                      child: const Text("OK", style: TextStyle(color: Colors.black)),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending notification. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _instructionText = "Press SOS for emergency";
        });
      }
    }
  }

  void _showEmergencyDescriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            "Emergency Description",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emergencyDescriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Describe the emergency situation...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEmergencyTypeDialog();
              },
              child: Text("Next"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSizeProvider = Provider.of<TextSizeProvider>(context);
    final fontSize = textSizeProvider.fontSize;
    return Scaffold(
      backgroundColor: Color.fromARGB(255,250, 250, 250),
      appBar: AppBar(
        title: const Text("Request Assistance"),
        backgroundColor: Color.fromARGB(255, 250, 250, 250),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticService.instance.buttonPress();
            TalkBackService.instance.speak("Going back from request assistance");
            Navigator.pop(context);
          },
        ),
      ),
          body: GestureDetector(
            onVerticalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
            _showPopUpDialog();
              }
            },
            child: RefreshIndicator(
            onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
            _showPopUpDialog();
          },
          child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: const Color.fromARGB(255, 250, 250, 250),
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Select Assistance Type",
                    labelStyle: TextStyle(
                      fontSize: fontSize - 3,
                      color: Colors.black,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  items: ["Medication", "Wheelchair", "Transportation Service"].map((String category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        style: TextStyle(fontSize: fontSize - 3),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    HapticService.instance.buttonPress();
                    setState(() {
                      _selectedCategory = value;
                      _clearInputs();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedCategory == "Medication") ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _medicineNameController,
                      decoration: InputDecoration(
                        labelText: null,
                        labelStyle: TextStyle(fontSize: fontSize - 3),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        hintText: "Name of medicine (if multiple,\nseparate with commas — e.g., Bioflu, Biogesic)",
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                      style: TextStyle(fontSize: fontSize),
                      maxLines: 2,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () { HapticService.instance.buttonPress(); _pickImage(); },
                    child: Container(
                      padding: EdgeInsets.all(4), // Reduced padding to make the box smaller
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, color: Colors.blue, size: 24),
                              SizedBox(width: 6),
                              Text("Upload Image", style: TextStyle(color: Colors.blue, fontSize: fontSize - 4)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          if (_selectedImage != null) ...[
                            Image.file(
                              _selectedImage!,
                              height: 60, // Smaller image size
                              width: 60,  // Smaller image size
                              fit: BoxFit.cover,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () { HapticService.instance.buttonPress(); _selectDate(context, _dateController); },
                          child: AbsorbPointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: TextFormField(
                                controller: _dateController,
                                onTap: () {
                                  TalkBackService.instance.speak("Date field, select a date");
                                },
                                decoration: InputDecoration(
                                  labelText: "Date",
                                  hintText: "Select Date",
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  hintStyle: TextStyle(fontSize: fontSize),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                                ),
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () { HapticService.instance.buttonPress(); _selectTime(context, _timeController); },
                          child: AbsorbPointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: TextFormField(
                                controller: _timeController,
                                decoration: InputDecoration(
                                  labelText: "Time",
                                  hintText: "Select Time",
                                  labelStyle: TextStyle(fontSize: fontSize),
                                  hintStyle: TextStyle(fontSize: fontSize),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  suffixIcon: Icon(Icons.access_time, color: Colors.grey),
                                ),
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: "Address",
                        labelStyle: TextStyle(fontSize: fontSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          value: "Pickup",
                          groupValue: _pickupOrDelivery,
                          title:  Text("Pickup",  style: TextStyle(fontSize: fontSize - 6)),
                          onChanged: (value) => setState(() => _pickupOrDelivery = value),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          value: "Delivery",
                          groupValue: _pickupOrDelivery,
                          title:  Text("Delivery",  style: TextStyle(fontSize: fontSize - 6)),
                          onChanged: (value) => setState(() => _pickupOrDelivery = value),
                        ),
                      ),
                    ],
                  ),
                ],

                if (_selectedCategory == "Wheelchair") ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 5,
                      minLines: 1,
                      decoration:  InputDecoration(
                        labelText: "Reason for Request",
                        labelStyle: TextStyle(fontSize: fontSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: "Address",
                        labelStyle: TextStyle(fontSize: fontSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        "When do you need it?",
                        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () { HapticService.instance.buttonPress(); _selectDate(context, _deliverDateController); },
                              child: AbsorbPointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: TextFormField(
                                    controller: _deliverDateController,
                                    decoration: InputDecoration(
                                      labelText: "Date",
                                      hintText: "Select Date",
                                      labelStyle: TextStyle(fontSize: fontSize),
                                      hintStyle: TextStyle(fontSize: fontSize),
                                      border: InputBorder.none,
                                      suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    ),
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () { HapticService.instance.buttonPress(); _selectTime(context, _timeController); },
                              child: AbsorbPointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: TextFormField(
                                    controller: _timeController,
                                    decoration:  InputDecoration(
                                      labelText: "Time",
                                      hintText: "Select Time",
                                      labelStyle: TextStyle(fontSize: fontSize),
                                      hintStyle: TextStyle(fontSize: fontSize),
                                      border: InputBorder.none,
                                      suffixIcon: Icon(Icons.access_time, color: Colors.grey),
                                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    ),
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        "When will you return it?",
                        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () { HapticService.instance.buttonPress(); _selectDate(context, _pickupDateController); },
                              child: AbsorbPointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: TextFormField(
                                    controller: _pickupDateController,
                                    decoration:  InputDecoration(
                                      labelText: "Date",
                                      hintText: "Select Date",
                                      labelStyle: TextStyle(fontSize: fontSize),
                                      hintStyle: TextStyle(fontSize: fontSize),
                                      border: InputBorder.none,
                                      suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    ),
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () { HapticService.instance.buttonPress(); _selectTime(context, _pickupTimeController); },
                              child: AbsorbPointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: TextFormField(
                                    controller: _pickupTimeController,
                                    decoration:  InputDecoration(
                                      labelText: "Time",
                                      hintText: "Select Time",
                                      labelStyle: TextStyle(fontSize: fontSize),
                                      hintStyle: TextStyle(fontSize: fontSize),
                                      border: InputBorder.none,
                                      suffixIcon: Icon(Icons.access_time, color: Colors.grey),
                                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    ),
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],

                if (_selectedCategory == "Transportation Service") ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _reasonController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: "Reason for Request",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _whereController,
                      decoration:  InputDecoration(
                        labelText: "Pickup Location",
                        labelStyle: TextStyle(fontSize: fontSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () { HapticService.instance.buttonPress(); _selectDate(context, _whenDateController); },
                    child: AbsorbPointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: TextFormField(
                          controller: _whenDateController,
                          decoration:  InputDecoration(
                            labelText: "When do you need pickup?",
                            hintText: "Select Date",
                            labelStyle: TextStyle(fontSize: fontSize-4),
                            hintStyle: TextStyle(fontSize: fontSize),
                            border: InputBorder.none,
                            suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          ),
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () { HapticService.instance.buttonPress(); _selectTime(context, _timeController); },
                    child: AbsorbPointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: TextFormField(
                          controller: _timeController,
                          decoration:  InputDecoration(
                            labelText: "What time do you need pickup?",
                            hintText: "Select Time",
                            labelStyle: TextStyle(fontSize: fontSize-4),
                            hintStyle: TextStyle(fontSize: fontSize),
                            border: InputBorder.none,
                            suffixIcon: Icon(Icons.access_time, color: Colors.grey),
                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          ),
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: TextField(
                      controller: _destinationController,
                      decoration:  InputDecoration(
                        labelText: "Destination",
                        labelStyle: TextStyle(fontSize: fontSize),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                  const SizedBox(height: 10),

                  CheckboxListTile(
                    value: _needsWheelchair,
                    onChanged: (value) => setState(() => _needsWheelchair = value!),
                    title: Text("Need Wheelchair?", style: TextStyle(fontSize: fontSize)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: "One-Way-Trip",
                          groupValue: _tripOption,
                          title: Text("One-Way-Trip", style: TextStyle(fontSize: fontSize)),
                          onChanged: (value) {
                            setState(() {
                              _tripOption = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: "Round Trip",
                          groupValue: _tripOption,
                          title: Text("Round Trip", style: TextStyle(fontSize: fontSize)),
                          onChanged: (value) {
                            setState(() {
                              _tripOption = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                Semantics(
                  label: _isSendingRequest ? "Sending request" : "Send request",
                  hint: "Submit your assistance request",
                  child: ElevatedButton(
  onPressed: _isSendingRequest ? null : () { HapticService.instance.buttonPress(); sendRequest(); },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color.fromARGB(255, 0, 48, 96),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
  child: _isSendingRequest
      ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        )
      : const Text(
          "Send Request",
          style: TextStyle(color: Colors.white),
        ),
      ),
                ),
              ],
            ),
          ),
        ),
      ),
     ),
    );
  }
}
