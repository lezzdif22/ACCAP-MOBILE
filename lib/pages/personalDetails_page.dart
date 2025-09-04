import 'package:firebase/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase/components/text_field.dart';
import 'package:flutter/services.dart';
import '../services/haptic_service.dart';
import '../services/talkback_service.dart';
import 'package:intl/intl.dart';

class PersonalDetailsPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onNext;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? frontData;
  final Map<String, dynamic>? backData;

  const PersonalDetailsPage({super.key, this.onNext, this.initialData, this.frontData, this.backData});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final birthdateController = TextEditingController();
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final fullNameController = TextEditingController();
  final addressController = TextEditingController();
  final contactNumberController = TextEditingController();

  DateTime? selectedDate;
  String disabilityType = "Hearing Impairment";

  final List<String> disabilityOptions = [
    "Hearing Impairment",
    "Speech Impairment",
    "Visual Impairment",
    "Mobility Impairment"
  ];

  @override
  void initState() {
    super.initState();

    if (widget.frontData != null) {
      String fullName = widget.frontData!["fullName"] ?? "";
      List<String> nameParts = fullName.split(" ");

      if (nameParts.isNotEmpty) {
        firstNameController.text = nameParts.length > 1
            ? nameParts.sublist(0, 2).join(" ")
            : nameParts[0];
        if (nameParts.length > 2) {
          List<String> lastNameParts = nameParts.sublist(2);
          List<String> cleanedLastNameParts = [];
          for (var part in lastNameParts) {
            var match = RegExp(r'^([A-Za-z]\.)([A-Za-z]+)$').firstMatch(part);
            if (match != null) {
              cleanedLastNameParts.add(match.group(2)!);
            } else if (!RegExp(r'^[A-Za-z]\.$').hasMatch(part)) {
              cleanedLastNameParts.add(part);
            }
          }
          lastNameController.text = cleanedLastNameParts.join(" ");
        } else {
          lastNameController.text = "";
        }
        middleNameController.text = "";
      }
    }

    if (widget.backData != null) {
      addressController.text = widget.backData!["address"] ?? "";
      if (widget.backData != null && widget.backData!["birthdate"] != null) {
        String birthdateString = widget.backData!["birthdate"].toString().trim();
        print('Extracted birthdate: "$birthdateString"');
        if (birthdateString.isNotEmpty && birthdateString != ":") {
          // Try to parse as a date, or just set the string
          DateTime? parsedDate;
          try {
            parsedDate = DateTime.parse(birthdateString);
          } catch (_) {}
          if (parsedDate == null) {
            try {
              parsedDate = DateFormat("MM/dd/yyyy").parse(birthdateString);
            } catch (_) {}
          }
          if (parsedDate != null) {
            selectedDate = parsedDate;
            birthdateController.text = DateFormat("yyyy-MM-dd").format(parsedDate);
          } else {
            birthdateController.text = birthdateString;
          }
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime currentDate = DateTime.now();
    DateTime latestAllowedDate = DateTime(2007, 12, 31);

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: latestAllowedDate,
      firstDate: DateTime(1900),
      lastDate: latestAllowedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Color.fromARGB(255, 250, 250, 250),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        birthdateController.text = DateFormat("yyyy-MM-dd").format(picked!);
      });
    }
  }

  String capitalize(String name) {
    if (name.isEmpty) return "";
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  void saveDetails() {
    if (_formKey.currentState!.validate()) {
      if (selectedDate == null) {
        return;
      }
      final details = {
        "firstName": capitalize(firstNameController.text.trim()),
        "middleName": capitalize(middleNameController.text.trim()),
        "lastName": capitalize(lastNameController.text.trim()),
        "birthdate": selectedDate != null ? DateFormat("yyyy-MM-dd").format(selectedDate!) : "",
        "address": addressController.text.trim(),
        "contactNumber": "+63${contactNumberController.text.trim()}",
        "disabilityType": disabilityType,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterPage(
            personalDetails: details,
            onTap: () {
              print("Register button tapped!");
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 48, 96),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await TalkBackService.instance.speak("Going back from personal details");
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              "ACCAP",
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
                            Text(
                              "ACCAP",
                              style: TextStyle(
                                letterSpacing: 3.0,
                                fontFamily: "Inter",
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 2
                                  ..color = Color.fromARGB(255, 28, 113, 166),
                              ),
                            ),
                            Text(
                              "ACCAP",
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
                        Text(
                          "Accessibility-Centered Community\nApplication for PWD",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  MyTextField(
                    controller: firstNameController,
                    hintText: "First Name",
                    obscureText: false,
                    validator: (value) => value == null || value.isEmpty ? "First Name is required" : null,
                  ),
                  const SizedBox(height: 10),
                  MyTextField(controller: middleNameController, hintText: "Middle Name (Optional)", obscureText: false),
                  const SizedBox(height: 10),
                  MyTextField(
                    controller: lastNameController,
                    hintText: "Last Name",
                    obscureText: false,
                    validator: (value) => value == null || value.trim().isEmpty ? "Last Name is required" : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () { HapticService.instance.selection(); _selectDate(context); },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: birthdateController,
                              decoration: InputDecoration(
                                hintText: "Birthdate",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MyTextField(
                    controller: addressController,
                    hintText: "Address",
                    obscureText: false,
                    validator: (value) => value == null || value.isEmpty ? "Address is required" : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text("+63", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: MyTextField(
                          controller: contactNumberController,
                          hintText: "Enter 10-digit number",
                          obscureText: false,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Contact number is required";
                            }
                            if (!RegExp(r'^9[0-9]{9}$').hasMatch(value)) {
                              return "Enter a valid 10-digit number";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Disability Type", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color.fromARGB(255, 250, 250, 250),
                    value: disabilityType,
                    items: disabilityOptions.map((String option) {
                      return DropdownMenuItem<String>(value: option, child: Text(option));
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        disabilityType = newValue!;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Material(
                      borderRadius: BorderRadius.circular(8),
                      color: Color.fromARGB(255, 0, 48, 96),
                      child: SizedBox(
                        width: 200,
                        child: TextButton.icon(
                          onPressed: () { HapticService.instance.lightImpact(); saveDetails(); },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            backgroundColor: Colors.transparent,
                          ),
                          label: const Text(
                            'Next',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}